import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _mode = 'url';
  bool _loading = false;
  String? _error;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _validate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String url;

      if (_mode == 'url') {
        url = _urlController.text.trim();
        if (url.isEmpty) {
          setState(() => _error = 'Entre une URL valide');
          _loading = false; // Ne pas oublier de reset le loading
          return;
        }
      } else {
        final host = _hostController.text.trim();
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();
        if (host.isEmpty || username.isEmpty || password.isEmpty) {
          setState(() => _error = 'Remplis tous les champs');
          _loading = false;
          return;
        }
        url = StorageService.buildXtreamUrl(
          host: host,
          username: username,
          password: password,
        );
      }

      // --- LE FIX POUR LE WEB ---
      String finalUrl = url;
      if (kIsWeb) {
        // On appelle notre propre fonction Vercel
        finalUrl = "/api/proxy?url=" + Uri.encodeComponent(url);
      }
      // --------------------------

      final dio = Dio();
      final response = await dio.get(
        finalUrl, // On utilise l'URL potentiellement modifiée
        options: Options(responseType: ResponseType.plain),
      );

      if (response.data.toString().contains('#EXTM3U')) {
        await StorageService.saveMode(_mode);
        if (_mode == 'url') {
          await StorageService.saveM3uUrl(
            url,
          ); // On sauvegarde l'URL d'origine (pas le proxy)
        } else {
          await StorageService.saveXtreamCredentials(
            host: _hostController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          );
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        setState(() => _error = 'URL invalide — fichier M3U non détecté');
      }
    } catch (e) {
      // Pour debug, tu peux afficher l'erreur réelle dans la console
      print("Erreur de chargement: $e");
      setState(
        () => _error = 'Impossible de charger cette URL (CORS ou Réseau)',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final searchBg = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFEEEEEE);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Logo
              Center(
                child: Image.asset('assets/logo.png', width: 160, height: 160),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Configure ta source IPTV',
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),

              // Toggle mode
              Container(
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mode = 'url'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mode == 'url'
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '🔗 URL Directe',
                              style: TextStyle(
                                color: _mode == 'url'
                                    ? Colors.white
                                    : subTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mode = 'xtream'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _mode == 'xtream'
                                ? Colors.blueAccent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '👤 Identifiants',
                              style: TextStyle(
                                color: _mode == 'xtream'
                                    ? Colors.white
                                    : subTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mode URL
              if (_mode == 'url') ...[
                Text(
                  'URL M3U',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'http://exemple.com/playlist.m3u',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(
                      Icons.link,
                      color: Colors.blueAccent,
                    ),
                    filled: true,
                    fillColor: searchBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              // Mode Xtream
              if (_mode == 'xtream') ...[
                Text(
                  'Host',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hostController,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'http://monserveur.com:8080',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(Icons.dns, color: Colors.blueAccent),
                    filled: true,
                    fillColor: searchBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Username',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'username',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: Colors.blueAccent,
                    ),
                    filled: true,
                    fillColor: searchBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Password',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  style: TextStyle(color: textColor),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Colors.blueAccent,
                    ),
                    filled: true,
                    fillColor: searchBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _validate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Charger la liste',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
