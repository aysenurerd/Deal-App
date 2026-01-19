class UserSession {
  // Singleton Yapısı (Standart)
  static final UserSession _instance = UserSession._internal();

  factory UserSession() {
    return _instance;
  }

  UserSession._internal();

  // --- ANA DEĞİŞKENLER ---
  int? userId;       // Yeni kodlar bunu kullanıyor
  String? username;  // Yeni kodlar bunu kullanıyor
  int? partnerId;    // Partner özelliği için gerekli

  // --- KÖPRÜLER (Eski kodların çalışması için) ---
  
  // 1. Eski kod 'currentUserId' isteyince, bizim 'userId'yi veriyoruz.
  int? get currentUserId => userId;
  
  // 2. Eski kod 'currentUserName' isteyince, bizim 'username'i veriyoruz.
  String? get currentUserName => username;

  // 3. Eski kod 'setUser' metodunu arıyor, onu buraya ekledik.
  void setUser(int id, String name) {
    userId = id;
    username = name;
  }

  // 4. Eski kod 'clear' diyor, yeni kod 'clearSession' diyor.
  // İkisi de aynı temizliği yapsın.
  void clear() {
    userId = null;
    username = null;
    partnerId = null;
  }

  void clearSession() {
    clear(); // Üstteki fonksiyonu çağır
  }

  // Login kontrolü
  bool get isLoggedIn => userId != null;
}