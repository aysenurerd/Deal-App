import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // DİKKAT: Emulator kullanıyorsan 10.0.2.2, Gerçek cihazsa bilgisayarın IP'si (örn: 192.168.1.35)
  // iOS Simulator ise localhost
  final String baseUrl = "http://10.0.2.2:5000"; 

  // 1. RASTGELE FİLM GETİR (Açılışta çalışan fonksiyon)
  // Artık bu arkadaş da alttaki 'fetchFilteredMovie'yi kullanıyor ama filtresiz çağırıyor.
  Future<Map<String, dynamic>?> fetchRandomMovie() async {
    return fetchFilteredMovie(platform: null, genre: null);
  }

  // 2. FİLTRELİ FİLM GETİR (Yeni Yıldızımız)
  // Python'daki '/get-filtered-movie' adresine gidiyor.
  Future<Map<String, dynamic>?> fetchFilteredMovie({String? platform, String? genre}) async {
    try {
      final url = Uri.parse('$baseUrl/get-filtered-movie'); // İŞTE EŞLEŞME BURADA SAĞLANIYOR
      
      print("İstek atılıyor: $url -> Platform: $platform, Tür: $genre"); // Log ekledik

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "platform": platform, // Seçilen platform (örn: 'Netflix')
          "genre": genre,       // Seçilen tür (örn: 'Dram')
          "seen_ids": []        // Daha önce izlenenler (şimdilik boş)
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print("❌ Sunucu Hatası: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return null;
    }
  }
}