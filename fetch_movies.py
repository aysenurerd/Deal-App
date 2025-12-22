
import requests
import mysql.connector
from datetime import datetime

# --- AYARLAR ---
# Buraya kendi TMDB API Key'ini yapıştır
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" 

DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', # Kendi MySQL şifreni buraya yaz
    'database': 'deal_db'
}

def fetch_and_save_movies():
    today = datetime.now().strftime('%Y-%m-%d')
    
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("✅ Veritabanı bağlantısı başarılı.")
        
        total_added = 0
        
        # 1000 film için 50 sayfa (50 * 20 = 1000)
        for page in range(1, 51):
            print(f"Sayfa {page} çekiliyor...")
            
            url = (f"https://api.themoviedb.org/3/discover/movie?api_key={TMDB_API_KEY}"
                   f"&language=tr-TR&sort_by=popularity.desc&include_adult=false"
                   f"&vote_average.gte=2&primary_release_date.lte={today}&page={page}")
            
            response = requests.get(url).json()
            
            if 'results' in response:
                for movie in response['results']:
                    # Özeti boş olan filmleri BERT analiz edemez, o yüzden eliyoruz
                    if not movie.get('overview') or len(movie.get('overview')) < 10:
                        continue
                        
                    title = movie['title']
                    overview = movie['overview']
                    poster_path = movie.get('poster_path')
                    poster_url = f"https://image.tmdb.org/t/p/w500{poster_path}" if poster_path else None
                    
                    # Aynı film varsa tekrar ekleme (title üzerinden kontrol)
                    sql = "INSERT IGNORE INTO Movies (title, overview, poster_url) VALUES (%s, %s, %s)"
                    cursor.execute(sql, (title, overview, poster_url))
                    total_added += cursor.rowcount
            
            # Veritabanını her sayfadan sonra güncelleyelim (Güvenlik için)
            conn.commit()
            
        print(f"\n🚀 İŞLEM TAMAMLANDI!")
        print(f"✅ Toplam {total_added} film başarıyla veritabanına eklendi.")
        
    except mysql.connector.Error as err:
        print(f"❌ Veritabanı hatası: {err}")
    except Exception as e:
        print(f"❌ Bir hata oluştu: {e}")
    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()

if __name__ == "__main__":
    fetch_and_save_movies()