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

# --- 3. OYUN İÇİN FİLM ÇEKME (FİNAL DÜZELTME: Having Kaldırıldı) ---
@app.route('/get-game-movies', methods=['GET'])
def get_game_movies():
    try:
        min_year = request.args.get('min_year')
        max_year = request.args.get('max_year')
        genres_str = request.args.get('genres')
        platforms_str = request.args.get('platforms')

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # Temel Sorgu: Filmleri çek, türleri varsa ekle, yoksa NULL kalsın
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

        # Tür Filtresi (Varsa uygula)
        if genres_str:
            genre_list = genres_str.split(',')
            placeholders = ','.join(['%s'] * len(genre_list))
            subquery = f"SELECT movie_id FROM movie_genres JOIN genres ON movie_genres.genre_id = genres.id WHERE genres.name IN ({placeholders})"
            conditions.append(f"m.id IN ({subquery})")
            params.extend(genre_list)
        
        # Platform Filtresi (Sinema + NULL Desteği)
        if platforms_str:
            platform_list = [p.strip() for p in platforms_str.split(',')]
            platform_conditions = []
            
            is_cinema_selected = any(p.lower() == 'sinema' for p in platform_list)
            
            if is_cinema_selected:
                # Sinema seçildiyse: NULL, Boşluk veya 'Sinema' içerenleri al
                platform_conditions.append("(m.platform IS NULL OR m.platform = '' OR m.platform LIKE '%Sinema%')")
                platform_list = [p for p in platform_list if p.lower() != 'sinema']
            
            for p in platform_list:
                if p:
                    platform_conditions.append("m.platform LIKE %s")
                    params.append(f"%{p}%")
            
            if platform_conditions:
                conditions.append(f"({' OR '.join(platform_conditions)})")

        if conditions:
            query += " WHERE " + " AND ".join(conditions)

        # DEBUG: Log bas
        print(f"DEBUG: İstek Geldi -> Platform: {platforms_str} | Tür: {genres_str}")

        # --- KRİTİK DEĞİŞİKLİK ---
        # "HAVING genre_names IS NOT NULL" KISMINI SİLDİK!
        # Artık türü olmayan "yetim" filmler de listeye girebilecek.
        # Limit 50 ile geniş bir havuz alıp Python'da karıştıracağız.
        query += " GROUP BY m.id ORDER BY RAND() LIMIT 50"

        cursor.execute(query, tuple(params))
        movies = cursor.fetchall()
        
        print(f"DEBUG: SQL'den Dönen Film Sayısı: {len(movies)}")

        # Python Shuffle: İyice karıştır
        random.shuffle(movies)

        # İlk 5 tanesini seç
        selected_movies = movies[:5]
        
        # Seçilenlerin ID'lerini logla (Kontrol için)
        if selected_movies:
             print(f"DEBUG: Seçilen ID'ler: {[m['id'] for m in selected_movies]}")

        # Veriyi Temizle
        cleaned_movies = []
        for m in selected_movies:
            poster = m.get('poster_url', '')
            if poster and not poster.startswith('http'):
                poster = f"https://image.tmdb.org/t/p/w500{poster}"

            year = ""
            if m.get('release_date'):
                try: year = str(m['release_date'].year)
                except: year = str(m['release_date'])[:4]

            platform_info = m.get('platform')
            if not platform_info: 
                platform_info = "Sinema"

            cleaned_movies.append({
                "id": m['id'],
                "title": m.get('title', 'Başlıksız'),
                "poster_url": poster,
                "rating": str(m.get('vote_average', 0.0)),
                "year": year,
                "genres": m.get('genre_names', ''), # Tür yoksa boş gelsin, sorun değil
                "platforms": platform_info,
                "overview": m.get('overview', 'Özet bulunamadı.')
            })

        conn.close()
        
        # Cache (Önbellek) Engelleme Başlıkları
        response = jsonify(cleaned_movies)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
        
        return response

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

# --- 6. PROFİL BİLGİLERİ (GÜNCEL VERSİYON) ---
@app.route('/get-profile', methods=['GET'])
def get_profile():
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({"error": "User ID gerekli"}), 400

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Kullanıcı Adı
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        
        # Partner Adı (İlk partneri örnek alalım)
        cursor.execute("SELECT name FROM partners WHERE user_id = %s LIMIT 1", (user_id,))
        partner = cursor.fetchone()
        
        # Toplam Beğeni Sayısı
        cursor.execute("SELECT COUNT(*) as count FROM collections WHERE user_id = %s", (user_id,))
        stats = cursor.fetchone()
        
        conn.close()
        
        return jsonify({
            "username": user['username'] if user else "Bilinmiyor",
            "partner_name": partner['name'] if partner else "Partner Yok",
            "total_likes": stats['count'] if stats else 0
        })

    except Exception as e:
        print(f"Profil Hatasi: {str(e)}")
        return jsonify({"error": str(e)}), 500


# --- 7. KÜTÜPHANE (TEK VE KLASÖR DESTEKLİ VERSİYON) ---
@app.route('/get-library', methods=['GET'])
def get_library():
    try:
        user_id = request.args.get('user_id')
        partner_id = request.args.get('partner_id') # Flutter'dan gelen filtre
        
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        # Detaylı sorgu: Overview (Özet) bilgisini de çekiyoruz
        query = """
            SELECT m.id, m.title, m.poster_url, m.vote_average, m.overview, c.saved_at
            FROM collections c
            JOIN movies m ON c.movie_id = m.id
            WHERE c.user_id = %s
        """
        params = [user_id]

        # Filtreleme mantığı
        if partner_id == 'solo':
            query += " AND c.partner_id IS NULL"
        elif partner_id and partner_id != 'null':
            query += " AND c.partner_id = %s"
            params.append(partner_id)
        
        query += " ORDER BY c.saved_at DESC"
        
        cursor.execute(query, tuple(params))
        movies = cursor.fetchall()
        
        for m in movies:
            if m.get('poster_url') and not m['poster_url'].startswith('http'):
                m['poster_url'] = f"https://image.tmdb.org/t/p/w500{m['poster_url']}"
            if not m.get('overview'):
                m['overview'] = "Bu film için özet bilgisi bulunamadı."
                
        conn.close()
        response = jsonify(movies)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        return response

    except Exception as e:
        print(f"Kutuphane Hatasi: {str(e)}")
        return jsonify({"error": str(e)}), 500
# --- PARTNER SİLME ---
@app.route('/delete-partner', methods=['POST'])
def delete_partner():
    try:
        data = request.get_json()
        partner_id = data.get('partner_id')
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Sadece partneri siliyoruz, veritabanı ayarların (Cascade) 
        # düzgünse koleksiyondaki eşleşmeler de otomatik temizlenir.
        cursor.execute("DELETE FROM partners WHERE id = %s", (partner_id,))
        conn.commit()
        conn.close()
        
        return jsonify({"success": True, "message": "Partner silindi"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500        
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)