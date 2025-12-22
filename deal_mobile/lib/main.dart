import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart'; // Fragman linkini açmak için (pubspec.yaml'a ekle: url_launcher)

void main() => runApp(const DealApp());

class DealApp extends StatelessWidget {
  const DealApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', // Varsa özel fontun buraya ekle
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
  final CardSwiperController _swiperController = CardSwiperController();
  late ConfettiController _confettiController;
  
  List<Map<String, dynamic>> _movies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _startSession();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() => _isLoading = true);
    // Başlangıç için 5 film çekelim
    for (int i = 0; i < 5; i++) {
      await _loadMoreMovies();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreMovies() async {
    try {
      final movie = await _apiService.fetchRandomMovie();
      if (movie != null) {
        // Fragman linki yoksa, YouTube arama linki oluştur
        movie['trailer_url'] = "https://www.youtube.com/results?search_query=${movie['title']}+trailer";
        setState(() {
          _movies.add(movie);
        });
      }
    } catch (e) {
      print("Film yükleme hatası: $e");
    }
  }

  // --- KRİTİK NOKTA: DETAY PANELİNİ AÇAN FONKSİYON ---
  void _showMovieDetails(BuildContext context, Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Tam ekran boyuna yakın açılmasını sağlar
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Ekranın %60'ı kadar açılsın
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Dune tarzı koyu gri arka plan
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            controller: controller,
            children: [
              // Tutamaç Çubuğu (Gri Çizgi)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(10)),
                ),
              ),

              // Başlık
              Text(movie['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),

              // Bilgi Satırı (Yıl • Puan • Süre)
              Row(
                children: [
                  Text("2024", style: TextStyle(color: Colors.grey[400])), // Yıl verisi varsa buraya ekle
                  const SizedBox(width: 10),
                  const Icon(Icons.circle, size: 5, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 5),
                  Text(movie['imdb_rating'] ?? "8.1", style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  const Icon(Icons.circle, size: 5, color: Colors.grey),
                  const SizedBox(width: 10),
                  Text("2s 46dk", style: TextStyle(color: Colors.grey[400])), // Süre verisi varsa buraya
                ],
              ),
              const SizedBox(height: 20),

              // Türler (Chips)
              Wrap(
                spacing: 10,
                children: [
                  _buildGenreChip(movie['genre'] ?? "Bilim Kurgu"),
                  _buildGenreChip("Macera"), // Örnek
                  _buildGenreChip("Dram"),   // Örnek
                ],
              ),
              const SizedBox(height: 25),

              // "Synopsis" (Özet) Başlığı
              const Text("Özet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                movie['overview'] ?? "Bu filmin özeti bulunmuyor.",
                style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 30),

              // Fragman Butonu (YouTube)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse(movie['trailer_url']);
                    if (!await launchUrl(url)) {
                      print("Link açılamadı: $url");
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                  label: const Text("Fragmanı İzle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Arka Plan
          if (_movies.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                _movies.first['poster_url'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.black),
              ),
            ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Daha güçlü blur
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 5),
                  child: Text("DEAL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white)),
                ),
                
                Expanded(
                  child: _isLoading && _movies.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : CardSwiper(
                          controller: _swiperController,
                          cardsCount: _movies.length,
                          numberOfCardsDisplayed: 3,
                          // --- ÖNEMLİ: KARTI SADECE YATAY KAYDIRMAYA İZİN VER ---
                          // Böylece yukarı çektiğinde kart gitmez, detay açılır.
                          allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true), 
                          onSwipe: (previousIndex, currentIndex, direction) {
                            if (direction == CardSwiperDirection.right) _confettiController.play();
                            if (currentIndex != null && currentIndex >= _movies.length - 2) _loadMoreMovies();
                            return true;
                          },
                          padding: const EdgeInsets.all(24.0),
                          cardBuilder: (context, index, horizontalOffsetPercentage, verticalOffsetPercentage) {
                            return _buildMovieCard(context, _movies[index]);
                          },
                        ),
                ),
                
                // Alt Butonlar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircleButton(Icons.close, Colors.red, () => _swiperController.swipe(CardSwiperDirection.left)),
                      _buildCircleButton(Icons.favorite, Colors.green, () => _swiperController.swipe(CardSwiperDirection.right)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.pink],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(BuildContext context, Map<String, dynamic> movie) {
    // --- GESTURE DETECTOR: YUKARI KAYDIRMAYI BURASI ALGILAR ---
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Eğer parmak yukarı doğru hızlıca gittiyse (-velocity)
        if (details.primaryVelocity! < -500) {
          _showMovieDetails(context, movie);
        }
      },
      onTap: () => _showMovieDetails(context, movie), // Tıklayınca da açsın
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Afiş
            Positioned.fill(
              child: Image.network(
                movie['poster_url'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.movie, size: 50, color: Colors.white24)),
              ),
            ),
            
            // Alt Bilgi Alanı (Gradient)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                    stops: const [0.5, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(movie['title'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 5),
                        Text(movie['imdb_rating'] ?? "7.5", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 15),
                        Text(movie['genre'] ?? "Film", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Yukarı Kaydır İpucu Oku
                    const Center(child: Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 30)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}