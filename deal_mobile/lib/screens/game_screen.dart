import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() {
      _stage = GameStage.loading;
      _errorMessage = null;
    });
    
    try {
      final movies = await _apiService.getGameMovies(
        genres: widget.selectedGenres.isNotEmpty ? widget.selectedGenres : null,
        years: widget.selectedYears,
        platforms: widget.selectedPlatforms.isNotEmpty ? widget.selectedPlatforms : null,
      );
      
      if (mounted) {
        setState(() {
          _movies = movies;
          if (movies.isEmpty) {
            _errorMessage = 'Filtrelerinize uygun film bulunamadı.\nLütfen farklı filtreler deneyin.';
            _stage = GameStage.loading; // Hata durumu için loading stage'de kalıyoruz
          } else {
            _stage = widget.isSolo ? GameStage.playingUser : GameStage.playingUser;
            _currentCardIndex = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Filmler yüklenirken bir hata oluştu.\nLütfen tekrar deneyin.';
          _stage = GameStage.loading;
        });
      }
    }
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (_movies.isEmpty || previousIndex >= _movies.length) return false;

    // ID'yi güvenli şekilde int'e çevir
    final movieIdRaw = _movies[previousIndex]['id'];
    final movieId = int.parse(movieIdRaw.toString());
    final isLike = direction == CardSwiperDirection.right;

    // Son kart kontrolü - previousIndex son kartın index'i mi?
    final isLastCard = previousIndex == _movies.length - 1;

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
      
      // Son kart mı kontrol et - hem currentIndex hem de previousIndex kontrolü
      if (isLastCard || currentIndex == null || currentIndex >= _movies.length) {
        // Swipe işlemini tamamla ama stage'i değiştir
        Future.microtask(() {
          if (mounted) {
            if (widget.isSolo) {
              setState(() => _stage = GameStage.finished);
            } else {
              setState(() => _stage = GameStage.transition);
            }
          }
        });
        return true; // Swipe işlemini tamamla
      }
    } else if (_stage == GameStage.playingPartner) {
      if (isLike) {
        _partnerLikes.add(movieId);
      }
      
      // Son kart mı kontrol et
      if (isLastCard || currentIndex == null || currentIndex >= _movies.length) {
        // Swipe işlemini tamamla ama stage'i değiştir
        Future.microtask(() {
          _finishGame();
        });
        return true; // Swipe işlemini tamamla
      }
    }

    setState(() => _currentCardIndex = currentIndex ?? 0);
    return true;
  }

  Future<void> _finishGame() async {
    // ID'leri int'e çevirerek eşleşmeleri bul
    final userLikesInt = _userLikes;
    final partnerLikesInt = _partnerLikes;
    final matches = userLikesInt.intersection(partnerLikesInt);
    
    if (matches.isNotEmpty) {
      // Eşleşmeleri kaydet
      final userId = UserSession().currentUserId;
      if (userId != null && widget.partnerId != null) {
        for (final movieId in matches) {
          await _apiService.saveMatch(userId, movieId, partnerId: widget.partnerId);
        }
      }
    }
    
    if (mounted) {
      setState(() => _stage = GameStage.finished);
    }
  }

  void _startPartnerTurn() {
    setState(() {
      _stage = GameStage.playingPartner;
      _currentCardIndex = 0;
      // Key'i değiştirerek CardSwiper'ı sıfırla (kartları başa sar)
      _swiperKey = UniqueKey();
    });
  }

  void _showMovieDetails(Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildMovieDetailsSheet(movie),
    );
  }

  Future<void> _watchTrailer(String title) async {
    final query = Uri.encodeComponent('$title trailer');
    final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fragman açılamadı')),
        );
      }
    }
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
            
            // Üst katman: Geri dön butonu (HER ZAMAN görünür)
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
        if (_errorMessage != null) {
          return _buildErrorScreen();
        }
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

  Widget _buildErrorScreen() {
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
              _errorMessage ?? 'Bir hata oluştu',
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

  Widget _buildPlayingScreen() {
    if (_movies.isEmpty) {
      return _buildErrorScreen();
    }

    return Column(
      children: [
        // Üst bilgi
        Padding(
          padding: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _stage == GameStage.playingUser 
                    ? 'Senin Turun' 
                    : '${widget.partnerName ?? "Partner"} Turu',
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
            isLoop: false, // Döngüyü kapat
            cardBuilder: (context, index, horizontalThreshold, verticalThreshold) {
              if (index >= _movies.length) {
                return const SizedBox.shrink(); // Geçersiz index için boş widget
              }
              return GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                    // Yukarı kaydırma - detayları göster
                    _showMovieDetails(_movies[index]);
                  }
                },
                child: _buildMovieCard(_movies[index]),
              );
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
    final platform = movie['platforms'] as String? ?? '';

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
          fit: StackFit.expand,
          children: [
            // Poster - Tam ekran
            Image.network(
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

            // Gradient overlay (Alt tarafta)
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

            // İçerik (Alt tarafta gradient üzerinde)
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
                  
                  // Yıl ve Puan (Yıldız ikonlu)
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
                  
                  // Platform bilgisi
                  if (platform.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        platform,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Detaylar için kaydır uyarısı
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Detaylar için kaydır',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieDetailsSheet(Map<String, dynamic> movie) {
    final title = movie['title'] as String? ?? 'Bilinmeyen Film';
    final genres = movie['genres'] as String? ?? '';
    final platform = movie['platforms'] as String? ?? '';
    final overview = movie['overview'] as String? ?? 'Özet bulunamadı.';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Film adı
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),

                const SizedBox(height: 24),

                // Türler (Chip)
                if (genres.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.split(', ').map((genre) {
                      return Chip(
                        label: Text(
                          genre.trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        labelStyle: const TextStyle(color: AppColors.primary),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Platform (Chip)
                if (platform.isNotEmpty) ...[
                  Chip(
                    label: Text(
                      platform,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    side: BorderSide(color: AppColors.primary, width: 1.5),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                ],

                // Özet
                Text(
                  'Özet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  overview,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[300],
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 32),

                // FRAGMANI İZLE butonu (Sarı)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _watchTrailer(title);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'FRAGMANI İZLE',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
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

  void _showRandomMovieDialog(List<Map<String, dynamic>> movies) {
    if (movies.isEmpty) return;
    
    final random = movies.toList()..shuffle();
    final selectedMovie = random.first;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                selectedMovie['poster_url'] as String? ?? '',
                width: 200,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 300,
                    color: Colors.grey[800],
                    child: const Icon(Icons.movie, color: Colors.grey, size: 60),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              selectedMovie['title'] as String? ?? 'Bilinmeyen',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              selectedMovie['year'] as String? ?? '',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'TAMAM',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedScreen() {
    if (widget.isSolo) {
      // Solo mod için mevcut mantık
      final matchedMovies = _movies.where((m) {
        final movieId = int.parse(m['id'].toString());
        return _userLikes.contains(movieId);
      }).toList();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Harika! Seçimlerin kütüphanene eklendi.',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
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
            
            // DEVAM ET butonu (Yeni 5 Film)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _stage = GameStage.loading;
                    _swiperKey = UniqueKey();
                    _currentCardIndex = 0;
                  });
                  _loadMovies();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'DEVAM ET (YENİ 5 FİLM)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ANA SAYFAYA DÖN butonu
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceDark,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.primary, width: 2),
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

    // Duo mod için yeni mantık
    final matches = _userLikes.intersection(_partnerLikes);
    
    // ID'leri int'e çevirerek eşleşen filmleri bul
    final matchedMovies = _movies.where((m) {
      final movieId = int.parse(m['id'].toString());
      return matches.contains(movieId);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          
          // Senaryo yönetimi
          if (matches.isEmpty)
            // Eşleşme yoksa
            Column(
              children: [
                Text(
                  'Maalesef Ortak Film Yok',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // Oyunu yeniden başlat
                      setState(() {
                        _userLikes.clear();
                        _partnerLikes.clear();
                        _currentCardIndex = 0;
                        _swiperKey = UniqueKey();
                        _stage = GameStage.playingUser;
                      });
                    },
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceDark,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.primary, width: 2),
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
              ],
            )
          else if (matches.length == 1)
            // Tek eşleşme
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEAL!',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 40),
                if (matchedMovies.isNotEmpty)
                  Container(
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
                            matchedMovies.first['poster_url'] as String? ?? '',
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 120,
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
                                matchedMovies.first['title'] as String? ?? 'Bilinmeyen',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                matchedMovies.first['year'] as String? ?? '',
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
              ],
            )
          else
            // Birden çok eşleşme
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEAL! ${matches.length} Tane Film Bulundu',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Yatay liste
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: matchedMovies.length,
                    itemBuilder: (context, index) {
                      final movie = matchedMovies[index];
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                movie['poster_url'] as String? ?? '',
                                width: 140,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 140,
                                    height: 200,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.movie, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              movie['title'] as String? ?? 'Bilinmeyen',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Karasız Kaldık: Rastgele Seç butonu
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _showRandomMovieDialog(matchedMovies),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'KARARSIZ KALDIK: RASTGELE SEÇ 🎲',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceDark,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.primary, width: 2),
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
              ],
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
