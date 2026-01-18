class UserSession {
  static final UserSession _instance = UserSession._internal();
  
  factory UserSession() {
    return _instance;
  }
  
  UserSession._internal();

  int? currentUserId;
  String? currentUserName;

  void setUser(int userId, String userName) {
    currentUserId = userId;
    currentUserName = userName;
  }

  void clear() {
    currentUserId = null;
    currentUserName = null;
  }

  bool get isLoggedIn => currentUserId != null;
}
