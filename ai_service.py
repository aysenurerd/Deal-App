from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import mysql.connector
import torch
import random

app = Flask(__name__)

# --- YAPILANDIRMA ---
MODEL_PATH = "./deal_model" 
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', 
    'database': 'deal_db'
}

# --- AI MODELLERİNİ YÜKLE ---
print("🧠 BERT Modeli yükleniyor...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_PATH)

PLATFORMLAR = ["Netflix", "Disney+", "Amazon Prime", "BluTV", "MUBI"]

# --- KARAKTERLİ AI YORUMLARI (Mühendis Modu) ---
AI_MESSAGES = {
    "Pozitif": [
        "Hocam bu veri tabanı harika çalışıyor! Bu film tam bir 'Primary Key' gibi sağlam, kesin izle.",
        "Algoritmam bu filmde %100 'Success' döndürdü. Modun 404 vermeyecek, söz veriyorum.",
        "Bu içerik tam bir 'Clean Code' gibi temiz ve akıcı. İzlerken beynin debug edilmiş gibi olacak."
    ],
    "Negatif": [
        "Hocam bu filmde bir 'Deadlock' var, hikaye bir türlü çözülmüyor. İzlerken beynin yanabilir.",
        "Sorgu hatası almış gibi hissediyorum; bu filmde yoğun bir 'Exception' var, modun düşebilir.",
        "Analiz sonucuna göre bu yapım 'Infinite Loop'a girmiş gibi, biraz karanlık ve bitmek bilmiyor."
    ]
}

@app.route('/get_movie', methods=['GET'])
def get_movie():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)

        # 1. Veritabanından rastgele bir film çek (release_date çıkarıldı çünkü tabloda yok)
        cursor.execute("SELECT id, title, overview, poster_url FROM Movies ORDER BY RAND() LIMIT 1")
        movie = cursor.fetchone()

        if not movie: return jsonify({'error': 'DB Boş!'}), 404

        movie_id = movie['id']
        overview = movie['overview']

        # 2. Cache Kontrolü
        cursor.execute("SELECT sentiment_result, ai_comment FROM Movie_Analysis WHERE movie_id = %s", (movie_id,))
        cached = cursor.fetchone()

        if cached:
            sentiment, comment = cached['sentiment_result'], cached['ai_comment']
        else:
            # 3. BERT Analizi
            inputs = tokenizer(overview, return_tensors="pt", truncation=True, padding=True, max_length=256)
            with torch.no_grad():
                outputs = model(**inputs)
            
            prediction = torch.argmax(outputs.logits).item()
            sentiment = "Pozitif" if prediction == 1 else "Negatif"
            comment = random.choice(AI_MESSAGES[sentiment])

            cursor.execute("INSERT INTO Movie_Analysis (movie_id, sentiment_result, ai_comment) VALUES (%s, %s, %s)",
                           (movie_id, sentiment, comment))
            conn.commit()

        return jsonify({
            'id': movie_id,
            'title': movie['title'],
            'overview': overview,
            'poster_url': movie['poster_url'],
            'release_date': "2025 (Mühendis Tahmini)", # Tabloda olmadığı için sabit verdik
            'platforms': random.sample(PLATFORMLAR, 2),
            'ai_result': sentiment,
            'ai_comment': comment
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close(); conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)