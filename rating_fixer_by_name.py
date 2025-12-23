import mysql.connector
import requests
import time
from urllib.parse import quote

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" # Kendi key'ini yapıştır
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', # Şifren
    'database': 'deal_db'
}

def fix_ratings_by_name():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # Puanı 0 olan veya NULL olan filmleri çek
        cursor.execute("SELECT id, title FROM movies WHERE vote_average IS NULL OR vote_average = 0")
        movies = cursor.fetchall()
        
        print(f"🔄 {len(movies)} film için İSİM ile puan aranıyor...")

        for movie in movies:
            movie_id = movie['id']
            title = movie['title']
            
            # URL güvenliği için ismi kodla (Örn: Matrix -> Matrix, Baba 2 -> Baba%202)
            encoded_title = quote(title)
            
            # ARAMA SORGUSU (Search API)
            url = f"https://api.themoviedb.org/3/search/movie?api_key={TMDB_API_KEY}&query={encoded_title}&language=tr-TR"
            
            try:
                res = requests.get(url).json()
                results = res.get('results')
                
                if results and len(results) > 0:
                    # İlk sonucu en doğru film kabul edelim
                    first_match = results[0]
                    rating = first_match.get('vote_average')
                    real_id = first_match.get('id') # Meraklısına TMDB ID'si
                    
                    if rating:
                        # Veritabanına kaydet
                        sql = "UPDATE movies SET vote_average = %s WHERE id = %s"
                        cursor.execute(sql, (rating, movie_id))
                        print(f"✅ {title} -> {rating} Puan (TMDB ID: {real_id})")
                    else:
                        print(f"⚠️ {title} -> Sonuç bulundu ama puanı yok.")
                else:
                    print(f"❌ {title} -> TMDB'de bu isimle film bulunamadı.")
                
                conn.commit()
                time.sleep(0.1) # Kibar olalım, API'yi yormayalım

            except Exception as e:
                print(f"💥 Hata ({title}): {e}")

        conn.close()
        print("\n🚀 Operasyon Tamamlandı! Puanlar güncellendi.")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    fix_ratings_by_name()