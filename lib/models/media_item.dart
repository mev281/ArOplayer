enum MediaType { live, movie, newMovie, episode }

class MediaItem {
  final String id;
  final String name;
  final String url;
  final String logo;
  final String groupTitle;
  final MediaType type;
  final String country;
  final String subCategory;
  final String? seriesName;
  final int? season;
  final int? episode;
  final String userAgent;
  final String referrer;
  final String tvgId;

  const MediaItem({
    required this.id,
    required this.name,
    required this.url,
    this.logo = '',
    this.groupTitle = '',
    this.type = MediaType.live,
    this.country = 'Diğer',
    this.subCategory = 'Genel',
    this.seriesName,
    this.season,
    this.episode,
    this.userAgent = '',
    this.referrer = '',
    this.tvgId = '',
  });

  Map<String, String>? get httpHeaders {
    final headers = <String, String>{};
    if (userAgent.isNotEmpty) headers['User-Agent'] = userAgent;
    if (referrer.isNotEmpty) headers['Referer'] = referrer;
    return headers.isEmpty ? null : headers;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'logo': logo,
        'groupTitle': groupTitle,
        'type': type.name,
        'country': country,
        'subCategory': subCategory,
        'seriesName': seriesName,
        'season': season,
        'episode': episode,
        'userAgent': userAgent,
        'referrer': referrer,
        'tvgId': tvgId,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        logo: (j['logo'] ?? '') as String,
        groupTitle: (j['groupTitle'] ?? '') as String,
        type: MediaType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => MediaType.live,
        ),
        country: (j['country'] ?? 'Diğer') as String,
        subCategory: (j['subCategory'] ?? 'Genel') as String,
        seriesName: j['seriesName'] as String?,
        season: j['season'] as int?,
        episode: j['episode'] as int?,
        userAgent: (j['userAgent'] ?? '') as String,
        referrer: (j['referrer'] ?? '') as String,
        tvgId: (j['tvgId'] ?? '') as String,
      );
}

class SeriesItem {
  final String name;
  final String logo;
  final String groupTitle;
  final Map<int, List<MediaItem>> seasons;

  SeriesItem({
    required this.name,
    this.logo = '',
    this.groupTitle = '',
    required this.seasons,
  });

  int get episodeCount =>
      seasons.values.fold(0, (sum, list) => sum + list.length);
}

class PlaylistData {
  final List<MediaItem> live;
  final List<MediaItem> newMovies;
  final List<MediaItem> movies;
  final List<SeriesItem> series;

  const PlaylistData({
    this.live = const [],
    this.newMovies = const [],
    this.movies = const [],
    this.series = const [],
  });

  bool get isEmpty =>
      live.isEmpty && newMovies.isEmpty && movies.isEmpty && series.isEmpty;

  List<MediaItem> get allPlayable => [
        ...live,
        ...newMovies,
        ...movies,
        for (final s in series)
          for (final e in s.seasons.values) ...e,
      ];
}

class WatchProgress {
  final MediaItem item;
  final int positionSec;
  final int durationSec;
  final int updatedAtMs;

  const WatchProgress({
    required this.item,
    required this.positionSec,
    required this.durationSec,
    required this.updatedAtMs,
  });

  double get fraction =>
      durationSec <= 0 ? 0 : (positionSec / durationSec).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'positionSec': positionSec,
        'durationSec': durationSec,
        'updatedAtMs': updatedAtMs,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> j) => WatchProgress(
        item: MediaItem.fromJson(Map<String, dynamic>.from(j['item'] as Map)),
        positionSec: j['positionSec'] as int,
        durationSec: j['durationSec'] as int,
        updatedAtMs: j['updatedAtMs'] as int,
      );
}
