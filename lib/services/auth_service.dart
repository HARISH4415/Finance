import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  static const String _boxName = 'authBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  // Register a new user
  // Returns true if successful, false if username already exists
  static Future<bool> register(
    String username,
    String password,
    String name,
    String phone,
  ) async {
    if (_box.containsKey(username)) {
      return false; // User already exists
    }
    // Store user details as a Map
    await _box.put(username, {
      'password': password,
      'name': name,
      'phone': phone,
    });
    return true;
  }

  // Login a user
  // Returns true if successful
  static Future<bool> login(String username, String password) async {
    final userData = _box.get(username);
    if (userData != null && userData is Map) {
      if (userData['password'] == password) {
        await _box.put('currentUser', username);
        return true;
      }
    } else if (userData != null && userData is String) {
      // Fallback for old data where only password was stored
      if (userData == password) {
        await _box.put('currentUser', username);
        return true;
      }
    }
    return false;
  }

  // Logout current user
  static Future<void> logout() async {
    await _box.delete('currentUser');
  }

  // Check if a user is currently logged in
  static bool get isLoggedIn => _box.containsKey('currentUser');

  // Get current username
  static String? get currentUser => _box.get('currentUser');

  // Get current user details
  static Map<dynamic, dynamic>? get currentUserDetails {
    final username = currentUser;
    if (username != null) {
      final data = _box.get(username);
      if (data is Map) {
        return data;
      }
    }
    return null;
  }
}
