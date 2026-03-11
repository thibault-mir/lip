enum ChannelType { live, movie, series }

class StreamQuality {
  final String label; // FHD, HD, SD, 4K...
  final String url;

  StreamQuality({required this.label, required this.url});
}

class Channel {
  final String id; // tvg-id
  final String name; // Nom sans le suffixe qualité
  final String? logo;
  final String? group;
  final ChannelType type;
  final List<StreamQuality> qualities;

  Channel({
    required this.id,
    required this.name,
    required this.type,
    required this.qualities,
    this.logo,
    this.group,
  });

  // Qualité par défaut = meilleure disponible
  StreamQuality get bestQuality {
    const order = ['4K|UHD', '4K|HDR', '4K', 'FHD', 'HD', 'SD'];
    for (final q in order) {
      final match = qualities.firstWhere(
        (s) => s.label == q,
        orElse: () => qualities.first,
      );
      if (qualities.any((s) => s.label == q)) return match;
    }
    return qualities.first;
  }
}
