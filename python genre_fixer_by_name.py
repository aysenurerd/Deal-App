import mysql.connector
import requests
import time
from urllib.parse import quote

# --- AYARLAR ---
TMDB_API_KEY = "f27636b3559669645a684b936f5f8375" # <-- Kendi anahtarını buraya yapıştır!
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': '123456', 
    'database': 'deal_db'
}

def search_tmdb(title, attempt_type="TR"):
    """TMDB'de farklı dillerde arama yapan fonksiyon"""
    encoded_title = quote(title)
    
    language = "&language=tr-TR"
    if attempt_type == "EN":
        language = "&language=en-US" # İngilizce dene
    elif attempt_type == "RAW":
        language = "" # Dil kısıtlaması olmadan dene
        
    url = f"https://api.themoviedb.org/3/search/movie?api_key={TMDB_API_KEY}&query={encoded_title}{language}"
    
    try:
        res = requests.get(url).json()
        return res.get('results', [])
    except:
        return []

def fix_genres_smartly():
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor(dictionary=True)
        
        # Sadece türü eksik olan filmleri tekrar tarayalım
        # Böylece bulduklarımızı tekrar tekrar arayıp vakit kaybetmeyiz
        print("🔍 Türü eksik olan filmler listeleniyor...")
        cursor.execute("""
            SELECT m.id, m.title 
            FROM movies m
            LEFT JOIN movie_genres mg ON m.id = mg.movie_id
            WHERE mg.id IS NULL
        """)
        movies = cursor.fetchall()
        
        if not movies:
            print("🎉 Harika! Türü eksik olan hiçbir film kalmamış.")
            return

        print(f"🎬 {len(movies)} 'Kayıp Vaka' film için AKILLI ARAMA başlatılıyor...")

        for movie in movies:
            local_id = movie['id']
            title = movie['title']
            
            # ADIM 1: Türkçe Ara
            results = search_tmdb(title, "TR")
            
            # ADIM 2: Bulamazsan İngilizce Ara (Zootropolis -> Zootopia)
            if not results:
                print(f"   🌍 İngilizce aranıyor: {title}...")
                results = search_tmdb(title, "EN")
            
            # ADIM 3: Hala yoksa ve isimde ':' veya '-' varsa ilk kısmı ara
            # Örn: "Avatar: Ateş ve Kül" -> "Avatar"
            if not results and (":" in title or "-" in title):
                clean_title = title.split(":")[0].split("-")[0].strip()
                if len(clean_title) > 2: # Çok kısa değilse
                    print(f"   ✂️ Kısaltıp aranıyor: {clean_title}...")
                    results = search_tmdb(clean_title, "TR")
                    if not results:
                        results = search_tmdb(clean_title, "EN")

            # SONUÇ VARSA KAYDET
            if results:
                correct_movie = results[0]
                tmdb_id = correct_movie['id']
                original_title = correct_movie['original_title']
                genre_ids = correct_movie.get('genre_ids', [])
                
                if genre_ids:
                    for g_id in genre_ids:
                        cursor.execute("INSERT IGNORE INTO genres (id, name) VALUES (%s, %s)", (g_id, "Bilinmiyor")) 
                        cursor.execute("INSERT INTO movie_genres (movie_id, genre_id) VALUES (%s, %s)", (local_id, g_id))
                    
                    print(f"✅ {title} -> (Buldum: {original_title}) Türler eklendi.")
                else:
                    print(f"⚠️ {title} -> Film bulundu ama tür bilgisi yok.")
            else:
                print(f"❌ {title} -> Pes ettim, bulunamadı.")
            
            conn.commit()
            time.sleep(0.1) 

        conn.close()
        print("\n🚀 AKILLI GÜNCELLEME TAMAMLANDI!")

    except Exception as e:
        print(f"Bağlantı Hatası: {e}")

if __name__ == "__main__":
    fix_genres_smartly()