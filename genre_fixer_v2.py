import mysql.connector
import requests
import time
from urllib.parse import quote

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" # <-- API KEY'ini buraya tekrar yapıştır!
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', 
    'database': 'deal_db'
}

def search_tmdb(title, attempt_type="TR"):
    encoded_title = quote(title)
    
    language = "&language=tr-TR"
    if attempt_type == "EN":
        language = "&language=en-US"
    elif attempt_type == "RAW":
        language = "" 
        
    url = f"https://api.themoviedb.org/3/search/movie?api_key={TMDB_API_KEY}&query={encoded_title}{language}"
    
    try:
        # timeout=10 ekledik ki internet takılırsa kod donmasın
        res = requests.get(url, timeout=10).json()
        return res.get('results', [])
    except Exception as e:
        return []

def fix_genres_v2():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        print("🔍 Türleri kontrol etmek için film listesi çekiliyor...")
        # Hepsini tekrar tarayalım ki Zootropolis gibi İngilizce isimleri de yakalayalım
        cursor.execute("SELECT id, title FROM movies")
        movies = cursor.fetchall()
        
        print(f"🎬 {len(movies)} film için AKILLI (V2) tarama başlıyor...")

        for movie in movies:
            local_id = movie['id']
            title = movie['title']
            
            # --- STRATEJİ 1: Türkçe Ara ---
            results = search_tmdb(title, "TR")
            
            # --- STRATEJİ 2: İngilizce Ara (Zootropolis -> Zootopia) ---
            if not results:
                print(f"   🌍 İngilizce aranıyor: {title}...")
                results = search_tmdb(title, "EN")
            
            # --- STRATEJİ 3: İsmi Kısalt (Avatar: Ateş ve Kül -> Avatar) ---
            if not results and (":" in title or "-" in title):
                clean_title = title.split(":")[0].split("-")[0].strip()
                if len(clean_title) > 2:
                    print(f"   ✂️ Kısaltıp aranıyor: {clean_title}...")
                    results = search_tmdb(clean_title, "TR")
                    if not results:
                        results = search_tmdb(clean_title, "EN")

            # --- SONUÇ İŞLEME ---
            if results:
                correct_movie = results[0]
                original_title = correct_movie['original_title']
                genre_ids = correct_movie.get('genre_ids', [])
                
                # Önce bu film için eski (belki hatalı) türleri temizle
                cursor.execute("DELETE FROM movie_genres WHERE movie_id = %s", (local_id,))
                
                if genre_ids:
                    for g_id in genre_ids:
                        cursor.execute("INSERT IGNORE INTO genres (id, name) VALUES (%s, %s)", (g_id, "Bilinmiyor")) 
                        cursor.execute("INSERT INTO movie_genres (movie_id, genre_id) VALUES (%s, %s)", (local_id, g_id))
                    
                    print(f"✅ {title} -> (Bulunan: {original_title}) Türler güncellendi.")
                else:
                    print(f"⚠️ {title} -> Film bulundu ama tür bilgisi yok.")
            else:
                print(f"❌ {title} -> Hiçbir şekilde bulunamadı (Veritabanında kalabilir).")
            
            conn.commit()
            # API'yi çok yormamak için minik bekleme
            time.sleep(0.1) 

        conn.close()
        print("\n🚀 V2 GÜNCELLEME TAMAMLANDI!")

    except Exception as e:
        print(f"Büyük Hata: {e}")

if __name__ == "__main__":
    fix_genres_v2()