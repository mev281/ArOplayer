import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import 'l10n.dart';

enum SourceType { m3u, xtream }

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String _keySourceType = 'source_type';
  static const String _keyM3uUrl = 'm3u_url';
  static const String _keyHost = 'xtream_host';
  static const String _keyUsername = 'xtream_username';
  static const String _keyPassword = 'xtream_password';
  static const String _keyFavorites = 'favorites';
  static const String _keyRecentChannels = 'recent_channels';
  static const String _keyProgress = 'progress';
  static const String _keyPin = 'parental_pin';
  static const String _keyHideAdult = 'hide_adult';
  static const String _keyLanguage = 'language';
  static const String _keyAutoPlayLast = 'auto_play_last';
  static const String _keyLastChannelId = 'last_channel_id';
  static const String _keyEpgUrl = 'epg_url';
  static const String _cacheFileName = 'playlist_cache.m3u';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  SharedPreferences? _prefs;
  List<MediaItem> _favorites = <MediaItem>[];
  List<MediaItem> _recentChannels = <MediaItem>[];
  List<WatchProgress> _progress = <WatchProgress>[];

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _loadFavorites();
    _loadRecentChannels();
    _loadProgress();
    L10n.language.value = language;
    changes.value = changes.value + 1;
  }

  SharedPreferences? get _store => _prefs;

  Future<void> saveSource({
    required SourceType type,
    required String m3uUrl,
    String? host,
    String? username,
    String? password,
  }) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setString(_keySourceType, type.name);
    await prefs.setString(_keyM3uUrl, m3uUrl);
    if (host != null) {
      await prefs.setString(_keyHost, host);
    } else {
      await prefs.remove(_keyHost);
    }
    if (username != null) {
      await prefs.setString(_keyUsername, username);
    } else {
      await prefs.remove(_keyUsername);
    }
    if (password != null) {
      await prefs.setString(_keyPassword, password);
    } else {
      await prefs.remove(_keyPassword);
    }
    changes.value = changes.value + 1;
  }

  bool get hasSource {
    final url = m3uUrl;
    return sourceType != null && url != null && url.isNotEmpty;
  }

  String? get m3uUrl {
    final value = _store?.getString(_keyM3uUrl);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  SourceType? get sourceType {
    final value = _store?.getString(_keySourceType);
    if (value == null) return null;
    for (final type in SourceType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  Future<void> clearSource() async {
    final prefs = _store;
    if (prefs != null) {
      await prefs.remove(_keySourceType);
      await prefs.remove(_keyM3uUrl);
      await prefs.remove(_keyHost);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyPassword);
      await prefs.remove(_keyFavorites);
      await prefs.remove(_keyRecentChannels);
      await prefs.remove(_keyProgress);
      await prefs.remove(_keyLastChannelId);
      await prefs.reload();
    }
    _favorites = <MediaItem>[];
    _recentChannels = <MediaItem>[];
    _progress = <WatchProgress>[];
    await _deleteCache();
    changes.value = changes.value + 1;
  }

  Future<void> _deleteCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      return;
    }
  }

  static String xtreamToM3u(String host, String user, String pass) {
    var base = host.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final encodedUser = Uri.encodeQueryComponent(user.trim());
    final encodedPass = Uri.encodeQueryComponent(pass);
    return '$base/get.php?username=$encodedUser&password=$encodedPass&type=m3u_plus&output=ts';
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_cacheFileName');
  }

  Future<void> cachePlaylist(String text) async {
    if (!hasSource) return;
    try {
      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(text, flush: true);
      if (!hasSource && await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      return;
    }
  }

  Future<String?> readCachedPlaylist() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return text;
    } catch (_) {
      return null;
    }
  }

  List<MediaItem> get favorites => List<MediaItem>.unmodifiable(_favorites);

  bool isFavorite(MediaItem item) {
    for (final favorite in _favorites) {
      if (favorite.id == item.id) return true;
    }
    return false;
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final index = _favorites.indexWhere((favorite) => favorite.id == item.id);
    if (index >= 0) {
      _favorites.removeAt(index);
    } else {
      _favorites.add(item);
    }
    await _persistFavorites();
    changes.value = changes.value + 1;
  }

  void _loadFavorites() {
    final raw = _store?.getString(_keyFavorites);
    if (raw == null || raw.isEmpty) {
      _favorites = <MediaItem>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <MediaItem>[];
        for (final entry in decoded) {
          if (entry is Map) {
            items.add(MediaItem.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        _favorites = items;
        return;
      }
    } catch (_) {
      _favorites = <MediaItem>[];
      return;
    }
    _favorites = <MediaItem>[];
  }

  Future<void> _persistFavorites() async {
    final prefs = _store;
    if (prefs == null) return;
    final encoded = jsonEncode(
      _favorites.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_keyFavorites, encoded);
  }

  List<MediaItem> get recentChannels =>
      List<MediaItem>.unmodifiable(_recentChannels);

  Future<void> addRecentChannel(MediaItem item) async {
    _recentChannels.removeWhere((entry) => entry.id == item.id);
    _recentChannels.insert(0, item);
    if (_recentChannels.length > 10) {
      _recentChannels = _recentChannels.sublist(0, 10);
    }
    await _persistRecentChannels();
    changes.value = changes.value + 1;
  }

  void _loadRecentChannels() {
    final raw = _store?.getString(_keyRecentChannels);
    if (raw == null || raw.isEmpty) {
      _recentChannels = <MediaItem>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <MediaItem>[];
        for (final entry in decoded) {
          if (entry is Map) {
            items.add(MediaItem.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        _recentChannels = items.length > 10 ? items.sublist(0, 10) : items;
        return;
      }
    } catch (_) {
      _recentChannels = <MediaItem>[];
      return;
    }
    _recentChannels = <MediaItem>[];
  }

  Future<void> _persistRecentChannels() async {
    final prefs = _store;
    if (prefs == null) return;
    final encoded = jsonEncode(
      _recentChannels.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_keyRecentChannels, encoded);
  }

  Future<void> saveProgress(
    MediaItem item,
    int positionSec,
    int durationSec,
  ) async {
    _progress.removeWhere((entry) => entry.item.id == item.id);
    final finished = durationSec > 0 &&
        positionSec > 0 &&
        positionSec / durationSec >= 0.95;
    if (!finished && positionSec > 0) {
      _progress.add(WatchProgress(
        item: item,
        positionSec: positionSec,
        durationSec: durationSec,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ));
      _progress.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      if (_progress.length > 60) {
        _progress = _progress.sublist(0, 60);
      }
    }
    await _persistProgress();
    changes.value = changes.value + 1;
  }

  int? progressFor(String id) {
    for (final entry in _progress) {
      if (entry.item.id == id) {
        return entry.positionSec;
      }
    }
    return null;
  }

  List<WatchProgress> continueWatching() {
    final sorted = List<WatchProgress>.from(_progress)
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    if (sorted.length > 30) {
      return sorted.sublist(0, 30);
    }
    return sorted;
  }

  void _loadProgress() {
    final raw = _store?.getString(_keyProgress);
    if (raw == null || raw.isEmpty) {
      _progress = <WatchProgress>[];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <WatchProgress>[];
        for (final entry in decoded) {
          if (entry is Map) {
            items.add(WatchProgress.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
        items.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
        _progress = items;
        return;
      }
    } catch (_) {
      _progress = <WatchProgress>[];
      return;
    }
    _progress = <WatchProgress>[];
  }

  Future<void> _persistProgress() async {
    final prefs = _store;
    if (prefs == null) return;
    final encoded = jsonEncode(
      _progress.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_keyProgress, encoded);
  }

  String? get pin {
    final value = _store?.getString(_keyPin);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setPin(String value) async {
    final prefs = _store;
    if (prefs == null) return;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyPin);
    } else {
      await prefs.setString(_keyPin, trimmed);
    }
    changes.value = changes.value + 1;
  }

  bool get hideAdult => _store?.getBool(_keyHideAdult) ?? false;

  Future<void> setHideAdult(bool value) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setBool(_keyHideAdult, value);
    changes.value = changes.value + 1;
  }

  bool verifyPin(String value) {
    final stored = pin;
    if (stored == null) return true;
    return stored == value.trim();
  }

  String get language {
    final value = _store?.getString(_keyLanguage);
    if (value == null || value.isEmpty) return 'tr';
    return value;
  }

  Future<void> setLanguage(String value) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setString(_keyLanguage, value);
    changes.value = changes.value + 1;
  }

  bool get autoPlayLast => _store?.getBool(_keyAutoPlayLast) ?? false;

  Future<void> setAutoPlayLast(bool value) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setBool(_keyAutoPlayLast, value);
    changes.value = changes.value + 1;
  }

  String? get lastChannelId {
    final value = _store?.getString(_keyLastChannelId);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> setLastChannelId(String id) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setString(_keyLastChannelId, id);
    changes.value = changes.value + 1;
  }

  String get epgUrl => _store?.getString(_keyEpgUrl) ?? '';

  Future<void> setEpgUrl(String value) async {
    final prefs = _store;
    if (prefs == null) return;
    await prefs.setString(_keyEpgUrl, value.trim());
    changes.value = changes.value + 1;
  }
}
