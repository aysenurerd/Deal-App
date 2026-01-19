import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  final TextEditingController _partnerController = TextEditingController();

  // --- TASARIMINDAKİ RESMİ RENKLER ---
  final Color dealPrimary = const Color(0xFFECCB13);     // Sarı/Altın
  final Color dealBackground = const Color(0xFF221F10);  // Derin Siyah Zemin
  final Color dealSurface = const Color(0xFF2D2A1D);     // Kart Yüzeyleri

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  void _refreshProfile() {
    final userId = UserSession().userId;
    if (userId != null) {
      setState(() {
        _profileFuture = ApiService().fetchProfile(userId);
      });
    }
  }

  // --- PARTNER YÖNETİM PANELİ (LİSTELE + EKLE + SİL) ---
  void _showPartnerManagementPanel() async {
    final userId = UserSession().userId;
    if (userId == null) return;

    List<Map<String, dynamic>> currentPartners = await ApiService().getPartners(userId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dealSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPanelState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Partner Yönetimi", style: TextStyle(color: dealPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              // 1. MEVCUT PARTNERLER LİSTESİ
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                child: currentPartners.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(20), child: Text("Henüz partner yok.", style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentPartners.length,
                      itemBuilder: (context, index) {
                        final p = currentPartners[index];
                        return ListTile(
                          leading: Icon(Icons.favorite, color: dealPrimary.withOpacity(0.7)),
                          title: Text(p['name'], style: const TextStyle(color: Colors.white)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              // Backend'e silme isteği atıyoruz
                              bool success = await ApiService().deletePartner(p['id']);
                              if (success) {
                                List<Map<String, dynamic>> updated = await ApiService().getPartners(userId);
                                setPanelState(() => currentPartners = updated);
                                _refreshProfile();
                              }
                            },
                          ),
                        );
                      },
                    ),
              ),
              
              const Divider(color: Colors.white12, height: 30),

              // 2. YENİ EKLEME ALANI
              TextField(
                controller: _partnerController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Yeni Partner İsmi",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: dealPrimary), borderRadius: BorderRadius.circular(12)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: dealPrimary),
                  onPressed: () async {
                    final name = _partnerController.text.trim();
                    if (name.isNotEmpty) {
                      await ApiService().addPartner(userId, name);
                      _partnerController.clear();
                      List<Map<String, dynamic>> updated = await ApiService().getPartners(userId);
                      setPanelState(() => currentPartners = updated);
                      _refreshProfile();
                    }
                  },
                  child: Text("YENİ EKLE", style: TextStyle(color: dealBackground, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dealBackground,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        automaticallyImplyLeading: false,
        backgroundColor: dealBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: dealPrimary));
          }

          final data = snapshot.data ?? {};
          final username = data['username'] ?? 'User';
          final partner = data['partner_name'] ?? 'Add Partner';
          final totalLikes = data['total_likes'] ?? 0;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // AVATAR
                CircleAvatar(
                  radius: 55,
                  backgroundColor: dealPrimary,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : "U",
                    style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: dealBackground),
                  ),
                ),
                const SizedBox(height: 24),
                Text(username, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text("Verified Member", style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 40),

                Row(
                  children: [
                    // PARTNER KARTI (Tıklanınca Yönetim Paneli Açılır)
                    Expanded(
                      child: GestureDetector(
                        onTap: _showPartnerManagementPanel,
                        child: _buildStatCard("Partner", partner, Icons.favorite, Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard("Matches", "$totalLikes", Icons.stars, dealPrimary),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // ÇIKIŞ BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      UserSession().clearSession();
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                    },
                    icon: const Icon(Icons.logout, color: Colors.white60),
                    label: const Text("Logout", style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dealSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center, maxLines: 1),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}