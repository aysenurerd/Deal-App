import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import 'login_screen.dart'; // Çıkış yapınca Login'e dönmek için

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    final userId = UserSession().userId;
    if (userId != null) {
      _profileFuture = ApiService().fetchProfile(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor; // Sarı rengimiz

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profilim"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          } else if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final data = snapshot.data!;
          final username = data['username'] ?? 'Bilinmiyor';
          final partner = data['partner_name'] ?? 'Partner Yok';
          final totalLikes = data['total_likes'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: primaryColor,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : "?",
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                
                // İsim
                Text(
                  username,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Üye",
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 30),

                // İstatistik Kartları
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard("Partner", partner, Icons.favorite, Colors.redAccent),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard("Eşleşmeler", "$totalLikes", Icons.movie, primaryColor),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Çıkış Butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900]?.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // Session'ı temizle
                      UserSession().clearSession();
                      // Login Ekranına at ve geriye dönmeyi engelle
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Çıkış Yap", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}