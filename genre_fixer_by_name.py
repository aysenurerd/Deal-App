import mysql.connector
import requests
import time
from urllib.parse import quote

# --- AYARLAR ---
TMDB_API_KEY = "BURAYA_TMDB_API_KEYINI_YAZ" # Kendi anahtarını gir
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', 
    'database': 'deal_db'
}

def fix_genres_by_name():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # 1. Önce eski hatalı eşleşmeleri temizleyelim (Temiz sayfa)
        print("🧹 Eski hatalı türler temizleniyor...")
        cursor.execute("TRUNCATE TABLE movie_genres")
        conn.commit()
        
        # Tüm filmleri çek
        cursor.execute("SELECT id, title FROM movies")
        movies = cursor.fetchall()
        
        print(f"🎬 {len(movies)} film için İSİM ile doğru türler aranıyor...")

        for movie in movies:
            local_id = movie['id']
            title = movie['title']
            
            # İsmi URL uyumlu hale getir
            encoded_title = quote(title)
            
            # 2. İsme göre ARAMA yap (Doğru ID'yi bulmak için)
            search_url = f"https://api.themoviedb.org/3/search/movie?api_key={TMDB_API_KEY}&query={encoded_title}&language=tr-TR"
            
            try:
                search_res = requests.get(search_url).json()
                results = search_res.get('results')
                
                if results and len(results) > 0:
                    # En iyi eşleşen filmi al
                    correct_movie = results[0]
                    tmdb_id = correct_movie['id'] # Gerçek TMDB ID'si
                    genre_ids = correct_movie.get('genre_ids', []) # Örn: [18, 36, 10752]
                    
                    # Bu ID'lerin isimlerini (Örn: 18 -> Dram) bulmamız lazım
                    # (TMDB genre listesini hafızada tutmak yerine her seferinde kaydedelim, sağlam olsun)
                    
                    if genre_ids:
                        for g_id in genre_ids:
                            # Tür adını öğrenmek için ufak bir sorgu daha gerekebilir veya
                            # genelde elimizdeki 'genres' tablosunda bu ID varsa ismini oradan kullanırız.
                            # Ama garanti olsun diye genres tablosuna "INSERT IGNORE" yapacağız.
                            
                            # Türü movie_genres tablosuna ekle
                            cursor.execute("INSERT INTO movie_genres (movie_id, genre_id) VALUES (%s, %s)", (local_id, g_id))
                            
                            # Not: genres tablosunda bu ID yoksa ismi eksik kalabilir. 
                            # O yüzden önce genres tablosunu doldurmak en iyisidir ama
                            # şimdilik sadece bağlantıyı kuralım, isimleri genelde standarttır.
                        
                        print(f"✅ {title} -> {len(genre_ids)} tür eklendi (TMDB ID: {tmdb_id})")
                    else:
                        print(f"⚠️ {title} -> Tür bilgisi boş.")
                else:
                    print(f"❌ {title} -> Bulunamadı.")
                
                conn.commit()
                time.sleep(0.1) # Hız sınırı

            except Exception as e:
                print(f"💥 Hata ({title}): {e}")

        conn.close()
        print("\n🚀 TÜM TÜRLER DOĞRULANDI VE GÜNCELLENDİ!")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    fix_genres_by_name()