import 'dart:ui'; // Buzlu cam efekti (Blur) için gerekli
import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() => runApp(const DealApp());

class DealApp extends StatelessWidget {
  const DealApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const MovieScreen(),
    );
  }
}

class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key});
  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _currentMovie;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNewMovie();
  }

  Future<void> _loadNewMovie() async {
    setState(() {
      _isLoading = true;
      _currentMovie = null; 
    });
    
    try {
      final movie = await _apiService.fetchRandomMovie();
      setState(() {
        _currentMovie = movie;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("❌ BAĞLANTI HATASI: $e"); 
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Bağlantı Sorunu"),
          content: Text("Sunucuya ulaşılamadı. IP adresini veya Python terminalini kontrol et: $e"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tamam"))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _currentMovie == null 
          ? const Center(child: Text("Yükleniyor..."))
          : Stack(
              children: [
                // 1. KATMAN: Arka Plan Afişi ve Blur (Buzlu Cam Hazırlığı)
                Positioned.fill(
                  child: Image.network(
                    _currentMovie!['poster_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.black.withOpacity(0.5)),
                  ),
                ),

                // 2. KATMAN: İçerik
                SafeArea(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("DEAL - AI MATCH", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white70)),
                      ),

                      // ANA KART (Görsel ve Hata Kontrolü)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, spreadRadius: 5)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Image.network(
                              _currentMovie!['poster_url'] ?? '',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              // --- HATA KONTROLÜ ---
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[900],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, size: 80, color: Colors.white24),
                                    SizedBox(height: 10),
                                    Text("Afiş Yüklenemedi\n(URL veya İnternet Hatası)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)),
                                  ],
                                ),
                              ),
                              // ---------------------
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                          ),
                        ),
                      ),

                      // BİLGİ PANELİ (Glassmorphism Tasarımı)
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(_currentMovie!['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))),
                                Text(_currentMovie!['release_date'] ?? "2025", style: const TextStyle(color: Colors.white54)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            
                            // BERT AI Yorum Kutusu
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: _currentMovie!['ai_result'] == "Pozitif" ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _currentMovie!['ai_result'] == "Pozitif" ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: _currentMovie!['ai_result'] == "Pozitif" ? Colors.greenAccent : Colors.redAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_currentMovie!['ai_comment'] ?? "Analiz yapılıyor...", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white))),
                                ],
                              ),
                            ),

                            const SizedBox(height: 25),
                            
                            // Kontrol Butonları
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(Icons.close, Colors.red, _loadNewMovie),
                                _buildActionButton(Icons.favorite, Colors.green, _loadNewMovie),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Şık Buton Tasarımı İçin Yardımcı Fonksiyon
  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Icon(icon, color: color, size: 35),
      ),
    );
  }
}