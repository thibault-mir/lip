import 'channel.dart';

class Episode {
  final int number;
  final Channel channel;

  Episode({required this.number, required this.channel});
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});
}

class SeriesShow {
  final String title;
  final String? logo;
  final String? group;
  final Map<int, Season> seasons;

  SeriesShow({
    required this.title,
    required this.seasons,
    this.logo,
    this.group,
  });

  int get seasonCount => seasons.length;
  int get episodeCount =>
      seasons.values.fold(0, (sum, s) => sum + s.episodes.length);
}
