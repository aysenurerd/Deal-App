import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';
import 'game_screen.dart';

class FilterScreen extends StatefulWidget {
  final bool isSolo;
  final int? partnerId;
  final String? partnerName;

  const FilterScreen({
    super.key,
    required this.isSolo,
    this.partnerId,
    this.partnerName,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  RangeValues _yearRange = const RangeValues(1970, 2025);
  final Set<String> _selectedPlatforms = {};
  final Set<String> _selectedGenres = {};

  final List<String> _platforms = [
    'Netflix',
    'Prime Video',
    'Disney+',
    'Apple TV',
  ];

  final List<String> _genres = [
    'Aksiyon',
    'Komedi',
    'Dram',
    'Korku',
    'Bilim Kurgu',
    'Romantik',
    'Animasyon',
  ];

  void _navigateToGameScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          isSolo: widget.isSolo,
          partnerId: widget.partnerId,
          selectedYears: RangeValues(_yearRange.start, _yearRange.end),
          selectedPlatforms: _selectedPlatforms.toList(),
          selectedGenres: _selectedGenres.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        color: AppColors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Filtreler',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                      // Sağ tarafta boşluk için görünmez bir widget
                      const SizedBox(width: 48),
                    ],
                  ),
                  if (!widget.isSolo && widget.partnerName != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Text(
                        '${widget.partnerName} ile aranıyor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Yıl Aralığı
                    _buildSectionTitle('Yıl Aralığı'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_yearRange.start.round()} - ${_yearRange.end.round()}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RangeSlider(
                            values: _yearRange,
                            min: 1970,
                            max: 2025,
                            divisions: 55,
                            activeColor: AppColors.primary,
                            inactiveColor: Colors.grey[700],
                            onChanged: (RangeValues values) {
                              setState(() {
                                _yearRange = values;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Platformlar
                    _buildSectionTitle('Platformlar'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _platforms.map((platform) {
                        final isSelected = _selectedPlatforms.contains(platform);
                        return ChoiceChip(
                          label: Text(
                            platform,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.black : AppColors.white,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPlatforms.add(platform);
                              } else {
                                _selectedPlatforms.remove(platform);
                              }
                            });
                          },
                          backgroundColor: AppColors.surfaceDark,
                          selectedColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Türler
                    _buildSectionTitle('Türler'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _genres.map((genre) {
                        final isSelected = _selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(
                            genre,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.black : AppColors.white,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedGenres.add(genre);
                              } else {
                                _selectedGenres.remove(genre);
                              }
                            });
                          },
                          backgroundColor: AppColors.surfaceDark,
                          selectedColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Alt Buton
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _navigateToGameScreen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'OYUNA BAŞLA',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      ),
    );
  }
}
