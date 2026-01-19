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

  // --- TASARIMINDAKİ RESMİ RENKLER ---
  final Color dealPrimary = const Color(0xFFECCB13);     // Tasarımdaki "primary"
  final Color dealBackground = const Color(0xFF221F10);  // Tasarımdaki "background-dark"
  final Color dealSurface = const Color(0xFF2D2A1D);     // Tasarımdaki "surface-dark"

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
      backgroundColor: dealBackground, // Arka plan düzeltildi
      appBar: AppBar(
        title: const Text("Collections", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: dealBackground,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _partnersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: dealPrimary));
          }

          final partners = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // 1. SOLO KÜTÜPHANE BUTONU
              _buildLibraryFolder(
                context,
                title: "Solo Kütüphanem",
                subtitle: "Your private collection",
                icon: Icons.person,
                color: dealPrimary, // İkon rengi sarı
                filterId: 'solo',
              ),
              
              const SizedBox(height: 24),
              const Text("Partner Collections", 
                style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
              const SizedBox(height: 12),

              if (partners.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("No partners added yet.", style: TextStyle(color: Colors.white24)),
                )
              else
                ...partners.map((partner) => _buildLibraryFolder(
                  context,
                  title: "${partner['name']}'s Matches",
                  subtitle: "Shared movie interest",
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  filterId: partner['id'].toString(),
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLibraryFolder(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required String filterId}) {
    return Card(
      color: dealSurface, // Kart rengi düzeltildi
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        trailing: Icon(Icons.arrow_forward_ios, color: dealPrimary, size: 16),
        onTap: () {
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
  final String filterId;

  const LibraryFolderDetailScreen({super.key, required this.folderName, required this.filterId});

  @override
  State<LibraryFolderDetailScreen> createState() => _LibraryFolderDetailScreenState();
}

class _LibraryFolderDetailScreenState extends State<LibraryFolderDetailScreen> {
  late Future<List<dynamic>> _moviesFuture;
  final Color dealPrimary = const Color(0xFFECCB13);
  final Color dealBackground = const Color(0xFF221F10);
  final Color dealSurface = const Color(0xFF2D2A1D);

  @override
  void initState() {
    super.initState();
    final userId = UserSession().userId;
    if (userId != null) {
      _moviesFuture = ApiService().fetchLibrary(userId, partnerId: widget.filterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dealBackground, // Alt ekran arka planı düzeltildi
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: dealBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _moviesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: dealPrimary));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.movie_outlined, size: 80, color: Colors.white10),
                  const SizedBox(height: 16),
                  const Text("This folder is empty!", style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final movies = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              return GestureDetector(
                onTap: () => _showFullMovieDetails(context, movie),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        movie['poster_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(color: dealSurface),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: dealPrimary, size: 10),
                              const SizedBox(width: 3),
                              Text("${movie['vote_average']}", 
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  void _showFullMovieDetails(BuildContext context, Map<String, dynamic> movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: dealSurface, // Detay paneli rengi düzeltildi
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48, height: 5,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(movie['poster_url'] ?? '', width: 110, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          movie['title'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.star, color: dealPrimary, size: 20),
                            const SizedBox(width: 6),
                            Text("${movie['vote_average']} / 10", 
                              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: dealPrimary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dealPrimary.withOpacity(0.5)),
                          ),
                          child: Text("MATCHED ✅", 
                            style: TextStyle(color: dealPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text("Overview", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                movie['overview'] ?? "No description available.",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}