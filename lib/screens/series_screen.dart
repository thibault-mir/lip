import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../models/series_show.dart';
import '../models/channel.dart';
import '../main.dart' show LipSidebar, isWideScreen;
import 'player_screen.dart';

class SeriesScreen extends StatefulWidget {
  final SeriesShow show;
  final int currentTab;
  final Function(int) onTabTap;

  const SeriesScreen({
    super.key,
    required this.show,
    required this.currentTab,
    required this.onTabTap,
  });

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  int _selectedSeason = 1;
  Map<String, dynamic>? _tmdbData;
  Map<String, dynamic>? _tmdbDetails;
  bool _loadingTmdb = false;
  bool _sidebarCollapsed = true;

  static const _tmdbApiKey = '66d3718f549769f4c9707607af99ad0a';

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.show.seasons.keys.first;
    _fetchTmdb();
  }

  String _cleanTitle(String name) {
    return name
        .replaceAll(RegExp(r'^\|[^|]+\|\s*'), '')
        .replaceAll(RegExp(r'\|[^|]+\|'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _fetchTmdb() async {
    setState(() => _loadingTmdb = true);
    try {
      final title = _cleanTitle(widget.show.title);
      final response = await Dio().get(
        'https://api.themoviedb.org/3/search/tv',
        queryParameters: {
          'api_key': _tmdbApiKey,
          'query': title,
          'language': 'fr-FR',
        },
      );
      final results = response.data['results'] as List;
      if (results.isNotEmpty) {
        setState(() => _tmdbData = results.first);
        await _fetchTmdbDetails(results.first['id']);
      }
    } catch (_) {
    } finally {
      setState(() => _loadingTmdb = false);
    }
  }

  Future<void> _fetchTmdbDetails(int id) async {
    try {
      final response = await Dio().get(
        'https://api.themoviedb.org/3/tv/$id',
        queryParameters: {
          'api_key': _tmdbApiKey,
          'language': 'fr-FR',
          'append_to_response': 'credits',
        },
      );
      setState(() => _tmdbDetails = response.data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (isWideScreen(context)) return _buildWebLayout(context);
    return _buildMobileLayout(context);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEB LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWebLayout(BuildContext context) {
    const isDark = true; // dark forcé sur web
    const bg = Color(0xFF141414);
    const panelBg = Color(0xFF111111);
    const textColor = Colors.white;
    final subColor = Colors.grey[400]!;
    final cardBg = const Color(0xFF2A2A2A);

    final seasons = widget.show.seasons;
    final episodes = seasons[_selectedSeason]?.episodes ?? [];

    final posterPath = _tmdbData?['poster_path'];
    final backdropPath = _tmdbData?['backdrop_path'];
    final overview = _tmdbData?['overview'] ?? '';
    final vote = _tmdbData?['vote_average'];
    final year = (_tmdbData?['first_air_date'] ?? '').toString();
    final yearStr = year.length >= 4 ? year.substring(0, 4) : '';
    final tmdbTitle = _tmdbData?['name'] ?? widget.show.title;
    final bgImageUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w780$backdropPath'
        : (posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$posterPath'
              : null);

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
      ),
      child: Scaffold(
        backgroundColor: bg,
        body: Row(
          children: [
            // Sidebar
            LipSidebar(
              currentTab: widget.currentTab,
              onTabTap: widget.onTabTap,
              collapsed: _sidebarCollapsed,
              onToggle: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),

            // Contenu
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panneau infos série (gauche)
                  SizedBox(
                    width: 320,
                    child: Container(
                      color: panelBg,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Backdrop
                            if (bgImageUrl != null)
                              Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: bgImageUrl,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            panelBg.withOpacity(0.95),
                                          ],
                                          stops: const [0.4, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (posterPath != null)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                'https://image.tmdb.org/t/p/w200$posterPath',
                                            width: 70,
                                            height: 105,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tmdbTitle,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                if (yearStr.isNotEmpty) ...[
                                                  Text(
                                                    yearStr,
                                                    style: TextStyle(
                                                      color: subColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (vote != null) ...[
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: 12,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    vote.toStringAsFixed(1),
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (_tmdbDetails?['genres'] !=
                                                null) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 4,
                                                runSpacing: 3,
                                                children: (_tmdbDetails!['genres'] as List)
                                                    .take(3)
                                                    .map(
                                                      (g) => Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              (isDark
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .black)
                                                                  .withOpacity(
                                                                    0.1,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          g['name'],
                                                          style: TextStyle(
                                                            color: textColor,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (overview.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Synopsis',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      overview,
                                      style: TextStyle(
                                        color: subColor,
                                        fontSize: 12,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],

                                  // Casting
                                  if (_tmdbDetails != null) ...[
                                    const SizedBox(height: 16),
                                    _buildCasting(textColor, subColor),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Liste épisodes (droite)
                  Expanded(
                    child: Column(
                      children: [
                        // Header saisons
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.06),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'SAISONS',
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: seasons.keys.map((s) {
                                    final isSelected = _selectedSeason == s;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedSeason = s),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        margin: const EdgeInsets.only(
                                          right: 6,
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : Colors.white24,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'S$s',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black
                                                  : subColor,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              Text(
                                '${episodes.length} épisodes',
                                style: TextStyle(color: subColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Grille épisodes
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 1.7,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                            itemCount: episodes.length,
                            itemBuilder: (context, index) {
                              final ep = episodes[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerScreen(
                                      channel: ep.channel,
                                      initialQuality: ep.channel.bestQuality,
                                      currentTab: widget.currentTab,
                                      onTabTap: (i) {
                                        Navigator.popUntil(
                                          context,
                                          (route) => route.isFirst,
                                        );
                                        widget.onTabTap(i);
                                      },
                                    ),
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Stack(
                                    children: [
                                      if (ep.channel.logo != null &&
                                          ep.channel.logo!.isNotEmpty)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            ep.channel.logo!,
                                            width: double.infinity,
                                            height: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox(),
                                          ),
                                        ),
                                      // Overlay gradient + numéro
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withOpacity(0.7),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 10,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.play_circle_rounded,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Épisode ${ep.number}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT (inchangé)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final seasons = widget.show.seasons;
    final episodes = seasons[_selectedSeason]?.episodes ?? [];

    final posterPath = _tmdbData?['poster_path'];
    final backdropPath = _tmdbData?['backdrop_path'];
    final overview = _tmdbData?['overview'] ?? '';
    final vote = _tmdbData?['vote_average'];
    final year = (_tmdbData?['first_air_date'] ?? '').toString();
    final yearStr = year.length >= 4 ? year.substring(0, 4) : '';
    final tmdbTitle = _tmdbData?['name'] ?? widget.show.title;
    final bgImageUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w780$backdropPath'
        : (posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$posterPath'
              : null);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _buildBottomNav(isDark),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                if (bgImageUrl != null)
                  Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: bgImageUrl,
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                bg.withOpacity(0.7),
                                bg,
                              ],
                              stops: const [0.0, 0.3, 0.65, 0.85],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(height: 280, color: bg),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 0,
                  left: 20,
                  right: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (posterPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w200$posterPath',
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tmdbTitle,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (yearStr.isNotEmpty) ...[
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: subColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    yearStr,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (vote != null) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    vote.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_tmdbDetails?['genres'] != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: (_tmdbDetails!['genres'] as List)
                                    .take(3)
                                    .map(
                                      (g) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (isDark
                                                      ? Colors.white
                                                      : Colors.black)
                                                  .withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          g['name'],
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_tmdbDetails != null)
            SliverToBoxAdapter(child: _buildRealisateur(textColor, subColor)),
          if (_tmdbDetails != null)
            SliverToBoxAdapter(child: _buildCasting(textColor, subColor)),

          if (overview.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synopsis',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overview,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 0, 0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: seasons.keys.map((s) {
                    final isSelected = _selectedSeason == s;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSeason = s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Saison $s',
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : subColor,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                '${episodes.length} épisodes',
                style: TextStyle(color: subColor, fontSize: 12),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final ep = episodes[index];
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading:
                        ep.channel.logo != null && ep.channel.logo!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              ep.channel.logo!,
                              width: 80,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _epPlaceholder(isDark),
                            ),
                          )
                        : _epPlaceholder(isDark),
                    title: Text(
                      'Épisode ${ep.number}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: subColor,
                      size: 24,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          channel: ep.channel,
                          initialQuality: ep.channel.bestQuality,
                          currentTab: widget.currentTab,
                          onTabTap: (index) {
                            Navigator.popUntil(
                              context,
                              (route) => route.isFirst,
                            );
                            widget.onTabTap(index);
                          },
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
                ],
              );
            }, childCount: episodes.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final subColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final activeColor = isDark ? Colors.white : Colors.black;
    final navBg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
    final tabs = ['Live', 'Films', 'Séries', 'Recherche', 'Config'];
    final icons = [
      Icons.live_tv_rounded,
      Icons.movie_rounded,
      Icons.theaters_rounded,
      Icons.search_rounded,
      Icons.settings_rounded,
    ];

    return Container(
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
            final selected = widget.currentTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onTabTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[i],
                        size: 24,
                        color: selected ? activeColor : subColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: selected ? activeColor : subColor,
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
    );
  }

  Widget _buildRealisateur(Color textColor, Color subColor) {
    final credits = _tmdbDetails?['credits'];
    if (credits == null) return const SizedBox.shrink();
    final crew = credits['crew'] as List? ?? [];
    final director = crew.firstWhere(
      (c) => c['job'] == 'Director' || c['job'] == 'Creator',
      orElse: () => null,
    );
    if (director == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Icon(
            Icons.movie_creation_rounded,
            size: 16,
            color: Colors.black54,
          ),
          const SizedBox(width: 8),
          Text('Créateur  ', style: TextStyle(color: subColor, fontSize: 13)),
          Text(
            director['name'],
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasting(Color textColor, Color subColor) {
    final credits = _tmdbDetails?['credits'];
    if (credits == null) return const SizedBox.shrink();
    final cast = (credits['cast'] as List? ?? []).take(6).toList();
    if (cast.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Casting',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final actor = cast[i];
                final profilePath = actor['profile_path'];
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: profilePath != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  'https://image.tmdb.org/t/p/w185$profilePath',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _actorPlaceholder(),
                            )
                          : _actorPlaceholder(),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 60,
                      child: Text(
                        actor['name'],
                        style: TextStyle(color: textColor, fontSize: 10),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _epPlaceholder(bool isDark) => Container(
    width: 80,
    height: 50,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(
      Icons.play_circle_outline_rounded,
      color: isDark ? Colors.white24 : Colors.black26,
      size: 24,
    ),
  );

  Widget _actorPlaceholder() => Container(
    width: 56,
    height: 56,
    color: Colors.grey[300],
    child: const Icon(Icons.person_rounded, color: Colors.grey, size: 28),
  );
}
