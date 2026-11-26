import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';

String _fold(String input) {
  var text = input.replaceAll('\u0130', 'I').replaceAll('\u0131', 'i');
  text = text.toLowerCase();
  text = text.replaceAll('\u015F', 's');
  text = text.replaceAll('\u011F', 'g');
  text = text.replaceAll('\u00FC', 'u');
  text = text.replaceAll('\u00F6', 'o');
  text = text.replaceAll('\u00E7', 'c');
  text = text.replaceAll('\u00E2', 'a');
  text = text.replaceAll('\u00EE', 'i');
  text = text.replaceAll('\u00FB', 'u');
  return text;
}

bool isAdultText(String s) {
  final folded = _fold(s);
  const keys = <String>[
    'adult',
    'xxx',
    '+18',
    '18+',
    'porn',
    'erotik',
    'yetiskin',
  ];
  for (final key in keys) {
    if (folded.contains(key)) return true;
  }
  return false;
}

String? _categoryFromKeywords(String folded) {
  if (folded.contains('muzik') || folded.contains('music')) return 'Müzik';
  if (folded.contains('haber') || folded.contains('news')) return 'Haber';
  if (folded.contains('belgesel') ||
      folded.contains('documentary') ||
      folded.contains('docu')) {
    return 'Belgesel';
  }
  if (folded.contains('spor') || folded.contains('sport')) return 'Spor';
  if (folded.contains('cocuk') ||
      folded.contains('kids') ||
      folded.contains('kid')) {
    return 'Çocuk';
  }
  if (folded.contains('sinema') ||
      folded.contains('movie') ||
      folded.contains('film')) {
    return 'Sinema';
  }
  if (folded.contains('ulusal') || folded.contains('national')) {
    return 'Ulusal';
  }
  return null;
}

String _titleCase(String input) {
  final words = input.split(RegExp(r'\s+'));
  final buffer = <String>[];
  for (final word in words) {
    if (word.isEmpty) continue;
    buffer.add(word[0].toUpperCase() + word.substring(1));
  }
  if (buffer.isEmpty) return 'Genel';
  return buffer.join(' ');
}

String _normalizeCategory(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Genel';
  final guessed = _categoryFromKeywords(_fold(trimmed));
  if (guessed != null) return guessed;
  return _titleCase(trimmed);
}

String _guessCategory(String folded) {
  return _categoryFromKeywords(folded) ?? 'Genel';
}

String _cleanSeriesName(String raw) {
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'[\[\]\(\)\{\}]'), ' ');
  text = text.replaceAll(RegExp(r'^[\-\u2013\u2014:|._]+'), '').trim();
  text = text.replaceAll(RegExp(r'[\-\u2013\u2014:|._]+$'), '').trim();
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text
      .replaceFirst(RegExp(r'^(dizi|series)[\s\-\u2013\u2014:|]*', caseSensitive: false), '')
      .trim();
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

const Map<String, String> _countryAliases = <String, String>{
  'tr': 'Türkiye',
  'tur': 'Türkiye',
  'turkey': 'Türkiye',
  'turkiye': 'Türkiye',
  'turk': 'Türkiye',
  'turkish': 'Türkiye',
  'de': 'Almanya',
  'ger': 'Almanya',
  'germany': 'Almanya',
  'german': 'Almanya',
  'deutschland': 'Almanya',
  'deutsch': 'Almanya',
  'almanya': 'Almanya',
  'uk': 'İngiltere',
  'gb': 'İngiltere',
  'gbr': 'İngiltere',
  'england': 'İngiltere',
  'britain': 'İngiltere',
  'british': 'İngiltere',
  'ingiltere': 'İngiltere',
  'us': 'ABD',
  'usa': 'ABD',
  'abd': 'ABD',
  'america': 'ABD',
  'amerika': 'ABD',
  'american': 'ABD',
  'fr': 'Fransa',
  'fra': 'Fransa',
  'france': 'Fransa',
  'french': 'Fransa',
  'fransa': 'Fransa',
  'nl': 'Hollanda',
  'nld': 'Hollanda',
  'netherlands': 'Hollanda',
  'holland': 'Hollanda',
  'dutch': 'Hollanda',
  'hollanda': 'Hollanda',
  'it': 'İtalya',
  'ita': 'İtalya',
  'italy': 'İtalya',
  'italia': 'İtalya',
  'italya': 'İtalya',
  'es': 'İspanya',
  'esp': 'İspanya',
  'spain': 'İspanya',
  'ispanya': 'İspanya',
  'pt': 'Portekiz',
  'portugal': 'Portekiz',
  'portekiz': 'Portekiz',
  'be': 'Belçika',
  'belgium': 'Belçika',
  'belcika': 'Belçika',
  'at': 'Avusturya',
  'austria': 'Avusturya',
  'avusturya': 'Avusturya',
  'ch': 'İsviçre',
  'switzerland': 'İsviçre',
  'isvicre': 'İsviçre',
  'ru': 'Rusya',
  'rus': 'Rusya',
  'russia': 'Rusya',
  'rusya': 'Rusya',
  'az': 'Azerbaycan',
  'azerbaijan': 'Azerbaycan',
  'azerbaycan': 'Azerbaycan',
  'pl': 'Polonya',
  'poland': 'Polonya',
  'polonya': 'Polonya',
  'gr': 'Yunanistan',
  'greece': 'Yunanistan',
  'yunanistan': 'Yunanistan',
  'ro': 'Romanya',
  'romania': 'Romanya',
  'romanya': 'Romanya',
  'bg': 'Bulgaristan',
  'bulgaria': 'Bulgaristan',
  'bulgaristan': 'Bulgaristan',
  'al': 'Arnavutluk',
  'albania': 'Arnavutluk',
  'arnavutluk': 'Arnavutluk',
  'ar': 'Arap',
  'arab': 'Arap',
  'arabic': 'Arap',
  'ca': 'Kanada',
  'canada': 'Kanada',
  'kanada': 'Kanada',
  'se': 'İsveç',
  'sweden': 'İsveç',
  'isvec': 'İsveç',
  'dk': 'Danimarka',
  'denmark': 'Danimarka',
  'danimarka': 'Danimarka',
  'no': 'Norveç',
  'norway': 'Norveç',
  'norvec': 'Norveç',
  'ex': 'Eski Yugoslavya',
  'yu': 'Eski Yugoslavya',
  'ba': 'Eski Yugoslavya',
  'rs': 'Eski Yugoslavya',
  'hr': 'Eski Yugoslavya',
  'ku': 'Kürtçe',
  'kurdish': 'Kürtçe',
  'kurdistan': 'Kürtçe',
};

String? _countryFromToken(String token, bool isFirst) {
  if (token.isEmpty) return null;
  if (!isFirst && token.length < 4) return null;
  return _countryAliases[token];
}

String? _detectCountry(String foldedText) {
  final tokens = foldedText
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList();
  for (var i = 0; i < tokens.length; i++) {
    final country = _countryFromToken(tokens[i], i == 0);
    if (country != null) return country;
  }
  if (foldedText.contains('united kingdom')) return 'İngiltere';
  if (foldedText.contains('united states')) return 'ABD';
  return null;
}

const Map<String, String> _isoCountries = <String, String>{
  'us': 'ABD',
  'tr': 'Türkiye',
  'de': 'Almanya',
  'uk': 'İngiltere',
  'gb': 'İngiltere',
  'fr': 'Fransa',
  'nl': 'Hollanda',
  'it': 'İtalya',
  'es': 'İspanya',
  'pt': 'Portekiz',
  'be': 'Belçika',
  'at': 'Avusturya',
  'ch': 'İsviçre',
  'ru': 'Rusya',
  'ua': 'Ukrayna',
  'pl': 'Polonya',
  'ro': 'Romanya',
  'bg': 'Bulgaristan',
  'gr': 'Yunanistan',
  'hu': 'Macaristan',
  'cz': 'Çekya',
  'sk': 'Slovakya',
  'rs': 'Sırbistan',
  'hr': 'Hırvatistan',
  'ba': 'Bosna Hersek',
  'si': 'Slovenya',
  'mk': 'Kuzey Makedonya',
  'al': 'Arnavutluk',
  'xk': 'Kosova',
  'me': 'Karadağ',
  'az': 'Azerbaycan',
  'ge': 'Gürcistan',
  'am': 'Ermenistan',
  'kz': 'Kazakistan',
  'uz': 'Özbekistan',
  'by': 'Belarus',
  'lt': 'Litvanya',
  'lv': 'Letonya',
  'ee': 'Estonya',
  'fi': 'Finlandiya',
  'se': 'İsveç',
  'no': 'Norveç',
  'dk': 'Danimarka',
  'is': 'İzlanda',
  'ie': 'İrlanda',
  'lu': 'Lüksemburg',
  'mt': 'Malta',
  'cy': 'Kıbrıs',
  'md': 'Moldova',
  'in': 'Hindistan',
  'pk': 'Pakistan',
  'bd': 'Bangladeş',
  'lk': 'Sri Lanka',
  'np': 'Nepal',
  'af': 'Afganistan',
  'ir': 'İran',
  'iq': 'Irak',
  'sy': 'Suriye',
  'lb': 'Lübnan',
  'jo': 'Ürdün',
  'il': 'İsrail',
  'ps': 'Filistin',
  'sa': 'Suudi Arabistan',
  'ae': 'BAE',
  'kw': 'Kuveyt',
  'qa': 'Katar',
  'bh': 'Bahreyn',
  'om': 'Umman',
  'ye': 'Yemen',
  'eg': 'Mısır',
  'ly': 'Libya',
  'tn': 'Tunus',
  'dz': 'Cezayir',
  'ma': 'Fas',
  'sd': 'Sudan',
  'so': 'Somali',
  'ke': 'Kenya',
  'ng': 'Nijerya',
  'gh': 'Gana',
  'za': 'Güney Afrika',
  'et': 'Etiyopya',
  'sn': 'Senegal',
  'ci': 'Fildişi Sahili',
  'cm': 'Kamerun',
  'cn': 'Çin',
  'hk': 'Hong Kong',
  'tw': 'Tayvan',
  'jp': 'Japonya',
  'kr': 'Güney Kore',
  'kp': 'Kuzey Kore',
  'mn': 'Moğolistan',
  'th': 'Tayland',
  'vn': 'Vietnam',
  'id': 'Endonezya',
  'my': 'Malezya',
  'sg': 'Singapur',
  'ph': 'Filipinler',
  'kh': 'Kamboçya',
  'mm': 'Myanmar',
  'au': 'Avustralya',
  'nz': 'Yeni Zelanda',
  'ca': 'Kanada',
  'mx': 'Meksika',
  'br': 'Brezilya',
  'ar': 'Arjantin',
  'cl': 'Şili',
  'co': 'Kolombiya',
  'pe': 'Peru',
  've': 'Venezuela',
  'ec': 'Ekvador',
  'uy': 'Uruguay',
  'py': 'Paraguay',
  'bo': 'Bolivya',
  'cr': 'Kosta Rika',
  'pa': 'Panama',
  'gt': 'Guatemala',
  'hn': 'Honduras',
  'sv': 'El Salvador',
  'ni': 'Nikaragua',
  'do': 'Dominik Cumhuriyeti',
  'cu': 'Küba',
  'pr': 'Porto Riko',
  'jm': 'Jamaika',
  'ht': 'Haiti',
  'tt': 'Trinidad ve Tobago',
};

const Map<String, String> _categoryNames = <String, String>{
  'news': 'Haber',
  'sports': 'Spor',
  'sport': 'Spor',
  'music': 'Müzik',
  'documentary': 'Belgesel',
  'movies': 'Sinema',
  'movie': 'Sinema',
  'series': 'Dizi',
  'kids': 'Çocuk',
  'general': 'Genel',
  'undefined': 'Genel',
  'entertainment': 'Eğlence',
  'religious': 'Dini',
  'legislative': 'Meclis',
  'education': 'Eğitim',
  'culture': 'Kültür',
  'comedy': 'Komedi',
  'lifestyle': 'Yaşam',
  'animation': 'Animasyon',
  'shop': 'Alışveriş',
  'business': 'Ekonomi',
  'outdoor': 'Doğa',
  'classic': 'Klasik',
  'travel': 'Seyahat',
  'cooking': 'Yemek',
  'family': 'Aile',
  'auto': 'Otomobil',
  'weather': 'Hava Durumu',
  'science': 'Bilim',
  'public': 'Kamu',
  'relax': 'Rahatlama',
  'interactive': 'İnteraktif',
  'xxx': 'Yetişkin',
};

String _categoryFromGroup(String group) {
  final first = group
      .split(RegExp(r'[;,]'))
      .map((part) => part.trim())
      .firstWhere((part) => part.isNotEmpty, orElse: () => '');
  if (first.isEmpty) return 'Genel';
  final mapped = _categoryNames[first.toLowerCase()];
  if (mapped != null) return mapped;
  return _normalizeCategory(first);
}

String? _countryFromTvgId(String tvgId) {
  final match = RegExp(r'\.([A-Za-z]{2,3})(?:@|$)').firstMatch(tvgId);
  if (match == null) return null;
  return _isoCountries[(match.group(1) ?? '').toLowerCase()];
}

class _LiveClass {
  const _LiveClass(this.country, this.subCategory);
  final String country;
  final String subCategory;
}

_LiveClass _classifyLive(String group, String name, String tvgId) {
  final foldedGroup = _fold(group);
  var country = _countryFromTvgId(tvgId) ?? _detectCountry(foldedGroup);
  if (country != null && _countryFromTvgId(tvgId) != null) {
    return _LiveClass(country, _categoryFromGroup(group));
  }
  if (country == null) {
    final prefix = RegExp(r'^\s*[\[\(|]?\s*([A-Za-z]{2,3})\s*[\]\)|:\-]')
        .firstMatch(name);
    if (prefix != null) {
      country = _countryAliases[_fold(prefix.group(1) ?? '')];
    }
  }
  if (country == null) {
    final raw = group.trim();
    return _LiveClass('Diğer', raw.isEmpty ? 'Genel' : raw);
  }
  final parts = group
      .split(RegExp(r'[-|:/\[\]()]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where((part) {
    final tokens = _fold(part)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return false;
    return !(tokens.length == 1 && _countryAliases.containsKey(tokens.first));
  }).toList();
  var sub = parts.isEmpty ? '' : _normalizeCategory(parts.join(' '));
  if (sub.isEmpty || sub == 'Genel') {
    sub = _guessCategory(_fold('$name $group'));
  }
  return _LiveClass(country, sub);
}

PlaylistData parseM3u(String text) {
  final live = <MediaItem>[];
  final movies = <MediaItem>[];
  final newMovies = <MediaItem>[];
  final seriesNames = <String, String>{};
  final seriesLogos = <String, String>{};
  final seriesGroups = <String, String>{};
  final seriesSeasons = <String, Map<int, List<MediaItem>>>{};

  final logoRe = RegExp(r'tvg-logo="([^"]*)"');
  final groupRe = RegExp(r'group-title="([^"]*)"');
  final tvgIdRe = RegExp(r'tvg-id="([^"]*)"');
  final uaRe = RegExp(r'http-user-agent="([^"]*)"');
  final refRe = RegExp(r'http-referrer="([^"]*)"');
  final episodeRe = RegExp(r'[Ss](\d{1,2})\s*[Ee](\d{1,2})');

  var pending = false;
  var name = '';
  var logo = '';
  var group = '';
  var tvgId = '';
  var userAgent = '';
  var referrer = '';

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      logo = logoRe.firstMatch(line)?.group(1)?.trim() ?? '';
      group = groupRe.firstMatch(line)?.group(1)?.trim() ?? '';
      tvgId = tvgIdRe.firstMatch(line)?.group(1)?.trim() ?? '';
      userAgent = uaRe.firstMatch(line)?.group(1)?.trim() ?? '';
      referrer = refRe.firstMatch(line)?.group(1)?.trim() ?? '';
      final comma = line.lastIndexOf(',');
      name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      pending = true;
      continue;
    }

    if (line.startsWith('#')) continue;
    if (!pending) continue;

    pending = false;
    final url = line;
    final id = url.hashCode.toString();
    final folded = _fold('$name $group');
    final episodeMatch = episodeRe.firstMatch(name);
    final lowerUrlAll = url.toLowerCase();
    final urlPath = lowerUrlAll.split('?').first;
    final isLiveUrl = tvgId.contains('@') ||
        lowerUrlAll.contains('/live/') ||
        urlPath.endsWith('.m3u8') ||
        urlPath.endsWith('.mpd') ||
        urlPath.endsWith('.ts');
    final isSeries = lowerUrlAll.contains('/series/') ||
        (!isLiveUrl &&
            (folded.contains('dizi') ||
                folded.contains('series') ||
                episodeMatch != null));

    if (isSeries) {
      int? season;
      int? episode;
      String seriesName;
      if (episodeMatch != null) {
        season = int.tryParse(episodeMatch.group(1) ?? '');
        episode = int.tryParse(episodeMatch.group(2) ?? '');
        seriesName = _cleanSeriesName(name.substring(0, episodeMatch.start));
      } else {
        seriesName = _cleanSeriesName(name);
      }
      if (seriesName.isEmpty) {
        seriesName = group.isNotEmpty ? group : name;
      }
      final key = _fold(seriesName);
      seriesNames.putIfAbsent(key, () => seriesName);
      if (logo.isNotEmpty && (seriesLogos[key] ?? '').isEmpty) {
        seriesLogos[key] = logo;
      }
      if (group.isNotEmpty && (seriesGroups[key] ?? '').isEmpty) {
        seriesGroups[key] = group;
      }
      final seasons = seriesSeasons.putIfAbsent(key, () => <int, List<MediaItem>>{});
      final seasonNo = season ?? 1;
      final bucket = seasons.putIfAbsent(seasonNo, () => <MediaItem>[]);
      bucket.add(MediaItem(
        id: id,
        name: name,
        url: url,
        logo: logo,
        groupTitle: group,
        type: MediaType.episode,
        seriesName: seriesName,
        season: season,
        episode: episode,
      ));
      continue;
    }

    final lowerUrl = url.toLowerCase();
    final isVideoFile = lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.endsWith('.avi');
    final isMovieGroup = folded.contains('film') ||
        folded.contains('movie') ||
        folded.contains('sinema');

    if (lowerUrl.contains('/movie/') ||
        (!isLiveUrl && (isVideoFile || isMovieGroup))) {
      final isNew = folded.contains('yeni') ||
          folded.contains('new') ||
          folded.contains('2025') ||
          folded.contains('2026') ||
          folded.contains('vizyon');
      final item = MediaItem(
        id: id,
        name: name,
        url: url,
        logo: logo,
        groupTitle: group,
        type: isNew ? MediaType.newMovie : MediaType.movie,
      );
      if (isNew) {
        newMovies.add(item);
      } else {
        movies.add(item);
      }
      continue;
    }

    final classified = _classifyLive(group, name, tvgId);
    final country = classified.country;
    final subCategory = classified.subCategory;
    live.add(MediaItem(
      id: id,
      name: name,
      url: url,
      logo: logo,
      groupTitle: group,
      type: MediaType.live,
      country: country,
      subCategory: subCategory,
      userAgent: userAgent,
      referrer: referrer,
      tvgId: tvgId,
    ));
  }

  final seriesKeys = seriesSeasons.keys.toList()
    ..sort((a, b) {
      final left = (seriesNames[a] ?? a).toLowerCase();
      final right = (seriesNames[b] ?? b).toLowerCase();
      return left.compareTo(right);
    });

  final series = <SeriesItem>[];
  for (final key in seriesKeys) {
    final seasons = seriesSeasons[key] ?? <int, List<MediaItem>>{};
    final seasonKeys = seasons.keys.toList()..sort();
    final ordered = <int, List<MediaItem>>{};
    for (final seasonNo in seasonKeys) {
      final episodes = seasons[seasonNo] ?? <MediaItem>[];
      episodes.sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));
      ordered[seasonNo] = episodes;
    }
    series.add(SeriesItem(
      name: seriesNames[key] ?? key,
      logo: seriesLogos[key] ?? '',
      groupTitle: seriesGroups[key] ?? '',
      seasons: ordered,
    ));
  }

  return PlaylistData(
    live: live,
    newMovies: newMovies,
    movies: movies,
    series: series,
  );
}

class M3uService {
  /// #EXTM3U başlığındaki EPG (url-tvg / x-tvg-url) adresleri.
  static List<String> lastEpgUrls = <String>[];

  static Future<String> fetch(String url) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = true
        ..maxRedirects = 10
        ..headers['User-Agent'] = 'VLC/3.0.18';
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Liste indirilemedi (HTTP ${response.statusCode})');
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }

  static Future<PlaylistData> parse(String text) async {
    // compute izolatında static alan paylaşılmadığı için başlık burada ayıklanır.
    lastEpgUrls = _extractEpgUrls(text);
    return compute(parseM3u, text);
  }
}

/// Ham metnin ilk 2000 karakterinden EPG adreslerini çıkarır.
List<String> _extractEpgUrls(String text) {
  final head = text.length > 2000 ? text.substring(0, 2000) : text;
  final urls = <String>[];
  final re = RegExp(r'(?:url-tvg|x-tvg-url)\s*=\s*"([^"]*)"');
  for (final match in re.allMatches(head)) {
    for (final part in (match.group(1) ?? '').split(',')) {
      final url = part.trim();
      if (url.isEmpty) continue;
      if (!urls.contains(url)) urls.add(url);
    }
  }
  return urls;
}
