import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';
import '../services/user_session.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  
  const HomeScreen({super.key, this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  final ApiService _apiService = ApiService();
  int _currentPage = 0;
  bool _isLoadingPartners = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleStartPlaying(int index) {
    if (index == 0) {
      // Solo Mode - GameScreen'e yönlendir
      _navigateToGameScreen(isSolo: true);
    } else {
      // Partner Mode - Partner dialog aç
      _showPartnerDialog();
    }
  }

  void _navigateToGameScreen({required bool isSolo, int? partnerId}) {
    print("GameScreen'e yönlendiriliyor - isSolo: $isSolo, partnerId: $partnerId");
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => GameScreen(isSolo: isSolo, partnerId: partnerId),
    //   ),
    // );
  }

  Future<void> _showPartnerDialog() async {
    final userId = UserSession().currentUserId;
    if (userId == null) return;

    setState(() => _isLoadingPartners = true);
    final partners = await _apiService.getPartners(userId);
    setState(() => _isLoadingPartners = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _PartnerDialog(
        partners: partners,
        onPartnerSelected: (partnerId) {
          Navigator.pop(context);
          _navigateToGameScreen(isSolo: false, partnerId: partnerId);
        },
        onAddPartner: () async {
          Navigator.pop(context);
          await _showAddPartnerDialog();
        },
      ),
    );
  }

  Future<void> _showAddPartnerDialog() async {
    final userId = UserSession().currentUserId;
    if (userId == null) return;

    final nameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text(
          'Yeni Partner Ekle',
          style: GoogleFonts.poppins(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: 'Partnerin adı ne?',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: AppColors.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Ekle',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final response = await _apiService.addPartner(userId, nameController.text.trim());
      if (response != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partner eklendi: ${nameController.text}'),
            backgroundColor: AppColors.primary,
          ),
        );
        // Dialog'u tekrar aç ki yeni partner görünsün
        _showPartnerDialog();
      }
    }
  }

  void _navigateToListsTab() {
    if (widget.onTabChange != null) {
      widget.onTabChange!(1); // Lists tab index = 1
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = UserSession().currentUserName ?? 'User';
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Deal yazısı ve Welcome back
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Deal yazısı
                    Text(
                      'Deal',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tekrar hoş geldin,',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İyi akşamlar, $userName',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        // Profil resmi
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceDark,
                            image: const DecorationImage(
                              image: NetworkImage('https://i.pravatar.cc/150?img=12'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Carousel
              SizedBox(
                height: 400,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: 2,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildGameCard(context, index),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Hızlı Erişim / Kütüphanem
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Hızlı Erişim',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // List Items - 2 sabit kart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _buildQuickAccessCard(
                      title: 'İlgilendiklerim',
                      subtitle: 'Kişisel listen',
                      icon: Icons.person,
                      onTap: _navigateToListsTab,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickAccessCard(
                      title: 'Son Eşleşmelerim',
                      subtitle: 'Partnerli sonuçlar',
                      icon: Icons.favorite,
                      onTap: _navigateToListsTab,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, int index) {
    final isSolo = index == 0;
    final title = isSolo ? 'Solo Mod' : 'Partner Modu';
    final description = isSolo
        ? 'Tek başına oyna ve kişisel film koleksiyonunu oluştur.'
        : 'Partnerinle eşleş, filmleri oyla. İkiniz de beğendiğinizde \'Deal\' olsun!';
    final chipText = isSolo ? 'TEK KİŞİLİK' : 'ÇİFT KİŞİLİK';
    final imageUrl = isSolo
        ? 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800'
        : 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=800';

    return GestureDetector(
      onTap: () => _handleStartPlaying(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Arka plan resmi
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: AppColors.surfaceDark);
                  },
                ),
              ),

              // Gradient overlay (alttan siyaha kararan)
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
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
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
                    // Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        chipText,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Başlık
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Açıklama
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // START PLAYING Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _handleStartPlaying(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'OYUNA BAŞLA',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

// Partner Dialog Widget
class _PartnerDialog extends StatelessWidget {
  final List<Map<String, dynamic>> partners;
  final Function(int) onPartnerSelected;
  final VoidCallback onAddPartner;

  const _PartnerDialog({
    required this.partners,
    required this.onPartnerSelected,
    required this.onAddPartner,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partner Seç',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (partners.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Henüz partner eklenmemiş',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                  ),
                ),
              )
            else
              ...partners.map((partner) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => onPartnerSelected(partner['id'] as int),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                partner['name'] as String? ?? 'Partner',
                                style: GoogleFonts.poppins(
                                  color: AppColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddPartner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  'Yeni Partner Ekle',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
