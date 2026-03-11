import '../models/channel.dart';
import '../models/series_show.dart';

class M3uParser {
  static List<Channel> parse(String content) {
    // Map tvg-id -> données brutes
    final Map<String, _RawChannel> rawMap = {};
    // Pour les chaînes sans tvg-id, on garde une liste séparée
    final List<Channel> noIdChannels = [];

    final lines = content.split('\n');
    String? currentId;
    String? currentName;
    String? currentLogo;
    String? currentGroup;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.startsWith('#EXTINF')) {
        // tvg-id
        final idMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(line);
        currentId = idMatch?.group(1) ?? '';

        // tvg-name
        final nameMatch = RegExp(r'tvg-name="([^"]*)"').firstMatch(line);
        currentName =
            nameMatch?.group(1) ??
            (line.contains(',') ? line.split(',').last.trim() : 'Inconnu');

        // logo
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);

        // group
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        currentGroup = groupMatch?.group(1);
      } else if (line.startsWith('http') && currentName != null) {
        final quality = _extractQuality(currentName);
        final cleanName = _cleanName(currentName);
        final type = _detectType(line);

        if (currentId != null && currentId.isNotEmpty) {
          // Grouper par tvg-id
          if (!rawMap.containsKey(currentId)) {
            rawMap[currentId] = _RawChannel(
              id: currentId,
              name: cleanName,
              logo: currentLogo,
              group: currentGroup,
              type: type,
              qualities: [],
            );
          }
          rawMap[currentId]!.qualities.add(
            StreamQuality(label: quality, url: line),
          );
        } else {
          // Pas de tvg-id → chaîne unique
          noIdChannels.add(
            Channel(
              id: cleanName,
              name: cleanName,
              logo: currentLogo,
              group: currentGroup,
              type: type,
              qualities: [StreamQuality(label: quality, url: line)],
            ),
          );
        }

        currentId = null;
        currentName = null;
        currentLogo = null;
        currentGroup = null;
      }
    }

    final grouped = rawMap.values
        .map(
          (r) => Channel(
            id: r.id,
            name: r.name,
            logo: r.logo,
            group: r.group,
            type: r.type,
            qualities: r.qualities,
          ),
        )
        .toList();

    return [...grouped, ...noIdChannels];
  }

  static String _extractQuality(String name) {
    if (name.contains('4K|UHD')) return '4K|UHD';
    if (name.contains('4K|HDR')) return '4K|HDR';
    if (name.contains('4K')) return '4K';
    if (name.contains('FHD')) return 'FHD';
    if (name.contains('HD')) return 'HD';
    if (name.contains('SD')) return 'SD';
    return 'HD';
  }

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'\s*(4K\|UHD|4K\|HDR|4K|FHD|HD|SD)\s*$'), '')
        .trim();
  }

  static ChannelType _detectType(String url) {
    if (url.contains('/series/')) return ChannelType.series;
    if (url.contains('/movie/')) return ChannelType.movie;
    return ChannelType.live;
  }

  static Map<String, SeriesShow> groupSeries(List<Channel> channels) {
    final Map<String, SeriesShow> shows = {};
    final reg = RegExp(r'^(.*?)\s+S(\d+)\s+E(\d+)\s*$', caseSensitive: false);

    for (final ch in channels) {
      if (ch.type != ChannelType.series) continue;
      final match = reg.firstMatch(ch.name);
      if (match == null) continue;

      final title = match
          .group(1)!
          .replaceAll(RegExp(r'^\|[^|]+\|\s*'), '') // retire |FR| etc
          .trim();
      final season = int.parse(match.group(2)!);
      final episode = int.parse(match.group(3)!);

      shows.putIfAbsent(
        title,
        () => SeriesShow(
          title: title,
          logo: ch.logo,
          group: ch.group,
          seasons: {},
        ),
      );

      final show = shows[title]!;
      show.seasons.putIfAbsent(
        season,
        () => Season(number: season, episodes: []),
      );
      show.seasons[season]!.episodes.add(Episode(number: episode, channel: ch));
    }

    // Trier les épisodes dans chaque saison
    for (final show in shows.values) {
      for (final season in show.seasons.values) {
        season.episodes.sort((a, b) => a.number.compareTo(b.number));
      }
    }

    return shows;
  }
}

class _RawChannel {
  final String id;
  final String name;
  final String? logo;
  final String? group;
  final ChannelType type;
  final List<StreamQuality> qualities;

  _RawChannel({
    required this.id,
    required this.name,
    required this.logo,
    required this.group,
    required this.type,
    required this.qualities,
  });
}
