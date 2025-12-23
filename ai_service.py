from flask import Flask, jsonify, request
import mysql.connector

app = Flask(__name__)

# --- VERİTABANI AYARLARI ---
# Şifreni buraya doğru yazdığından emin ol ('123456' olarak bıraktım senin kodundan)
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',     
    'database': 'deal_db' 
}

def get_db_connection():
    return mysql.connector.connect(**DB_CONFIG)

@app.route('/get-filtered-movie', methods=['POST'])
def get_filtered_movie():
    try:
        data = request.get_json() or {}
        selected_platform = data.get('platform') 
        selected_genre = data.get('genre')       
        seen_ids = data.get('seen_ids', [])      

        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        # --- SQL SORGUSU ---
        query = """
            SELECT DISTINCT m.* FROM movies m
            JOIN movie_genres mg ON m.id = mg.movie_id
            JOIN genres g ON mg.genre_id = g.id
            WHERE 1=1
        """
        params = []

        if selected_platform:
            query += " AND m.platform = %s"
            params.append(selected_platform)

        if selected_genre:
            query += " AND g.name = %s"
            params.append(selected_genre)

        if seen_ids:
            format_strings = ','.join(['%s'] * len(seen_ids))
            query += f" AND m.id NOT IN ({format_strings})"
            params.extend(seen_ids)

        query += " ORDER BY RAND() LIMIT 1"

        cursor.execute(query, tuple(params))
        movie = cursor.fetchone()
        
        # Bağlantıyı burada tek seferde kapatıyoruz
        conn.close()

        if movie:
            # --- AKILLI URL DÜZELTİCİ ---
            raw_path = movie.get('poster_url')
            
            # 1. Eğer veri hiç yoksa
            if not raw_path:
                full_poster_url = "https://via.placeholder.com/500x750?text=Afis+Yok"
            
            # 2. Eğer veri zaten "http" ile başlıyorsa (Tam link ise dokunma)
            elif str(raw_path).startswith('http'):
                full_poster_url = raw_path
            
            # 3. Eğer veri sadece "/abc.jpg" şeklindeyse (Yarım ise tamamla)
            else:
                clean_path = raw_path if str(raw_path).startswith('/') else f"/{raw_path}"
                full_poster_url = f"https://image.tmdb.org/t/p/w500{clean_path}"

            return jsonify({
                "id": movie['id'],
                "title": movie['title'],
                "overview": movie.get('overview', ''),
                "poster_url": full_poster_url,  # <-- Garantili link
                "release_date": movie.get('release_date'),
                "imdb_rating": str(movie.get('vote_average', '0.0')),
                "platform": movie.get('platform', 'Sinema'),
                "genre": movie.get('genres', 'Genel')
            })
        else:
            return jsonify({"error": "Aradığın kriterlere uygun film bulunamadı."}), 404

    except Exception as e:
        print(f"HATA: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)