import mysql.connector
import requests
import time

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375"  # <-- Kendi anahtarını yapıştır
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',  # Şifren
    'database': 'deal_db'
}

def update_ratings():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # Puanı henüz 0 olan filmleri çek
        cursor.execute("SELECT id, title FROM movies WHERE vote_average IS NULL OR vote_average = 0")
        movies = cursor.fetchall()
        
        print(f"🔄 {len(movies)} film için puan aranıyor...")

        for movie in movies:
            movie_id = movie['id']
            url = f"https://api.themoviedb.org/3/movie/{movie_id}?api_key={TMDB_API_KEY}&language=tr-TR"
            
            try:
                res = requests.get(url).json()
                rating = res.get('vote_average') # Örn: 7.8
                
                if rating:
                    # Veritabanına kaydet
                    sql = "UPDATE movies SET vote_average = %s WHERE id = %s"
                    cursor.execute(sql, (rating, movie_id))
                    print(f"⭐ {movie['title']} -> {rating} Puan Eklendi")
                else:
                    print(f"⚠️ {movie['title']} -> Puan bulunamadı.")
                
                conn.commit()
                time.sleep(0.05) # Çok hızlı istek atmayalım

            except Exception as e:
                print(f"❌ {movie['title']} Hatası: {e}")

        conn.close()
        print("\n🚀 Tüm puanlar başarıyla güncellendi!")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    update_ratings()