// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, unused_element

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/m3u_parser.dart';
import 'models/channel.dart';
import 'screens/player_screen.dart';
import 'screens/series_screen.dart';
import 'services/storage_service.dart';
import 'screens/setup_screen.dart';
import 'package:dio/dio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MyApp());
}

// ─── Helpers globaux ─────────────────────────────────────────────────────────

bool isWideScreen(BuildContext context) =>
    kIsWeb || MediaQuery.of(context).size.width > 700;

// ─── Sidebar partagée (web) ───────────────────────────────────────────────────

class LipSidebar extends StatelessWidget {
  final int currentTab;
  final Function(int) onTabTap;
  final bool collapsed;
  final VoidCallback onToggle;

  const LipSidebar({
    super.key,
    required this.currentTab,
    required this.onTabTap,
    required this.collapsed,
    required this.onToggle,
  });

  static const _sidebarBg = Color(0xFF0D0D0D);
  static const _activeColor = Colors.white;
  static final _subColor = Colors.grey[500]!;

  static const _tabs = ['Live', 'Films', 'Séries', 'Recherche', 'Config'];
  static const _icons = [
    Icons.live_tv_rounded,
    Icons.movie_rounded,
    Icons.theaters_rounded,
    Icons.search_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 56.0 : 200.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      color: _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo / Toggle ──────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: SizedBox(
              height: 64,
              child: collapsed
                  ? Center(child: Image.asset('assets/header.png', height: 22))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                      child: Row(
                        children: [
                          Image.asset('assets/header.png', height: 22),
                          const Spacer(),
                          Icon(
                            Icons.chevron_left_rounded,
                            color: _subColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(color: Colors.white10, height: 1),
          ),
          const SizedBox(height: 6),

          // ── Nav items ─────────────────────────────────────────────
          ...List.generate(_tabs.length, (i) {
            final selected = currentTab == i;
            return Tooltip(
              message: collapsed ? _tabs[i] : '',
              preferBelow: false,
              child: GestureDetector(
                onTap: () => onTabTap(i),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 0 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: collapsed
                      ? Center(
                          child: Icon(
                            _icons[i],
                            size: 20,
                            color: selected ? _activeColor : _subColor,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              _icons[i],
                              size: 18,
                              color: selected ? _activeColor : _subColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _tabs[i],
                              style: TextStyle(
                                color: selected ? _activeColor : _subColor,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          }),

          const Spacer(),

          // ── Expand (collapsed) ────────────────────────────────────
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(
                'v1.0.1',
                style: TextStyle(color: _subColor, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── APP ─────────────────────────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lip',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      theme: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        cardColor: const Color(0xFFF5F5F5),
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/setup': (context) => const SetupScreen(),
      },
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final mode = await StorageService.getMode();
    bool hasConfig = false;
    if (mode == 'xtream') {
      final creds = await StorageService.getXtreamCredentials();
      hasConfig =
          (creds['host'] ?? '').isNotEmpty &&
          (creds['username'] ?? '').isNotEmpty &&
          (creds['password'] ?? '').isNotEmpty;
    } else {
      final url = await StorageService.getM3uUrl();
      hasConfig = url != null && url.isNotEmpty;
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, hasConfig ? '/home' : '/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ─── HOME ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Channel> _allChannels = [];
  bool _loading = true;
  int _currentTab = 0;
  String? _selectedGroup;
  final TextEditingController _search = TextEditingController();
  String _searchQuery = '';
  bool _sidebarCollapsed = true;

  // Lazy loading (web grids)
  static const _pageSize = 30;
  int _moviesPage = 1;
  int _seriesPage = 1;
  int _livePage = 1;

  // Config
  String _configMode = 'url';
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _searchHints = [
    'Rechercher une chaîne...',
    'Rechercher un film...',
    'Rechercher une série...',
    'Rechercher...',
    '',
  ];
  final _tabTitles = ['Live', 'Films', 'Séries', 'Recherche', 'Config'];
  final TextEditingController _headerSearchController = TextEditingController();
  String _headerSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _loadConfig();
  }

  @override
  void dispose() {
    _search.dispose();
    _urlController.dispose();
    _hostController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _headerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final mode = await StorageService.getMode();
    final url = await StorageService.getM3uUrl();
    final creds = await StorageService.getXtreamCredentials();
    setState(() {
      _configMode = mode;
      _urlController.text = url ?? '';
      _hostController.text = creds['host'] ?? '';
      _usernameController.text = creds['username'] ?? '';
      _passwordController.text = creds['password'] ?? '';
    });
  }

  // Proxy web pour éviter les erreurs CORS
  static String _proxyUrl(String url) {
    if (kIsWeb) return '/api/proxy?url=${Uri.encodeComponent(url)}';
    return url;
  }

  Future<void> _loadChannels() async {
    setState(() => _loading = true);
    try {
      final mode = await StorageService.getMode();
      String content;
      if (mode == 'xtream') {
        final creds = await StorageService.getXtreamCredentials();
        final host = creds['host'] ?? '';
        final username = creds['username'] ?? '';
        final password = creds['password'] ?? '';
        if (host.isEmpty || username.isEmpty || password.isEmpty) {
          content = await rootBundle.loadString('assets/playlist.m3u');
        } else {
          final url = StorageService.buildXtreamUrl(
            host: host,
            username: username,
            password: password,
          );
          final response = await Dio().get(
            _proxyUrl(url),
            options: Options(responseType: ResponseType.plain),
          );
          content = response.data.toString();
        }
      } else {
        final url = await StorageService.getM3uUrl();
        if (url != null && url.isNotEmpty) {
          final response = await Dio().get(
            _proxyUrl(url),
            options: Options(responseType: ResponseType.plain),
          );
          content = response.data.toString();
        } else {
          content = await rootBundle.loadString('assets/playlist.m3u');
        }
      }
      final channels = M3uParser.parse(content);
      setState(() {
        _allChannels = channels;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Channel> _getChannels(ChannelType type) {
    return _allChannels.where((c) {
      final matchType = c.type == type;
      final matchSearch = c.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchGroup =
          _selectedGroup == null || (c.group ?? 'Autres') == _selectedGroup;
      return matchType && matchSearch && matchGroup;
    }).toList();
  }

  List<String> _getGroups(ChannelType type) {
    final groups = _allChannels
        .where((c) => c.type == type)
        .map((c) => c.group ?? 'Autres')
        .toSet()
        .toList();
    groups.sort((a, b) {
      final aFr = RegExp(r'\bFR\b|\|FR\||FRANCE').hasMatch(a.toUpperCase());
      final bFr = RegExp(r'\bFR\b|\|FR\||FRANCE').hasMatch(b.toUpperCase());
      if (aFr && !bFr) return -1;
      if (!aFr && bFr) return 1;
      return a.compareTo(b);
    });
    return groups;
  }

  void _onTabTap(int index) {
    setState(() {
      _currentTab = index;
      _selectedGroup = null;
      _search.clear();
      _searchQuery = '';
      _headerSearchController.clear();
      _headerSearchQuery = '';
      _moviesPage = 1;
      _seriesPage = 1;
      _livePage = 1;
    });
  }

  String _getCount() {
    switch (_currentTab) {
      case 0:
        return '${_allChannels.where((c) => c.type == ChannelType.live).length} lives';
      case 1:
        return '${_allChannels.where((c) => c.type == ChannelType.movie).length} films';
      case 2:
        final shows = M3uParser.groupSeries(
          _allChannels.where((c) => c.type == ChannelType.series).toList(),
        );
        return '${shows.length} séries';
      default:
        return '';
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (isWideScreen(context)) return _buildWebLayout(context);
    return _buildMobileLayout(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEB LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWebLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141414) : const Color(0xFFF8F8F8);
    final contentBg = isDark ? const Color(0xFF141414) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final chipSelected = isDark ? Colors.white : Colors.black;
    final chipUnselected = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFEEEEEE);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/header.png', height: 200),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            )
          : Row(
              children: [
                // ── Sidebar ───────────────────────────────────────────
                LipSidebar(
                  currentTab: _currentTab,
                  onTabTap: _onTabTap,
                  collapsed: _sidebarCollapsed,
                  onToggle: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),

                // ── Main ──────────────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Top bar
                      Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: contentBg,
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.06),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _tabTitles[_currentTab].toUpperCase(),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (_getCount().isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Text(
                                _getCount(),
                                style: TextStyle(color: subColor, fontSize: 11),
                              ),
                            ],
                            const Spacer(),
                            if (_currentTab != 4)
                              SizedBox(
                                width: 320,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: TextField(
                                    controller: _headerSearchController,
                                    onChanged: (v) =>
                                        setState(() => _headerSearchQuery = v),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: _searchHints[_currentTab],
                                      hintStyle: TextStyle(
                                        color: subColor,
                                        fontSize: 13,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search_rounded,
                                        color: subColor,
                                        size: 18,
                                      ),
                                      suffixIcon: _headerSearchQuery.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () => setState(() {
                                                _headerSearchController.clear();
                                                _headerSearchQuery = '';
                                              }),
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: subColor,
                                                size: 16,
                                              ),
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Content
                      Expanded(
                        child: IndexedStack(
                          index: _currentTab,
                          children: [
                            _buildLiveWeb(
                              textColor,
                              subColor,
                              chipSelected,
                              chipUnselected,
                              isDark,
                              contentBg,
                            ),
                            _buildMediaGrid(
                              ChannelType.movie,
                              textColor,
                              subColor,
                              chipSelected,
                              chipUnselected,
                              isDark,
                              contentBg,
                            ),
                            _buildSeriesGridWeb(
                              textColor,
                              subColor,
                              chipSelected,
                              chipUnselected,
                              isDark,
                              contentBg,
                            ),
                            _buildSearch(textColor, subColor, cardBg),
                            _buildConfig(textColor, subColor, cardBg),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Live web ──────────────────────────────────────────────────────────────
  Widget _buildLiveWeb(
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
    bool isDark,
    Color bg,
  ) {
    final allChannels = _getChannels(ChannelType.live);
    final filtered = _headerSearchQuery.isEmpty
        ? allChannels
        : allChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();
    final visible = filtered.take(_livePage * _pageSize).toList();
    final hasMore = visible.length < filtered.length;
    final groups = _getGroups(ChannelType.live);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
              itemCount: visible.length + (hasMore ? 1 : 0),
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
              ),
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  // Sentinel — charge la page suivante quand visible
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _livePage++);
                  });
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final ch = visible[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: _logo(ch, 48),
                  title: Text(
                    ch.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: ch.group != null
                      ? Text(
                          ch.group!,
                          style: TextStyle(color: subColor, fontSize: 12),
                        )
                      : null,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: subColor,
                    size: 24,
                  ),
                  onTap: () => _openPlayer(ch),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Films grid web ────────────────────────────────────────────────────────
  Widget _buildMediaGrid(
    ChannelType type,
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
    bool isDark,
    Color bg,
  ) {
    final allChannels = _getChannels(type);
    final filtered = _headerSearchQuery.isEmpty
        ? allChannels
        : allChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();
    final visible = filtered.take(_moviesPage * _pageSize).toList();
    final hasMore = visible.length < filtered.length;
    final groups = _getGroups(type);

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (hasMore &&
                    notif is ScrollEndNotification &&
                    notif.metrics.pixels >=
                        notif.metrics.maxScrollExtent - 400) {
                  setState(() => _moviesPage++);
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 20,
                ),
                itemCount: visible.length + (hasMore ? 5 : 0),
                itemBuilder: (context, index) {
                  if (index >= visible.length) {
                    return _webPosterSkeleton(isDark);
                  }
                  final ch = visible[index];
                  return GestureDetector(
                    onTap: () => _openPlayer(ch),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ch.logo != null && ch.logo!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: ch.logo!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) =>
                                        _webPosterSkeleton(isDark),
                                    errorWidget: (_, __, ___) =>
                                        _webPosterPlaceholder(isDark),
                                  )
                                : _webPosterPlaceholder(isDark),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ch.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Séries grid web ───────────────────────────────────────────────────────
  Widget _buildSeriesGridWeb(
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
    bool isDark,
    Color bg,
  ) {
    final allSeries = _allChannels
        .where((c) => c.type == ChannelType.series)
        .toList();
    final shows = M3uParser.groupSeries(allSeries);
    final groups = _getGroups(ChannelType.series);

    final filteredShows = _selectedGroup == null
        ? shows.values.toList()
        : shows.values
              .where((s) => (s.group ?? 'Autres') == _selectedGroup)
              .toList();
    filteredShows.sort((a, b) => a.title.compareTo(b.title));
    final filtered = _headerSearchQuery.isEmpty
        ? filteredShows
        : filteredShows
              .where(
                (s) => s.title.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();
    final visible = filtered.take(_seriesPage * _pageSize).toList();
    final hasMore = visible.length < filtered.length;

    return Container(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notif) {
                if (hasMore &&
                    notif is ScrollEndNotification &&
                    notif.metrics.pixels >=
                        notif.metrics.maxScrollExtent - 400) {
                  setState(() => _seriesPage++);
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 20,
                ),
                itemCount: visible.length + (hasMore ? 5 : 0),
                itemBuilder: (context, index) {
                  if (index >= visible.length) {
                    return _webPosterSkeleton(isDark);
                  }
                  final show = visible[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeriesScreen(
                          show: show,
                          currentTab: _currentTab,
                          onTabTap: (i) {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                            _onTabTap(i);
                          },
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: show.logo != null && show.logo!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: show.logo!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) =>
                                        _webPosterSkeleton(isDark),
                                    errorWidget: (_, __, ___) =>
                                        _webPosterPlaceholder(isDark),
                                  )
                                : _webPosterPlaceholder(isDark),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          show.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${show.seasonCount} S · ${show.episodeCount} ép.',
                          style: TextStyle(color: subColor, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webPosterPlaceholder(bool isDark) => Container(
    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
    child: Icon(
      Icons.movie_rounded,
      color: isDark ? Colors.white24 : Colors.black26,
      size: 40,
    ),
  );

  Widget _webPosterSkeleton(bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final chipSelected = isDark ? Colors.white : Colors.black;
    final chipUnselected = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFEEEEEE);
    final navBg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);

    final tabs = ['Live', 'Films', 'Séries', 'Recherche', 'Config'];
    final icons = [
      Icons.live_tv_rounded,
      Icons.movie_rounded,
      Icons.theaters_rounded,
      Icons.search_rounded,
      Icons.settings_rounded,
    ];

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/header.png', height: 400),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            )
          : Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.of(context).padding.top + 12,
                    20,
                    12,
                  ),
                  color: bg,
                  child: Row(
                    children: [
                      if (_currentTab != 4) ...[
                        Image.asset('assets/header.png', height: 48),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _headerSearchController,
                              onChanged: (v) =>
                                  setState(() => _headerSearchQuery = v),
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: _searchHints[_currentTab],
                                hintStyle: TextStyle(
                                  color: subColor,
                                  fontSize: 13,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: subColor,
                                  size: 18,
                                ),
                                suffixIcon: _headerSearchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () => setState(() {
                                          _headerSearchController.clear();
                                          _headerSearchQuery = '';
                                        }),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: subColor,
                                          size: 16,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _getCount(),
                          style: TextStyle(color: subColor, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),

                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildLive(
                        textColor,
                        subColor,
                        chipSelected,
                        chipUnselected,
                      ),
                      _buildMediaList(
                        ChannelType.movie,
                        textColor,
                        subColor,
                        chipSelected,
                        chipUnselected,
                      ),
                      _buildSeriesGrid(
                        textColor,
                        subColor,
                        chipSelected,
                        chipUnselected,
                      ),
                      _buildSearch(textColor, subColor, cardBg),
                      _buildConfig(textColor, subColor, cardBg),
                    ],
                  ),
                ),

                // Bottom nav
                Container(
                  decoration: BoxDecoration(
                    color: navBg,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: List.generate(tabs.length, (i) {
                        final selected = _currentTab == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _onTabTap(i),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icons[i],
                                    size: 24,
                                    color: selected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : subColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tabs[i],
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black)
                                          : subColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLive(
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allChannels = _getChannels(ChannelType.live);
    final channels = _headerSearchQuery.isEmpty
        ? allChannels
        : allChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();
    final groups = _getGroups(ChannelType.live);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: channels.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            itemBuilder: (context, index) {
              final ch = channels[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                leading: _logo(ch, 52),
                title: Text(
                  ch.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: ch.group != null
                    ? Text(
                        ch.group!,
                        style: TextStyle(color: subColor, fontSize: 12),
                      )
                    : null,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: subColor,
                  size: 24,
                ),
                onTap: () => _openPlayer(ch),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaList(
    ChannelType type,
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allChannels = _getChannels(type);
    final channels = _headerSearchQuery.isEmpty
        ? allChannels
        : allChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();
    final groups = _getGroups(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: channels.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            itemBuilder: (context, index) {
              final ch = channels[index];
              return GestureDetector(
                onTap: () => _openPlayer(ch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ch.logo != null && ch.logo!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: ch.logo!,
                                width: 60,
                                height: 90,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _mediaPoster(isDark),
                                errorWidget: (_, __, ___) =>
                                    _mediaPoster(isDark),
                              )
                            : _mediaPoster(isDark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ch.name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (ch.group != null)
                              Text(
                                ch.group!,
                                style: TextStyle(color: subColor, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: subColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mediaPoster(bool isDark) => Container(
    width: 60,
    height: 90,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.movie_rounded,
      color: isDark ? Colors.white24 : Colors.black26,
      size: 28,
    ),
  );

  Widget _buildSeriesGrid(
    Color textColor,
    Color subColor,
    Color chipSelected,
    Color chipUnselected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allSeries = _allChannels
        .where((c) => c.type == ChannelType.series)
        .toList();
    final shows = M3uParser.groupSeries(allSeries);
    final groups = _getGroups(ChannelType.series);

    final filteredShows = _selectedGroup == null
        ? shows.values.toList()
        : shows.values
              .where((s) => (s.group ?? 'Autres') == _selectedGroup)
              .toList();
    filteredShows.sort((a, b) => a.title.compareTo(b.title));
    final displayShows = _headerSearchQuery.isEmpty
        ? filteredShows
        : filteredShows
              .where(
                (s) => s.title.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupChips(groups, chipSelected, chipUnselected, subColor),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: displayShows.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            itemBuilder: (context, index) {
              final show = displayShows[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesScreen(
                      show: show,
                      currentTab: _currentTab,
                      onTabTap: (i) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                        _onTabTap(i);
                      },
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: show.logo != null && show.logo!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: show.logo!,
                                width: 60,
                                height: 90,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _mediaPoster(isDark),
                                errorWidget: (_, __, ___) =>
                                    _mediaPoster(isDark),
                              )
                            : _mediaPoster(isDark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              show.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${show.seasonCount} saison${show.seasonCount > 1 ? 's' : ''} · ${show.episodeCount} ép.',
                              style: TextStyle(color: subColor, fontSize: 12),
                            ),
                            if (show.group != null)
                              Text(
                                show.group!,
                                style: TextStyle(color: subColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: subColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(Color textColor, Color subColor, Color cardBg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = _headerSearchQuery.isEmpty
        ? <Channel>[]
        : _allChannels
              .where(
                (c) => c.name.toLowerCase().contains(
                  _headerSearchQuery.toLowerCase(),
                ),
              )
              .toList();

    if (_headerSearchQuery.isEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 72,
              color: subColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Recherche dans tous\nles contenus',
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, fontSize: 16, height: 1.5),
            ),
          ],
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final ch = results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: _logo(ch, 48),
          title: Text(
            ch.name,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ch.type == ChannelType.live
                      ? 'Live'
                      : ch.type == ChannelType.movie
                      ? 'Film'
                      : 'Série',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (ch.group != null) ...[
                const SizedBox(width: 6),
                Text(
                  ch.group!,
                  style: TextStyle(color: subColor, fontSize: 11),
                ),
              ],
            ],
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: subColor,
            size: 24,
          ),
          onTap: () => _openPlayer(ch),
        );
      },
    );
  }

  Widget _buildConfig(Color textColor, Color subColor, Color cardBg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0);
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedText = isDark ? Colors.black : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.asset('assets/logo.png', width: 56, height: 56)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Lip',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Center(
            child: Text(
              '${_allChannels.length} chaînes chargées',
              style: TextStyle(color: subColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                _modeToggleBtn(
                  'url',
                  '🔗  URL Directe',
                  selectedBg,
                  selectedText,
                  textColor,
                  subColor,
                ),
                _modeToggleBtn(
                  'xtream',
                  '👤  Identifiants',
                  selectedBg,
                  selectedText,
                  textColor,
                  subColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_configMode == 'url') ...[
            _label('URL M3U', textColor),
            _field(
              _urlController,
              'http://exemple.com/playlist.m3u',
              Icons.link_rounded,
              textColor,
              subColor,
              inputBg,
            ),
          ] else ...[
            _label('Host', textColor),
            _field(
              _hostController,
              'http://monserveur.com:8080',
              Icons.dns_rounded,
              textColor,
              subColor,
              inputBg,
            ),
            const SizedBox(height: 12),
            _label('Username', textColor),
            _field(
              _usernameController,
              'username',
              Icons.person_rounded,
              textColor,
              subColor,
              inputBg,
            ),
            const SizedBox(height: 12),
            _label('Password', textColor),
            _field(
              _passwordController,
              '••••••••',
              Icons.lock_rounded,
              textColor,
              subColor,
              inputBg,
              obscure: true,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () async {
                await StorageService.saveMode(_configMode);
                if (_configMode == 'url') {
                  await StorageService.saveM3uUrl(_urlController.text.trim());
                } else {
                  await StorageService.saveXtreamCredentials(
                    host: _hostController.text.trim(),
                    username: _usernameController.text.trim(),
                    password: _passwordController.text.trim(),
                  );
                }
                setState(() => _allChannels = []);
                await _loadChannels();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Configuration sauvegardée !'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Sauvegarder et recharger',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _buildGroupChips(
    List<String> groups,
    Color chipSelected,
    Color chipUnselected,
    Color subColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: groups.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final group = isAll ? null : groups[index - 1];
          final label = isAll ? 'Tout' : group!;
          final isSelected = _selectedGroup == group;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedGroup = group;
              _moviesPage = 1;
              _seriesPage = 1;
              _livePage = 1;
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? chipSelected : chipUnselected,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : subColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _modeToggleBtn(
    String mode,
    String label,
    Color selectedBg,
    Color selectedText,
    Color textColor,
    Color subColor,
  ) {
    final isSelected = _configMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _configMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedText : subColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, Color textColor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon,
    Color textColor,
    Color subColor,
    Color bg, {
    bool obscure = false,
  }) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: TextStyle(color: textColor),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: subColor),
      prefixIcon: Icon(icon, color: subColor, size: 20),
      filled: true,
      fillColor: bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _logo(Channel ch, double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ch.logo != null && ch.logo!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: ch.logo!,
              width: size,
              height: size,
              fit: BoxFit.contain,
              placeholder: (_, __) => _logoPlaceholder(size, isDark),
              errorWidget: (_, __, ___) => _logoPlaceholder(size, isDark),
            )
          : _logoPlaceholder(size, isDark),
    );
  }

  Widget _logoPlaceholder(double size, bool isDark) => Container(
    width: size,
    height: size,
    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
    child: Icon(
      Icons.tv_rounded,
      color: isDark ? Colors.white24 : Colors.black26,
      size: size * 0.5,
    ),
  );

  Widget _gridPlaceholder() => Container(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFEEEEEE),
    child: Icon(
      Icons.movie_rounded,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white24
          : Colors.black26,
      size: 40,
    ),
  );

  void _openPlayer(Channel ch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: ch,
          initialQuality: ch.bestQuality,
          currentTab: _currentTab,
          onTabTap: (index) {
            Navigator.pop(context);
            _onTabTap(index);
          },
        ),
      ),
    );
  }
}
