from flask import Flask, jsonify, request
import mysql.connector
import random

app = Flask(__name__)

# --- VERİTABANI AYARLARI ---
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',     
    'database': 'deal_db' 
}

def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)

# --- 1. GİRİŞ & KULLANICI YÖNETİMİ ---
@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        username = data.get('username')
        
        if not username:
            return jsonify({"error": "Kullanıcı adı gerekli"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Kullanıcı var mı diye bak
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()

        # Yoksa oluştur
        if not user:
            cursor.execute("INSERT INTO users (username) VALUES (%s)", (username,))
            conn.commit()
            user_id = cursor.lastrowid
            user = {"id": user_id, "username": username}
        
        conn.close()
        return jsonify(user)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- 2. PARTNER YÖNETİMİ ---
@app.route('/add-partner', methods=['POST'])
def add_partner():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        partner_name = data.get('name')

        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("INSERT INTO partners (user_id, name) VALUES (%s, %s)", (user_id, partner_name))
        conn.commit()
        partner_id = cursor.lastrowid
        
        conn.close()
        return jsonify({"success": True, "id": partner_id, "name": partner_name})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/get-partners', methods=['GET'])
def get_partners():
    try:
        user_id = request.args.get('user_id')
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("SELECT * FROM partners WHERE user_id = %s", (user_id,))
        partners = cursor.fetchall()
        
        conn.close()
        return jsonify(partners)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- 3. OYUN İÇİN FİLM ÇEKME ---
@app.route('/get-game-movies', methods=['GET'])
def get_game_movies():
    try:
        # Rastgele 10 film getir
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Puanı, Afişi ve Türü dolu olan filmleri getir
        query = """
            SELECT m.*, GROUP_CONCAT(g.name SEPARATOR ', ') as genre_names 
            FROM movies m
            JOIN movie_genres mg ON m.id = mg.movie_id
            JOIN genres g ON mg.genre_id = g.id
            GROUP BY m.id
            ORDER BY RAND()
            LIMIT 10
        """
        cursor.execute(query)
        movies = cursor.fetchall()
        
        # Verileri düzenle (URL düzeltme vs.)
        cleaned_movies = []
        for m in movies:
            poster = m['poster_url']
            if poster and not poster.startswith('http'):
                poster = f"https://image.tmdb.org/t/p/w500{poster}"
            
            cleaned_movies.append({
                "id": m['id'],
                "title": m['title'],
                "poster_url": poster,
                "rating": str(m['vote_average']),
                "year": m['release_date'].year if m['release_date'] else "",
                "genres": m['genre_names']
            })

        conn.close()
        return jsonify(cleaned_movies)

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500

# --- 4. EŞLEŞME KAYDETME (KRİTİK KISIM) ---
@app.route('/save-match', methods=['POST'])
def save_match():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        movie_id = data.get('movie_id')
        partner_id = data.get('partner_id') # Solo ise NULL (None) gelecek

        conn = get_db_connection()
        cursor = conn.cursor()

        # Zaten ekli mi diye bak (Çift kaydı önle)
        check_query = "SELECT id FROM collections WHERE user_id=%s AND movie_id=%s"
        check_params = [user_id, movie_id]
        
        if partner_id:
            check_query += " AND partner_id=%s"
            check_params.append(partner_id)
        else:
            check_query += " AND partner_id IS NULL"

        cursor.execute(check_query, tuple(check_params))
        exists = cursor.fetchone()

        if not exists:
            insert_query = "INSERT INTO collections (user_id, movie_id, partner_id) VALUES (%s, %s, %s)"
            cursor.execute(insert_query, (user_id, movie_id, partner_id))
            conn.commit()

        conn.close()
        return jsonify({"success": True})

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500

# --- 5. KÜTÜPHANE LİSTELEME ---
@app.route('/get-library', methods=['GET'])
def get_library():
    try:
        user_id = request.args.get('user_id')
        partner_id = request.args.get('partner_id') # Filtrelemek için

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        query = """
            SELECT m.id, m.title, m.poster_url, m.vote_average, c.saved_at
            FROM collections c
            JOIN movies m ON c.movie_id = m.id
            WHERE c.user_id = %s
        """
        params = [user_id]

        if partner_id:
            query += " AND c.partner_id = %s"
            params.append(partner_id)
        else:
            # Partner ID yoksa, sadece SOLO (partner_id IS NULL) olanları getir
            # VEYA hepsini getirip frontend'de ayırabilirsin.
            # Şimdilik "Tümü" veya "Solo" ayrımı yapalım:
            is_solo = request.args.get('solo')
            if is_solo == 'true':
                query += " AND c.partner_id IS NULL"

        query += " ORDER BY c.saved_at DESC"
        
        cursor.execute(query, tuple(params))
        movies = cursor.fetchall()
        
        # URL Düzeltme
        for m in movies:
            if m['poster_url'] and not m['poster_url'].startswith('http'):
                m['poster_url'] = f"https://image.tmdb.org/t/p/w500{m['poster_url']}"

        conn.close()
        return jsonify(movies)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)