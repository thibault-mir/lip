import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _m3uUrlKey = 'm3u_url';
  static const _hostKey = 'xtream_host';
  static const _usernameKey = 'xtream_username';
  static const _passwordKey = 'xtream_password';
  static const _modeKey = 'connection_mode'; // 'url' ou 'xtream'

  // Mode
  static Future<String> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modeKey) ?? 'url';
  }

  static Future<void> saveMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode);
  }

  // URL directe
  static Future<String?> getM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uUrlKey);
  }

  static Future<void> saveM3uUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_m3uUrlKey, url);
  }

  // Xtream credentials
  static Future<Map<String, String?>> getXtreamCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'host': prefs.getString(_hostKey),
      'username': prefs.getString(_usernameKey),
      'password': prefs.getString(_passwordKey),
    };
  }

  static Future<void> saveXtreamCredentials({
    required String host,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
  }

  // Construit l'URL M3U depuis les credentials Xtream
  static String buildXtreamUrl({
    required String host,
    required String username,
    required String password,
  }) {
    final base = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
    return '$base/get.php?username=$username&password=$password&type=m3u_plus&output=ts';
  }
}
