import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';

// --- ANA EKRAN: KLASÖRLER ---
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late Future<List<Map<String, dynamic>>> _partnersFuture;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  void _loadPartners() {
    final userId = UserSession().userId;
    if (userId != null) {
      _partnersFuture = ApiService().getPartners(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kütüphanelerim 📂"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _partnersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final partners = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. SOLO KÜTÜPHANE BUTONU
              _buildLibraryFolder(
                context,
                title: "Solo Kütüphanem",
                subtitle: "Kendin için seçtiklerin",
                icon: Icons.person,
                color: Colors.amber,
                filterId: 'solo', // Backend'e 'solo' diyeceğiz
              ),
              
              const SizedBox(height: 20),
              const Text("Partner Koleksiyonları", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // 2. PARTNER BUTONLARI (Varsa Listelenir)
              if (partners.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Henüz partner eklenmemiş.", style: TextStyle(color: Colors.grey)),
                )
              else
                ...partners.map((partner) => _buildLibraryFolder(
                  context,
                  title: "${partner['name']} ile Ortaklar",
                  subtitle: "Eşleşen filmleriniz",
                  icon: Icons.favorite,
                  color: Colors.pinkAccent,
                  filterId: partner['id'].toString(), // Backend'e ID göndereceğiz
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLibraryFolder(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required String filterId}) {
    return Card(
      color: const Color(0xFF2C2C2E),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: () {
          // Klasöre tıklayınca Detay Ekranına git
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LibraryFolderDetailScreen(
                folderName: title,
                filterId: filterId,
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- ALT EKRAN: FİLM LİSTESİ (Izgara Görünümü) ---
class LibraryFolderDetailScreen extends StatefulWidget {
  final String folderName;
  final String filterId; // 'solo' veya partner ID'si

  const LibraryFolderDetailScreen({super.key, required this.folderName, required this.filterId});

  @override
  State<LibraryFolderDetailScreen> createState() => _LibraryFolderDetailScreenState();
}

class _LibraryFolderDetailScreenState extends State<LibraryFolderDetailScreen> {
  late Future<List<dynamic>> _moviesFuture;

  @override
  void initState() {
    super.initState();
    final userId = UserSession().userId;
    if (userId != null) {
      // Filtreli istek atıyoruz
      _moviesFuture = ApiService().fetchLibrary(userId, partnerId: widget.filterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_outlined, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  const Text("Bu klasör henüz boş!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final movies = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return GestureDetector(
                onTap: () => _showFullMovieDetails(context, movie),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        movie['poster_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(color: Colors.grey),
                      ),
                      // Üstüne Puan Etiketi
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 4),
                              Text("${movie['vote_average']}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- DETAY PENCERESİ (GELİŞMİŞ) ---
  void _showFullMovieDetails(BuildContext context, Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      isScrollControlled: true, // Tam ekran olabilsin diye
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Ekranın %60'ı kadar açılsın
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Başlık ve Kapatma Çubuğu
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              
              // 2. Afiş ve Yan Bilgiler
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(movie['poster_url'] ?? '', width: 100, height: 150, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie['title'] ?? 'İsimsiz',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 5),
                            Text("${movie['vote_average']} / 10", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Text("MATCHED! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 25),
              const Divider(color: Colors.grey),
              const SizedBox(height: 15),

              // 3. Özet (Overview) - ARTIK BURASI DOLU GELECEK
              const Text("Özet", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                movie['overview'] ?? "Detay yok.",
                style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}