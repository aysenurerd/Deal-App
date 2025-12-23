import 'package:flutter/material.dart';


class FilterScreen extends StatefulWidget {
  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  // Başlangıç değerleri
  RangeValues _currentYears = const RangeValues(2000, 2024);
  List<String> selectedGenres = [];
  String? selectedPlatform;

  final List<String> genres = ['Dram', 'Aksiyon', 'Komedi', 'Korku', 'Bilim Kurgu', 'Animasyon'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Koyu tema
      appBar: AppBar(
        title: const Text("Filtrele", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        actions: [TextButton(onPressed: () {}, child: const Text("RESET", style: TextStyle(color: Colors.grey)))]
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TARİH FİLTRESİ (Slider)
                const Text("Yayınlanma Tarihi", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                RangeSlider(
                  values: _currentYears,
                  min: 1980,
                  max: 2025,
                  divisions: 45,
                  activeColor: Colors.deepPurpleAccent,
                  labels: RangeLabels(_currentYears.start.round().toString(), _currentYears.end.round().toString()),
                  onChanged: (values) => setState(() => _currentYears = values),
                ),
                Text("${_currentYears.start.round()} - ${_currentYears.end.round()}", style: const TextStyle(color: Colors.grey)),

                const SizedBox(height: 30),

                // 2. TÜR SEÇİMİ (Açılır Kapanır)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text("Türler", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white), // Kırmızı dairedeki ok
                    children: [
                      Wrap(
                        spacing: 8,
                        children: genres.map((genre) {
                          final isSelected = selectedGenres.contains(genre);
                          return FilterChip(
                            label: Text(genre),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) selectedGenres.add(genre);
                                else selectedGenres.remove(genre);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. OYUN OLUŞTUR BUTONU (En Altta Sabit)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _showModeSelection(context), // Mod seçimine yönlendir
              child: const Text("OYUN OLUŞTUR", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // MOD SEÇİMİ (Bottom Sheet)
  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Modunu Seç", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.amber),
                title: const Text("Partnersiz (Solo)", style: TextStyle(color: Colors.white)),
                onTap: () { /* Solo oyun başla */ },
              ),
              ListTile(
                leading: const Icon(Icons.people, color: Colors.deepPurpleAccent),
                title: const Text("Partnerli (Match)", style: TextStyle(color: Colors.white)),
                onTap: () { /* Partner daveti/eşleşme */ },
              ),
            ],
          ),
        );
      },
    );
  }
}