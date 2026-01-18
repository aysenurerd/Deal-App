import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import '../utils/colors.dart';
import '../services/api_service.dart';

enum GameStage { loading, playingUser, transition, playingPartner, finished }

class GameScreen extends StatefulWidget {
  final bool isSolo;
  final int? partnerId;
  final String? partnerName;
  final List<String> selectedGenres;
  final List<String> selectedPlatforms;
  final RangeValues selectedYears;

  const GameScreen({
    super.key,
    required this.isSolo,
    this.partnerId,
    this.partnerName,
    required this.selectedGenres,
    required this.selectedPlatforms,
    required this.selectedYears,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  List<dynamic> _movies = [];
  final Set<int> _userLikes = {};
  final Set<int> _partnerLikes = {};
  GameStage _stage = GameStage.loading;
  String? _errorMessage;
  Key _swiperKey = UniqueKey(); // Swiper'ı resetlemek için anahtar

  @override
  void initState() {
    super.initState();
    _fetchMovies();
  }

  // --- API'den Film Çekme ---
  Future<void> _fetchMovies() async {
    setState(() {
      _stage = GameStage.loading;
      _errorMessage = null;
    });

    try {
      final movies = await ApiService.getGameMovies(
        genres: widget.selectedGenres,
        platforms: widget.selectedPlatforms,
        minYear: widget.selectedYears.start.toInt(),
        maxYear: widget.selectedYears.end.toInt(),
      );

      if (movies.isEmpty) {
        setState(() => _errorMessage = "Kriterlere uygun film bulunamadı.");
      } else {
        setState(() {
          _movies = movies;
          _stage = GameStage.playingUser;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = "Bağlantı hatası: $e");
    }
  }

  // --- Fragman Açma ---
  Future<void> _launchTrailer(String movieTitle) async {
    final Uri url = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$movieTitle trailer')}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YouTube açılamadı.')),
      );
    }
  }

  // --- Kaydırma Mantığı ---
  bool _onSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    final movie = _movies[previousIndex];
    final int movieId = movie['id'];

    // Sadece Sağa (Beğen) Kaydırma İşlemi
    if (direction == CardSwiperDirection.right) {
      if (widget.isSolo) {
        // Solo ise direkt kaydet
        ApiService.saveMatch(movieId, null);
      } else {
        // Duo ise listeye ekle
        if (_stage == GameStage.playingUser) {
          _userLikes.add(movieId);
        } else if (_stage == GameStage.playingPartner) {
          _partnerLikes.add(movieId);
        }
      }
    }

    // Oyun Bitti mi?
    if (currentIndex == null) {
      _handleStageCompletion();
    }
    return true;
  }

  // --- Aşama Yönetimi ---
  void _handleStageCompletion() {
    if (widget.isSolo) {
      setState(() => _stage = GameStage.finished);
    } else {
      if (_stage == GameStage.playingUser) {
        // Kullanıcı bitti -> Geçiş ekranı
        setState(() => _stage = GameStage.transition);
      } else if (_stage == GameStage.playingPartner) {
        // Partner bitti -> Sonuçları hesapla
        _finishDuoGame();
      }
    }
  }

  // --- Duo Oyun Sonu (Eşleşme Bulma) ---
  void _finishDuoGame() async {
    // Kesişim Kümesi (Ortak Beğeniler)
    final commonLikes = _userLikes.intersection(_partnerLikes);

    // Eşleşmeleri Kaydet
    for (int movieId in commonLikes) {
      await ApiService.saveMatch(movieId, widget.partnerId);
    }

    setState(() => _stage = GameStage.finished);
  }

  // --- Detay Menüsü (Bottom Sheet) ---
  void _showMovieDetails(BuildContext context, dynamic movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutamaç
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Başlık
            Text(
              movie['title'],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // Platform ve Yıl
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(movie['year'],
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 16),
                const Icon(Icons.tv, size: 16, color: Colors.white70),
                const SizedBox(width: 4),
                Text(movie['platforms'] ?? 'Platform Yok',
                    style: const TextStyle(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 20),
            // Türler
            Wrap(
              spacing: 8,
              children: (movie['genres'] as String).split(',').map((genre) {
                return Chip(
                  label: Text(genre.trim(),
                      style: const TextStyle(color: Colors.black)),
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text("Özet",
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  movie['overview'] ?? "Özet bulunamadı.",
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Fragman Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchTrailer(movie['title']),
                icon: const Icon(Icons.play_arrow, color: Colors.black),
                label: const Text("FRAGMANI İZLE",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI PARÇALARI ---

  Widget _buildCard(dynamic movie) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          _showMovieDetails(context, movie);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Poster
            Positioned.fill(
              child: Image.network(
                movie['poster_url'],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.grey[900]),
              ),
            ),
            // Gradient ve Bilgiler
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.6, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          movie['rating'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          movie['year'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      movie['platforms'] ?? "",
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    // Eşleşenleri Bul
    final commonIds = _userLikes.intersection(_partnerLikes);
    final commonMovies =
        _movies.where((m) => commonIds.contains(m['id'])).toList();

    if (widget.isSolo) {
      return _buildSoloResult();
    } else if (commonMovies.isNotEmpty) {
      return _buildDealResult(commonMovies);
    } else {
      return _buildNoMatchResult();
    }
  }

  Widget _buildDealResult(List<dynamic> matches) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🎉 DEAL! 🎉",
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 48,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("${matches.length} Ortak Film Bulundu!",
              style: const TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 30),
          // Eşleşenlerin Listesi (Yatay Scroll)
          SizedBox(
            height: 300,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final movie = matches[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(movie['poster_url'],
                              fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie['title'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            child: const Text("ANA SAYFAYA DÖN",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.heart_broken, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Maalesef Ortak Film Çıkmadı",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Zevkleriniz biraz farklıymış...",
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Oyunu Sıfırla
              setState(() {
                _userLikes.clear();
                _partnerLikes.clear();
                _stage = GameStage.loading;
                _swiperKey = UniqueKey();
              });
              _fetchMovies();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
            child: const Text("TEKRAR DENE",
                style: TextStyle(color: Colors.black)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Çıkış Yap",
                style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text("Bitti!",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const Text("Beğendiklerin kütüphanene eklendi.",
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
            child: const Text("ANA SAYFA",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // İÇERİK
          if (_errorMessage != null)
            Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
                ElevatedButton(
                    onPressed: _fetchMovies, child: const Text("Tekrar Dene"))
              ],
            ))
          else if (_stage == GameStage.loading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_stage == GameStage.finished)
            _buildResultScreen()
          else if (_stage == GameStage.transition)
            // GEÇİŞ EKRANI
            Container(
              color: Colors.black,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Sıra Onda!",
                      style: TextStyle(color: Colors.white70, fontSize: 20)),
                  const SizedBox(height: 10),
                  Text("Telefonu ${widget.partnerName ?? 'Partnerine'} Ver",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _stage = GameStage.playingPartner;
                        _swiperKey = UniqueKey(); // Kartları başa sar
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 20)),
                    child: const Text("HAZIRIM",
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            // OYUN ALANI (KARTLAR)
            Column(
              children: [
                const SizedBox(height: 60),
                // Üst Bilgi
                Text(
                  _stage == GameStage.playingUser
                      ? "Senin Sıran"
                      : "${widget.partnerName}'nın Sırası",
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: CardSwiper(
                    key: _swiperKey, // Resetleme için önemli
                    controller: _swiperController,
                    cardsCount: _movies.length,
                    numberOfCardsDisplayed: 3,
                    backCardOffset: const Offset(0, 40),
                    padding: const EdgeInsets.all(24),
                    cardBuilder: (context, index, percentThresholdX,
                            percentThresholdY) =>
                        _buildCard(_movies[index]),
                    onSwipe: _onSwipe,
                  ),
                ),
                // Butonlar
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        heroTag: "pass",
                        backgroundColor: Colors.grey[900],
                        onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
                        child: const Icon(Icons.close, color: Colors.red),
                      ),
                      const SizedBox(width: 40),
                      FloatingActionButton(
                        heroTag: "like",
                        backgroundColor: AppColors.surfaceDark,
                        onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
                        child: const Icon(Icons.favorite,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // GERİ BUTONU (HER ZAMAN EN ÜSTTE)
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}