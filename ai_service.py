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
        if not username: return jsonify({"error": "Kullanıcı adı gerekli"}), 400
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        if not user:
            cursor.execute("INSERT INTO users (username) VALUES (%s)", (username,))
            conn.commit()
            user_id = cursor.lastrowid
            user = {"id": user_id, "username": username}
        conn.close()
        return jsonify(user)
    except Exception as e: return jsonify({"error": str(e)}), 500

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
    except Exception as e: return jsonify({"error": str(e)}), 500

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
    except Exception as e: return jsonify({"error": str(e)}), 500

# --- 3. OYUN İÇİN FİLM ÇEKME (DÜZELTİLDİ: Senin Tablo Yapına Göre) ---
@app.route('/get-game-movies', methods=['GET'])
def get_game_movies():
    try:
        min_year = request.args.get('min_year')
        max_year = request.args.get('max_year')
        genres_str = request.args.get('genres')
        platforms_str = request.args.get('platforms')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Temel Sorgu: Artık platform tablosuna JOIN YOK. Direkt m.platform alıyoruz.
        query = """
            SELECT m.id, m.title, m.poster_url, m.vote_average, m.release_date, m.overview, m.platform,
                   GROUP_CONCAT(DISTINCT g.name SEPARATOR ', ') as genre_names
            FROM movies m
            LEFT JOIN movie_genres mg ON m.id = mg.movie_id
            LEFT JOIN genres g ON mg.genre_id = g.id
        """

        conditions = []
        params = []

        # Yıl Filtresi
        if min_year and max_year:
            conditions.append("YEAR(m.release_date) BETWEEN %s AND %s")
            params.extend([min_year, max_year])

        # Tür Filtresi
        if genres_str:
            genre_list = genres_str.split(',')
            placeholders = ','.join(['%s'] * len(genre_list))
            subquery = f"SELECT movie_id FROM movie_genres JOIN genres ON movie_genres.genre_id = genres.id WHERE genres.name IN ({placeholders})"
            conditions.append(f"m.id IN ({subquery})")
            params.extend(genre_list)
        
        # Platform Filtresi (Artık m.platform sütununda arama yapıyoruz)
        if platforms_str:
            platform_list = platforms_str.split(',')
            # LIKE kullanarak esnek arama yapalım (Örn: 'Netflix' içerenleri bul)
            platform_conditions = []
            for p in platform_list:
                platform_conditions.append("m.platform LIKE %s")
                params.append(f"%{p}%")
            
            if platform_conditions:
                conditions.append(f"({' OR '.join(platform_conditions)})")

        # Koşulları Ekle
        if conditions:
            query += " WHERE " + " AND ".join(conditions)

        # Grupla ve Rastgele Getir
        query += " GROUP BY m.id HAVING genre_names IS NOT NULL ORDER BY RAND() LIMIT 10"

        cursor.execute(query, tuple(params))
        movies = cursor.fetchall()

        # Veriyi İşle
        cleaned_movies = []
        for m in movies:
            poster = m.get('poster_url', '')
            if poster and not poster.startswith('http'):
                poster = f"https://image.tmdb.org/t/p/w500{poster}"

            year = ""
            release_date = m.get('release_date')
            if release_date:
                try: year = release_date.year
                except: year = str(release_date)[:4]

            # Platform verisi artık direkt tablodan geliyor
            platform_info = m.get('platform')
            if not platform_info:
                platform_info = "Sinema" # Boşsa varsayılan

            cleaned_movies.append({
                "id": m['id'],
                "title": m.get('title', 'Başlıksız'),
                "poster_url": poster,
                "rating": str(m.get('vote_average', 0.0)),
                "year": str(year),
                "genres": m.get('genre_names', ''),
                "platforms": platform_info,  # Flutter burayı okuyacak
                "overview": m.get('overview', 'Özet bulunamadı.')
            })

        conn.close()
        return jsonify(cleaned_movies)

    except Exception as e:
        print("HATA:", str(e))
        return jsonify({"error": str(e)}), 500

# --- 4. EŞLEŞME KAYDETME ---
@app.route('/save-match', methods=['POST'])
def save_match():
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        movie_id = data.get('movie_id')
        partner_id = data.get('partner_id')
        conn = get_db_connection()
        cursor = conn.cursor()
        check_query = "SELECT id FROM collections WHERE user_id=%s AND movie_id=%s"
        check_params = [user_id, movie_id]
        if partner_id:
            check_query += " AND partner_id=%s"
            check_params.append(partner_id)
        else:
            check_query += " AND partner_id IS NULL"
        cursor.execute(check_query, tuple(check_params))
        if not cursor.fetchone():
            insert_query = "INSERT INTO collections (user_id, movie_id, partner_id) VALUES (%s, %s, %s)"
            cursor.execute(insert_query, (user_id, movie_id, partner_id))
            conn.commit()
        conn.close()
        return jsonify({"success": True})
    except Exception as e: return jsonify({"error": str(e)}), 500

# --- 5. KÜTÜPHANE LİSTELEME ---
@app.route('/get-library', methods=['GET'])
def get_library():
    try:
        user_id = request.args.get('user_id')
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        query = """
            SELECT m.id, m.title, m.poster_url, m.vote_average, c.saved_at
            FROM collections c
            JOIN movies m ON c.movie_id = m.id
            WHERE c.user_id = %s AND c.partner_id IS NULL
            ORDER BY c.saved_at DESC
        """
        cursor.execute(query, (user_id,))
        movies = cursor.fetchall()
        for m in movies:
            if m['poster_url'] and not m['poster_url'].startswith('http'):
                m['poster_url'] = f"https://image.tmdb.org/t/p/w500{m['poster_url']}"
        conn.close()
        return jsonify(movies)
    except Exception as e: return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)