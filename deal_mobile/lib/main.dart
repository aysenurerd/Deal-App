import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';

// --- ÖNEMLİ: Filtre ekranını buraya dahil ediyoruz ---
// Eğer klasör ismin 'screens' ise 'screens/filter_screen.dart' yap.
// Eğer 'pages' ise 'pages/filter_screen.dart' yap.
import 'pages/filter_screen.dart'; 

void main() => runApp(const DealApp());

class DealApp extends StatelessWidget {
  const DealApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deal App',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', 
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Premium Mat Siyah
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914), // Netflix Kırmızısı (Ana Renk)
          secondary: Color(0xFFFFD700), // Altın Sarısı (Yıldızlar/İkonlar)
          surface: Color(0xFF1E1E1E), // Kart Rengi
        ),
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
    for (int i = 0; i < 5; i++) {
      await _loadMoreMovies();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMoreMovies() async {
    try {
      final movie = await _apiService.fetchRandomMovie(); // Burası artık rastgele getiriyor, filtre gelince değişecek
      if (movie != null) {
        movie['trailer_url'] = "https://www.youtube.com/results?search_query=${movie['title']}+trailer";
        setState(() {
          _movies.add(movie);
        });
      }
    } catch (e) {
      print("Film yükleme hatası: $e");
    }
  }

  void _showMovieDetails(BuildContext context, Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414), // Çok koyu gri
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 30)],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 15),
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Text(movie['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text("2024", style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 10),
                  const Icon(Icons.circle, size: 5, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 18), // Altın Yıldız
                  const SizedBox(width: 5),
                  Text(movie['imdb_rating'] ?? "8.1", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [
                  _buildGenreChip(movie['genre'] ?? "Genel"),
                ],
              ),
              const SizedBox(height: 25),
              const Text("Özet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                movie['overview'] ?? "Özet bulunamadı.",
                style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 15),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914), // Kırmızı Buton
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    final Uri url = Uri.parse(movie['trailer_url']);
                    if (!await launchUrl(url)) {
                      print("Link açılamadı");
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                  label: const Text("Fragmanı İzle", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 50),
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
        color: Colors.white.withOpacity(0.05),
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
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ÜST BAŞLIK
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.person, color: Colors.transparent, size: 28),
                      const Text("DEAL", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFFE50914))),
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FilterScreen())),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- İŞTE KRİTİK KISIM BURASI ---
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                      : _movies.isEmpty 
                          // EĞER FİLM YOKSA HATA GÖSTER (SWIPER'I ÇALIŞTIRMA)
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 60),
                                  const SizedBox(height: 10),
                                  const Text("Bağlantı Kurulamadı", style: TextStyle(color: Colors.white70)),
                                  TextButton(
                                    onPressed: _startSession, 
                                    child: const Text("Tekrar Dene", style: TextStyle(color: Color(0xFFE50914)))
                                  )
                                ],
                              ),
                            )
                          // FİLM VARSA SWIPER'I ÇALIŞTIR
                          : CardSwiper(
                              controller: _swiperController,
                              cardsCount: _movies.length,
                              numberOfCardsDisplayed: _movies.length < 3 ? _movies.length : 3, // KORUMA: Liste kısaysa hata verme
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
                
                // ALT BUTONLAR
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCircleButton(Icons.close_rounded, Colors.grey, () => _swiperController.swipe(CardSwiperDirection.left)),
                      _buildCircleButton(Icons.favorite_rounded, const Color(0xFF00E676), () => _swiperController.swipe(CardSwiperDirection.right)),
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
              colors: const [Colors.red, Colors.amber, Colors.white],
            ),
          ),
        ],
      ),
    );
  }

  // --- KART TASARIMI (PREMIUM) ---
  Widget _buildMovieCard(BuildContext context, Map<String, dynamic> movie) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < -500) {
          _showMovieDetails(context, movie);
        }
      },
      onTap: () => _showMovieDetails(context, movie),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35), // Daha yuvarlak köşeler
        child: Stack(
          children: [
            // 1. Film Afişi
            Positioned.fill(
              child: Image.network(
                movie['poster_url'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: const Color(0xFF1E1E1E), child: const Icon(Icons.movie, size: 50, color: Colors.white12)),
              ),
            ),
            
            // 2. Alt Bilgi Alanı (Gradient)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.95),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie['title'], 
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914), // Yayın Tarihi Kutu
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            movie['release_date']?.toString().substring(0, 4) ?? "2024",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                        const SizedBox(width: 4),
                        Text(movie['imdb_rating'] ?? "7.0", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildGenreTag(movie['genre'] ?? "Genel"),
                          const SizedBox(width: 6),
                          _buildGenreTag(movie['platform'] ?? "Sinema"), // Dün eklediğimiz platform bilgisi
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: Icon(Icons.keyboard_arrow_up, color: Colors.white.withOpacity(0.5), size: 28)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 65, height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF181818), // Koyu buton
          border: Border.all(color: Colors.white10, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}