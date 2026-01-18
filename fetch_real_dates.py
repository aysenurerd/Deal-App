import mysql.connector
import requests
import time

# --- AYARLAR ---
# BURAYA KENDİ API KEY'İNİ YAPIŞTIR
API_KEY = "f27636b3559669645a684b936f5f8375" 

DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456',
    'database': 'deal_db'
}

def fetch_and_update_dates():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        # DÜZELTME BURADA: buffered=True ekledik.
        # Bu, verileri hafızaya alır ve "Unread result" hatasını önler.
        cursor = conn.cursor(buffered=True)
        print("Veritabanına bağlanıldı...")

        # 1. release_date sütunu yoksa ekle
        try:
            cursor.execute("SELECT release_date FROM movies LIMIT 1")
        except mysql.connector.Error:
            print("⚠️ 'release_date' sütunu yok. Ekleniyor...")
            cursor.execute("ALTER TABLE movies ADD COLUMN release_date DATE")
        
        # 2. Filmleri Çek
        cursor.execute("SELECT id, title FROM movies")
        movies = cursor.fetchall() # Hepsini hafızaya aldık
        
        print(f"Toplam {len(movies)} film için gerçek tarihler aranıyor...\n")

        updated_count = 0
        
        for movie in movies:
            movie_id = movie[0]
            title = movie[1]
            
            # TMDB'de film ismini arat
            search_url = f"https://api.themoviedb.org/3/search/movie?api_key={API_KEY}&query={title}&language=tr-TR"
            
            try:
                response = requests.get(search_url)
                if response.status_code == 200:
                    results = response.json().get('results')
                    if results:
                        best_match = results[0]
                        real_date = best_match.get('release_date')
                        
                        # Tarih boş gelirse atla
                        if real_date:
                            cursor.execute("UPDATE movies SET release_date = %s WHERE id = %s", (real_date, movie_id))
                            # Her güncellemeden sonra commit yaparak işi sağlama alalım
                            conn.commit()
                            print(f"✅ {title} -> {real_date}")
                            updated_count += 1
                        else:
                            print(f"⚠️ {title}: Tarih bilgisi boş.")
                    else:
                        print(f"❌ {title}: Bulunamadı.")
                else:
                    print(f"Hata: API {response.status_code}")
            except Exception as req_err:
                print(f"Bağlantı hatası: {req_err}")
            
            # API'yi yormamak için minik bekleme
            time.sleep(0.1)
        
        print(f"\n🎉 İŞLEM TAMAM! {updated_count} filmin tarihi güncellendi.")
        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ KRİTİK HATA: {e}")

if __name__ == "__main__":
    fetch_and_update_dates()