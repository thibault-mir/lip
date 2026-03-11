import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../main.dart' show LipSidebar, isWideScreen;
import 'dart:ui';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final StreamQuality initialQuality;
  final int currentTab;
  final Function(int) onTabTap;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.initialQuality,
    required this.currentTab,
    required this.onTabTap,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late StreamQuality _currentQuality;
  Map<String, dynamic>? _tmdbData;
  Map<String, dynamic>? _tmdbDetails;
  bool _loadingTmdb = false;
  bool _sidebarCollapsed = true; // collapsed par défaut sur les sous-écrans

  static const _tmdbApiKey = '66d3718f549769f4c9707607af99ad0a';

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _currentQuality = widget.initialQuality;
    _play(_currentQuality.url);
    if (widget.channel.type != ChannelType.live) {
      _fetchTmdb();
    }
  }

  Future<void> _play(String url) async {
    await _player.open(Media(url));
  }

  String _cleanTitle(String name) {
    return name
        .replaceAll(RegExp(r'^\|[^|]+\|\s*'), '')
        .replaceAll(RegExp(r'\|[^|]+\|'), '')
        .replaceAll(RegExp(r'S\d+\s*E\d+.*'), '')
        .replaceAll(RegExp(r'\s*(FHD|HD|SD|4K|UHD|HDR)\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatRuntime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}min';
  }

  Future<void> _fetchTmdb() async {
    setState(() => _loadingTmdb = true);
    try {
      final title = _cleanTitle(widget.channel.name);
      final type = widget.channel.type == ChannelType.movie ? 'movie' : 'tv';
      final response = await Dio().get(
        'https://api.themoviedb.org/3/search/$type',
        queryParameters: {
          'api_key': _tmdbApiKey,
          'query': title,
          'language': 'fr-FR',
        },
      );
      final results = response.data['results'] as List;
      if (results.isNotEmpty) {
        setState(() => _tmdbData = results.first);
        await _fetchTmdbDetails(results.first['id'], type);
      }
    } catch (_) {
    } finally {
      setState(() => _loadingTmdb = false);
    }
  }

  Future<void> _fetchTmdbDetails(int id, String type) async {
    try {
      final response = await Dio().get(
        'https://api.themoviedb.org/3/$type/$id',
        queryParameters: {
          'api_key': _tmdbApiKey,
          'language': 'fr-FR',
          'append_to_response': 'credits',
        },
      );
      setState(() => _tmdbDetails = response.data);
    } catch (_) {}
  }

  Future<void> _switchQuality(StreamQuality quality) async {
    setState(() => _currentQuality = quality);
    await _play(quality.url);
    if (mounted) Navigator.pop(context);
  }

  void _showQualityPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qualité',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.channel.qualities.map((q) {
              final isSelected = q.label == _currentQuality.label;
              return ListTile(
                title: Text(
                  q.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.blueAccent
                        : (isDark ? Colors.white : Colors.black),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.blueAccent)
                    : null,
                onTap: () => _switchQuality(q),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isWideScreen(context)) return _buildWebLayout(context);
    return _buildMobileLayout(context);
  }

  // ── WEB layout ────────────────────────────────────────────────────────────
  Widget _buildWebLayout(BuildContext context) {
    const isDark = true;
    const bg = Color(0xFF0E0E0E);
    const textColor = Colors.white;
    final subColor = Colors.grey[400]!;
    final isMedia = widget.channel.type != ChannelType.live;

    final posterPath = _tmdbData?['poster_path'];
    final backdropPath = _tmdbData?['backdrop_path'];
    final overview = _tmdbData?['overview'] ?? '';
    final vote = _tmdbData?['vote_average'];
    final year =
        (_tmdbData?['release_date'] ?? _tmdbData?['first_air_date'] ?? '')
            .toString();
    final yearStr = year.length >= 4 ? year.substring(0, 4) : '';
    final tmdbTitle =
        _tmdbData?['title'] ??
        _tmdbData?['name'] ??
        _cleanTitle(widget.channel.name);

    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: bg),
      child: Scaffold(
        backgroundColor: bg,
        body: Row(
          children: [
            // ── Sidebar ─────────────────────────────────────────────
            LipSidebar(
              currentTab: widget.currentTab,
              onTabTap: widget.onTabTap,
              collapsed: _sidebarCollapsed,
              onToggle: () =>
                  setState(() => _sidebarCollapsed = !_sidebarCollapsed),
            ),

            // ── Contenu principal ────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar : back + titre + qualité
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        GestureDetector(
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
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            tmdbTitle,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.channel.qualities.length > 1)
                          GestureDetector(
                            onTap: _showQualityPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _currentQuality.label,
                                style: const TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Vidéo pleine largeur ─────────────────────────
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(controller: _controller),
                  ),

                  // ── Fiche film sous la vidéo ─────────────────────
                  if (isMedia)
                    Expanded(
                      child: _loadingTmdb
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : _buildWebInfoPanel(
                              posterPath: posterPath,
                              backdropPath: backdropPath,
                              tmdbTitle: tmdbTitle,
                              yearStr: yearStr,
                              vote: vote,
                              overview: overview,
                              textColor: textColor,
                              subColor: subColor,
                            ),
                    ),

                  // Live : groupe sous la vidéo
                  if (!isMedia)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.channel.name,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.channel.group != null)
                            Text(
                              widget.channel.group!,
                              style: TextStyle(color: subColor, fontSize: 13),
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

  // ── Fiche film : poster + meta à gauche · synopsis + casting à droite ──────
  Widget _buildWebInfoPanel({
    required String? posterPath,
    required String? backdropPath,
    required String tmdbTitle,
    required String yearStr,
    required dynamic vote,
    required String overview,
    required Color textColor,
    required Color subColor,
  }) {
    final runtime = _tmdbDetails?['runtime'];
    final genres = (_tmdbDetails?['genres'] as List? ?? []).take(3).toList();
    final credits = _tmdbDetails?['credits'];
    final cast = (credits?['cast'] as List? ?? []).take(8).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Poster ────────────────────────────────────────────────
          if (posterPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: 'https://image.tmdb.org/t/p/w300$posterPath',
                width: 110,
                height: 165,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 22),

          // ── Infos + synopsis + casting ────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  tmdbTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Meta : année · durée · note
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (yearStr.isNotEmpty)
                      Text(
                        yearStr,
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    if (runtime != null && runtime > 0)
                      Text(
                        _formatRuntime(runtime),
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    if (vote != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            vote.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Genres
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: genres
                        .map(
                          (g) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              g['name'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Synopsis
                if (overview.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overview,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],

                // Casting
                if (cast.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Casting',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: cast.map((actor) {
                      final profilePath = actor['profile_path'];
                      return SizedBox(
                        width: 56,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: profilePath != null
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w185$profilePath',
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _actorPlaceholder(),
                                    )
                                  : _actorPlaceholder(),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              actor['name'],
                              style: TextStyle(color: subColor, fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE layout ─────────────────────────────────────────────────────────
  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final isMedia = widget.channel.type != ChannelType.live;

    final posterPath = _tmdbData?['poster_path'];
    final backdropPath = _tmdbData?['backdrop_path'];
    final overview = _tmdbData?['overview'] ?? '';
    final vote = _tmdbData?['vote_average'];
    final year =
        (_tmdbData?['release_date'] ?? _tmdbData?['first_air_date'] ?? '')
            .toString();
    final yearStr = year.length >= 4 ? year.substring(0, 4) : '';
    final tmdbTitle =
        _tmdbData?['title'] ??
        _tmdbData?['name'] ??
        _cleanTitle(widget.channel.name);
    final bgImageUrl = backdropPath != null
        ? 'https://image.tmdb.org/t/p/w780$backdropPath'
        : (posterPath != null
              ? 'https://image.tmdb.org/t/p/w500$posterPath'
              : null);

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: _buildBottomNav(isDark),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(controller: _controller),
              ),
              if (isMedia)
                Expanded(
                  child: _loadingTmdb
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          children: [
                            if (bgImageUrl != null)
                              Positioned.fill(
                                child: CachedNetworkImage(
                                  imageUrl: bgImageUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                ),
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
                                      bg.withOpacity(0.85),
                                      bg,
                                      bg,
                                    ],
                                    stops: const [0.0, 0.05, 0.25, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 100),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (posterPath != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  'https://image.tmdb.org/t/p/w200$posterPath',
                                              width: 85,
                                              height: 125,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                      Icons
                                                          .calendar_today_rounded,
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
                                              if (_tmdbDetails != null) ...[
                                                const SizedBox(height: 6),
                                                if (_tmdbDetails!['runtime'] !=
                                                        null &&
                                                    _tmdbDetails!['runtime'] >
                                                        0) ...[
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.schedule_rounded,
                                                        size: 12,
                                                        color: subColor,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _formatRuntime(
                                                          _tmdbDetails!['runtime'],
                                                        ),
                                                        style: TextStyle(
                                                          color: subColor,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                ],
                                                if (_tmdbDetails!['genres'] !=
                                                    null)
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children:
                                                        (_tmdbDetails!['genres']
                                                                as List)
                                                            .take(3)
                                                            .map(
                                                              (g) => Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          3,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      (isDark
                                                                              ? Colors.white
                                                                              : Colors.black)
                                                                          .withOpacity(
                                                                            0.12,
                                                                          ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        20,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  g['name'],
                                                                  style: TextStyle(
                                                                    color:
                                                                        textColor,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
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
                                  const SizedBox(height: 12),
                                  if (_tmdbDetails != null) ...[
                                    _buildRealisateur(textColor, subColor),
                                    _buildCasting(textColor, subColor),
                                  ],
                                  if (overview.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              if (!isMedia)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.channel.group != null)
                        Text(
                          widget.channel.group!,
                          style: TextStyle(color: subColor, fontSize: 13),
                        ),
                    ],
                  ),
                ),
            ],
          ),

          // Bouton retour flottant
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
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

          // Bouton qualité flottant
          if (widget.channel.qualities.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: GestureDetector(
                onTap: _showQualityPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentQuality.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
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
      (c) => c['job'] == 'Director',
      orElse: () => null,
    );
    if (director == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Icon(Icons.movie_creation_rounded, size: 16, color: subColor),
          const SizedBox(width: 8),
          Text(
            'Réalisateur  ',
            style: TextStyle(color: subColor, fontSize: 13),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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

  Widget _actorPlaceholder() => Container(
    width: 56,
    height: 56,
    color: Colors.grey[300],
    child: const Icon(Icons.person_rounded, color: Colors.grey, size: 28),
  );
}
