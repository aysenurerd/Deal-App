import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Python terminalinde gördüğün IP adresini buraya yazıyoruz
  static const String baseUrl = "http://10.0.2.2:5000";
  Future<Map<String, dynamic>> fetchRandomMovie() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_movie'));

      if (response.statusCode == 200) {
        // Gelen JSON verisini çözüp haritaya (Map) çeviriyoruz
        return json.decode(response.body);
      } else {
        throw Exception('Film yüklenemedi: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }
}