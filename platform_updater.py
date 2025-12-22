import mysql.connector
import requests
import time

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" # Kendi key'ini buraya yapıştır
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',     
    'database': 'deal_db' # Workbench'teki gerçek ismi buraya yaz!
}

def update_platforms():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # Platformu boş olan filmleri çek
        cursor.execute("SELECT id, title FROM movies WHERE platform IS NULL")
        movies = cursor.fetchall()
        print(f"🔄 {len(movies)} film için platform bilgisi aranıyor...")

        for movie in movies:
            movie_id = movie['id']
            # TMDB'den Türkiye (TR) sağlayıcılarını çek
            url = f"https://api.themoviedb.org/3/movie/{movie_id}/watch/providers?api_key={TMDB_API_KEY}"
            
            try:
                response = requests.get(url)
                if response.status_code == 200:
                    data = response.json()
                    # Türkiye (TR) sonuçları ve 'flatrate' (üyelikle izle) kısmına bak
                    results = data.get('results', {}).get('TR', {}).get('flatrate', [])
                    
                    if results:
                        # En popüler ilk platformu al (Netflix, Disney+, Prime vb.)
                        platform_name = results[0]['provider_name']
                        cursor.execute("UPDATE movies SET platform = %s WHERE id = %s", (platform_name, movie_id))
                        print(f"✅ {movie['title']} -> {platform_name}")
                    else:
                        cursor.execute("UPDATE movies SET platform = 'Sinema' WHERE id = %s", (movie_id,))
                        print(f"ℹ️ {movie['title']} -> Platform bulunamadı (Sinema).")
                
                conn.commit()
                time.sleep(0.2) # API'yi yormamak için kısa bekleme
                
            except Exception as e:
                print(f"❌ {movie['title']} hata: {e}")

        conn.close()
        print("\n🚀 Güncelleme tamamlandı!")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    update_platforms()  