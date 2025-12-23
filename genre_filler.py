import mysql.connector
import requests
import time

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" # Kendi key'ini buraya yapıştır
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',     
    'database': 'deal_db' # Senin belirttiğin gerçek isim
}

def fill_genres():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # Tüm filmleri çekiyoruz
        cursor.execute("SELECT id, title FROM movies")
        movies = cursor.fetchall()
        print(f"🔄 {len(movies)} film için türler çekiliyor...")

        for movie in movies:
            movie_id = movie['id']
            # TMDB'den film detaylarını Türkçe çekiyoruz
            url = f"https://api.themoviedb.org/3/movie/{movie_id}?api_key={TMDB_API_KEY}&language=tr-TR"
            
            try:
                res = requests.get(url).json()
                genres = res.get('genres', [])
                
                for g in genres:
                    g_id = g['id']
                    g_name = g['name']
                    
                    # 1. Önce türü 'genres' tablosuna kaydet (DUPLICATE KEY hatası almamak için IGNORE)
                    cursor.execute("INSERT IGNORE INTO genres (id, name) VALUES (%s, %s)", (g_id, g_name))
                    
                    # 2. Sonra filmle türü 'movie_genres' tablosunda eşleştir
                    cursor.execute("INSERT IGNORE INTO movie_genres (movie_id, genre_id) VALUES (%s, %s)", (movie_id, g_id))
                
                print(f"✅ {movie['title']} -> Türleri kaydedildi.")
                conn.commit()
                time.sleep(0.1) # API'yi yormayalım

            except Exception as e:
                print(f"❌ {movie['title']} hata: {e}")

        conn.close()
        print("\n🚀 İşlem tamam! Artık filtreleme için hazırsın.")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    fill_genres()