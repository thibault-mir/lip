import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _mode = 'url';
  final _urlController = TextEditingController();
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Proxy pour éviter CORS sur le web
  static String _proxyUrl(String url) {
    if (kIsWeb) return '/api/proxy?url=${Uri.encodeComponent(url)}';
    return url;
  }

  Future<void> _validate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String rawUrl;

      if (_mode == 'url') {
        rawUrl = _urlController.text.trim();
        if (rawUrl.isEmpty) {
          setState(() {
            _error = 'Entre une URL valide';
            _loading = false;
          });
          return;
        }
      } else {
        final host = _hostController.text.trim();
        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();
        if (host.isEmpty || username.isEmpty || password.isEmpty) {
          setState(() {
            _error = 'Remplis tous les champs';
            _loading = false;
          });
          return;
        }
        rawUrl = StorageService.buildXtreamUrl(
          host: host,
          username: username,
          password: password,
        );
      }

      // Sur le web on passe par le proxy Vercel
      final fetchUrl = _proxyUrl(rawUrl);

      final response = await Dio().get(
        fetchUrl,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final body = response.data.toString();

      if (body.contains('#EXTM3U')) {
        // On sauvegarde l'URL d'origine (pas l'URL proxy)
        await StorageService.saveMode(_mode);
        if (_mode == 'url') {
          await StorageService.saveM3uUrl(rawUrl);
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
    } on DioException catch (e) {
      final msg = e.response?.statusCode != null
          ? 'Erreur ${e.response!.statusCode}'
          : 'Impossible de charger cette URL';
      setState(() => _error = '$msg — vérifie l\'URL ou ta connexion');
    } catch (e) {
      setState(() => _error = 'Erreur inattendue, réessaie');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final fieldBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Center(child: Image.asset('assets/header.png', height: 40)),
                const SizedBox(height: 40),

                // Titre
                Text(
                  'Configurer ma source',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Entre ton URL M3U ou tes identifiants Xtream',
                  style: TextStyle(color: subColor, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // Toggle M3U / Xtream
                Container(
                  decoration: BoxDecoration(
                    color: fieldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _tab('URL M3U', 'url', textColor, subColor, isDark),
                      _tab('Xtream', 'xtream', textColor, subColor, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Champs
                if (_mode == 'url') ...[
                  _label('URL de la playlist', subColor),
                  _field(
                    _urlController,
                    'http://exemple.com/get.php?...',
                    textColor,
                    fieldBg,
                    subColor,
                  ),
                ] else ...[
                  _label('Serveur', subColor),
                  _field(
                    _hostController,
                    'http://monserveur.com:8080',
                    textColor,
                    fieldBg,
                    subColor,
                  ),
                  const SizedBox(height: 14),
                  _label('Nom d\'utilisateur', subColor),
                  _field(
                    _usernameController,
                    'username',
                    textColor,
                    fieldBg,
                    subColor,
                  ),
                  const SizedBox(height: 14),
                  _label('Mot de passe', subColor),
                  _field(
                    _passwordController,
                    '••••••••',
                    textColor,
                    fieldBg,
                    subColor,
                    obscure: true,
                  ),
                ],

                // Erreur
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Bouton valider
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _validate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      disabledBackgroundColor: isDark
                          ? Colors.white24
                          : Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Text(
                            'Valider',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(
    String label,
    String value,
    Color textColor,
    Color subColor,
    bool isDark,
  ) {
    final selected = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _mode = value;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : subColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color subColor) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: subColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String hint,
    Color textColor,
    Color bg,
    Color subColor, {
    bool obscure = false,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    style: TextStyle(color: textColor, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: subColor, fontSize: 13),
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    onSubmitted: (_) => _validate(),
  );
}
