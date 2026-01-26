import 'token_storage.dart';

/// User roles in the system
enum UserRole {
  admin,
  collector,
}

/// Authentication service for login and role management
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final TokenStorage _storage = TokenStorage();

  /// Login with token and role
  Future<void> login({
    required String token,
    required UserRole role,
    String? username,
  }) async {
    await _storage.saveToken(token);
    await _storage.saveCustom('user_role', role.name);
    if (username != null) {
      await _storage.saveCustom('username', username);
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current user role
  Future<UserRole?> getUserRole() async {
    final roleStr = await _storage.getCustom('user_role');
    if (roleStr == null) return null;
    
    switch (roleStr) {
      case 'admin':
        return UserRole.admin;
      case 'collector':
        return UserRole.collector;
      default:
        return null;
    }
  }

  /// Get current username
  Future<String?> getUsername() async {
    return await _storage.getCustom('username');
  }

  /// Logout
  Future<void> logout() async {
    await _storage.saveToken('');
    await _storage.saveCustom('user_role', '');
    await _storage.saveCustom('username', '');
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == UserRole.admin;
  }

  /// Check if current user is collector
  Future<bool> isCollector() async {
    final role = await getUserRole();
    return role == UserRole.collector;
  }
}
