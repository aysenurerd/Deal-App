import 'dart:convert';
import 'package:flutter/material.dart'; // RangeValues için gerekli
import 'package:http/http.dart' as http;

class ApiService {
  // Emulator kullanıyorsan 10.0.2.2, Gerçek cihazsa bilgisayarın IP'si
  final String baseUrl = "http://10.0.2.2:5000"; 

  // 0. GİRİŞ YAP
  Future<Map<String, dynamic>?> login(String username) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data; // {"id": 1, "username": "kullanici_adi"}
      } else {
        print("❌ Giriş Hatası: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return null;
    }
  }

  // 1. RASTGELE FİLM GETİR (Açılışta çalışan fonksiyon)
  Future<Map<String, dynamic>?> fetchRandomMovie() async {
    return fetchFilteredMovie(platform: null, genre: null);
  }

  // 1. PARTNER LİSTELE
  Future<List<Map<String, dynamic>>> getPartners(int userId) async {
    try {
      final url = Uri.parse('$baseUrl/get-partners?user_id=$userId');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        print("❌ Partner Listesi Hatası: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return [];
    }
  }

  // 2. PARTNER EKLE
  Future<Map<String, dynamic>?> addPartner(int userId, String name) async {
    try {
      final url = Uri.parse('$baseUrl/add-partner');
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "name": name,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print("❌ Partner Ekleme Hatası: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return null;
    }
  }

  // 3. OYUN İÇİN FİLM LİSTESİ GETİR
  Future<List<Map<String, dynamic>>> getGameMovies({
    List<String>? genres,
    RangeValues? years,
    List<String>? platforms,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/get-game-movies');
      final queryParams = <String, String>{};
      
      // HTTP caching'i engellemek için timestamp parametresi ekle
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      queryParams['timestamp'] = timestamp;
      
      if (genres != null && genres.isNotEmpty) {
        queryParams['genres'] = genres.join(',');
      }
      if (years != null) {
        queryParams['min_year'] = years.start.round().toString();
        queryParams['max_year'] = years.end.round().toString();
      }
      if (platforms != null && platforms.isNotEmpty) {
        queryParams['platforms'] = platforms.join(',');
      }
      
      final url = uri.replace(queryParameters: queryParams);
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      } else {
        print("❌ Film Listesi Hatası: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return [];
    }
  }

  // 4. EŞLEŞME KAYDET
  Future<bool> saveMatch(int userId, int movieId, {int? partnerId}) async {
    try {
      final url = Uri.parse('$baseUrl/save-match');
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "movie_id": movieId,
          "partner_id": partnerId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("❌ Eşleşme Kaydetme Hatası: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Bağlantı Hatası: $e");
      return false;
    }
  }

  // 5. FİLTRELİ FİLM GETİR
  Future<Map<String, dynamic>?> fetchFilteredMovie({String? platform, String? genre}) async {
    try {
      final url = Uri.parse('$baseUrl/get-filtered-movie');
      
      print("İstek atılıyor: $url -> Platform: $platform, Tür: $genre");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "platform": platform,
          "genre": genre,
          "seen_ids": []
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

  // --- 6. PROFİL GETİR (Düzeltildi: static silindi) ---
  Future<Map<String, dynamic>> fetchProfile(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get-profile?user_id=$userId'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Profil yüklenemedi: ${response.body}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

// --- KÜTÜPHANE GETİR (Güncellendi: Partner ID desteği) ---
  Future<List<dynamic>> fetchLibrary(int userId, {String? partnerId}) async {
    try {
      // Eğer partnerId varsa URL'e ekle (Örn: &partner_id=5 veya &partner_id=solo)
      String urlStr = '$baseUrl/get-library?user_id=$userId';
      if (partnerId != null) {
        urlStr += '&partner_id=$partnerId';
      }

      final response = await http.get(Uri.parse(urlStr));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Kütüphane yüklenemedi: ${response.body}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }
}