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
  final episodeRe = RegExp(r'[Ss](\d{1,2})\s*[Ee](\d{1,2})');
  final separatorRe = RegExp(r'[-|:/]');

  var pending = false;
  var name = '';
  var logo = '';
  var group = '';

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('#EXTINF')) {
      logo = logoRe.firstMatch(line)?.group(1)?.trim() ?? '';
      group = groupRe.firstMatch(line)?.group(1)?.trim() ?? '';
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
    final isSeries = folded.contains('dizi') ||
        folded.contains('series') ||
        episodeMatch != null;

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

    if (isVideoFile || isMovieGroup) {
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

    final parts = group
        .split(separatorRe)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    var country = 'Diğer';
    var subCategory = 'Genel';
    if (parts.length > 1) {
      country = parts.first;
      subCategory = _normalizeCategory(parts.sublist(1).join(' '));
    } else {
      subCategory = _guessCategory(folded);
    }
    if (country.trim().isEmpty) country = 'Diğer';
    live.add(MediaItem(
      id: id,
      name: name,
      url: url,
      logo: logo,
      groupTitle: group,
      type: MediaType.live,
      country: country,
      subCategory: subCategory,
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
  static Future<String> fetch(String url) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Liste indirilemedi (HTTP ${response.statusCode})');
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  static Future<PlaylistData> parse(String text) => compute(parseM3u, text);
}
