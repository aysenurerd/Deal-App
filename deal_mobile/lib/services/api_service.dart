import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // DİKKAT: Emulator kullanıyorsan 10.0.2.2, Gerçek cihazsa bilgisayarın IP'si (örn: 192.168.1.35)
  // iOS Simulator ise localhost
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
  // Artık bu arkadaş da alttaki 'fetchFilteredMovie'yi kullanıyor ama filtresiz çağırıyor.
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
      
      if (genres != null && genres.isNotEmpty) {
        queryParams['genres'] = genres.join(',');
      }
      if (years != null) {
        queryParams['year_min'] = years.start.round().toString();
        queryParams['year_max'] = years.end.round().toString();
      }
      if (platforms != null && platforms.isNotEmpty) {
        queryParams['platforms'] = platforms.join(',');
      }
      
      final url = queryParams.isEmpty 
          ? uri 
          : uri.replace(queryParameters: queryParams);
      
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

  // 5. FİLTRELİ FİLM GETİR (Yeni Yıldızımız)
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