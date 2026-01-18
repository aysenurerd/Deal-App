import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../utils/colors.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

enum GameStage {
  loading,
  playingUser,
  transition,
  playingPartner,
  finished,
}

class GameScreen extends StatefulWidget {
  final bool isSolo;
  final int? partnerId;
  final String? partnerName;
  final RangeValues selectedYears;
  final List<String> selectedPlatforms;
  final List<String> selectedGenres;

  const GameScreen({
    super.key,
    required this.isSolo,
    this.partnerId,
    this.partnerName,
    required this.selectedYears,
    required this.selectedPlatforms,
    required this.selectedGenres,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _movies = [];
  Set<int> _userLikes = {};
  Set<int> _partnerLikes = {};
  GameStage _stage = GameStage.loading;
  int _currentCardIndex = 0;
  Key _swiperKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() => _stage = GameStage.loading);
    
    final movies = await _apiService.getGameMovies(
      genres: widget.selectedGenres,
      years: widget.selectedYears,
      platforms: widget.selectedPlatforms,
    );
    
    if (mounted) {
      setState(() {
        _movies = movies;
        if (movies.isEmpty) {
          _stage = GameStage.loading; // Hata durumu için özel stage eklenebilir
        } else {
          _stage = widget.isSolo ? GameStage.playingUser : GameStage.playingUser;
        }
      });
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (_movies.isEmpty || previousIndex >= _movies.length) return false;

    final movieId = _movies[previousIndex]['id'] as int;
    final isLike = direction == CardSwiperDirection.right;

    if (_stage == GameStage.playingUser) {
      if (isLike) {
        _userLikes.add(movieId);
        
        // Solo modda direkt kaydet
        if (widget.isSolo) {
          final userId = UserSession().currentUserId;
          if (userId != null) {
            _apiService.saveMatch(userId, movieId);
          }
        }
      }
      
      // Son kart mı kontrol et
      if (currentIndex == null || currentIndex >= _movies.length - 1) {
        if (widget.isSolo) {
          setState(() => _stage = GameStage.finished);
        } else {
          setState(() => _stage = GameStage.transition);
        }
        return true;
      }
    } else if (_stage == GameStage.playingPartner) {
      if (isLike) {
        _partnerLikes.add(movieId);
      }
      
      // Son kart mı kontrol et
      if (currentIndex == null || currentIndex >= _movies.length - 1) {
        _finishGame();
        return true;
      }
    }

    setState(() => _currentCardIndex = currentIndex ?? 0);
    return true;
  }

  void _finishGame() {
    final matches = _userLikes.intersection(_partnerLikes);
    
    if (matches.isNotEmpty) {
      // Eşleşmeleri kaydet
      final userId = UserSession().currentUserId;
      if (userId != null && widget.partnerId != null) {
        for (final movieId in matches) {
          _apiService.saveMatch(userId, movieId, partnerId: widget.partnerId);
        }
      }
    }
    
    setState(() => _stage = GameStage.finished);
  }

  void _startPartnerTurn() {
    setState(() {
      _stage = GameStage.playingPartner;
      _currentCardIndex = 0;
      // Key'i değiştirerek CardSwiper'ı sıfırla
      _swiperKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Alt katman: Oyun içeriği
            _buildStageContent(),
            
            // Üst katman: Geri dön butonu
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  color: AppColors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case GameStage.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      
      case GameStage.transition:
        return _buildTransitionScreen();
      
      case GameStage.finished:
        return _buildFinishedScreen();
      
      case GameStage.playingUser:
      case GameStage.playingPartner:
        return _buildPlayingScreen();
    }
  }

  Widget _buildPlayingScreen() {
    if (_movies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.movie_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                'Film bulunamadı',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Filtrelerinize uygun film bulunamadı.\nLütfen farklı filtreler deneyin.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loadMovies,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'TEKRAR DENE',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Üst bilgi
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _stage == GameStage.playingUser ? 'Senin Turun' : '${widget.partnerName ?? "Partner"} Turu',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              Text(
                '${_currentCardIndex + 1}/${_movies.length}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),

        // Kartlar
        Expanded(
          child: CardSwiper(
            key: _swiperKey,
            controller: _swiperController,
            cardsCount: _movies.length,
            allowedSwipeDirection: const AllowedSwipeDirection.only(
              left: true,
              right: true,
            ),
            onSwipe: _onSwipe,
            cardBuilder: (context, index, horizontalThreshold, verticalThreshold) {
              return _buildMovieCard(_movies[index]);
            },
          ),
        ),

        // Kontrol butonları
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.close,
                color: Colors.grey[600]!,
                onTap: () => _swiperController.swipe(CardSwiperDirection.left),
              ),
              _buildControlButton(
                icon: Icons.favorite,
                color: AppColors.primary,
                onTap: () => _swiperController.swipe(CardSwiperDirection.right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> movie) {
    final posterUrl = movie['poster_url'] as String? ?? '';
    final title = movie['title'] as String? ?? 'Bilinmeyen Film';
    final year = movie['year'] as String? ?? '';
    final rating = movie['rating'] as String? ?? '0.0';
    final genres = movie['genres'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Poster
            Positioned.fill(
              child: Image.network(
                posterUrl.isNotEmpty ? posterUrl : 'https://via.placeholder.com/500',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surfaceDark,
                    child: const Icon(
                      Icons.movie,
                      size: 100,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // İçerik
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Film adı
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Yıl ve Puan
                  Row(
                    children: [
                      if (year.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            year,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(
                        Icons.star,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Türler
                  if (genres.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genres.split(', ').map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            genre.trim(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceDark,
          border: Border.all(color: Colors.white10, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }

  Widget _buildTransitionScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sıra ${widget.partnerName ?? "Partner"}\'nda!',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Telefonu ona ver.',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startPartnerTurn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'HAZIRIM',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final matches = widget.isSolo
        ? _userLikes
        : _userLikes.intersection(_partnerLikes);
    
    final matchedMovies = _movies.where((m) => matches.contains(m['id'])).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          
          if (widget.isSolo)
            Text(
              'Harika! Seçimlerin kütüphanene eklendi.',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            )
          else if (matches.isEmpty)
            Text(
              'Maalesef Ortak Film Çıkmadı',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            )
          else
            Text(
              'DEAL! ${matches.length} Tane Eşleşme Var',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),

          const SizedBox(height: 40),

          if (matchedMovies.isNotEmpty)
            ...matchedMovies.map((movie) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            movie['poster_url'] as String? ?? '',
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 90,
                                color: Colors.grey[800],
                                child: const Icon(Icons.movie, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                movie['title'] as String? ?? 'Bilinmeyen',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                movie['year'] as String? ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'ANA SAYFAYA DÖN',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
