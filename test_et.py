import requests
import json

# Yapay Zekaya soracağımız örnek bir film yorumu
test_yorumu = "Bu film gerçekten harikaydı! Görsel efektler ve oyunculuk muazzamdı, mutlaka izlenmeli."

print(f"Sorgulanıyor: '{test_yorumu}'")
print("-" * 50)

try:
    # Kendi bilgisayarındaki Yapay Zeka sunucusuna (Flask) istek gönderiyoruz
    response = requests.post(
        "http://127.0.0.1:5000/analyze", 
        json={"text": test_yorumu}
    )
    
    # Sunucudan gelen cevabı göster
    result = response.json()
    print("🤖 YAPAY ZEKA CEVABI:")
    print(f"Duygu Kararı: {result.get('sentiment')}")
    print(f"AI Yorumu: {result.get('ai_comment')}")

except Exception as e:
    print("❌ Sunucuya bağlanılamadı! ai_service.py'nin çalıştığından emin ol.")
    print("Hata:", e)