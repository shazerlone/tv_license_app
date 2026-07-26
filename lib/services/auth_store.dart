import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/session.dart';

/// Persists the auth session (JWT + user) so the app remembers the user across
/// launches and can open straight to the home screen. Cleared on sign-out.
class AuthStore {
  static const _kToken = 'auth.token';
  static const _kUser = 'auth.user';

  static Future<void> save({String? token, required UserProfile user}) async {
    final p = await SharedPreferences.getInstance();
    if (token != null) await p.setString(_kToken, token);
    await p.setString(_kUser, jsonEncode(user.toJson()));
  }

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
  }

  static Future<({String? token, UserProfile? user})> load() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString(_kToken);
    final rawUser = p.getString(_kUser);
    UserProfile? user;
    if (rawUser != null) {
      try {
        user = UserProfile.fromJson((jsonDecode(rawUser) as Map).cast<String, dynamic>());
      } catch (_) {
        user = null;
      }
    }
    return (token: token, user: user);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUser);
  }
}
