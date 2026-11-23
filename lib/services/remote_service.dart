import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteService {
  RemoteService._();
  static final RemoteService instance = RemoteService._();

  static const String databaseUrl =
      'https://aroplayer-panel-default-rtdb.europe-west1.firebasedatabase.app';
  static const String appVersion = 'v1.0.7';
  static const String idleLabel = 'Menüde';
  static const String _prefsKey = 'aro_device_id';
  static const Duration _interval = Duration(seconds: 20);
  static const Duration _timeout = Duration(seconds: 8);

  final StreamController<bool> _blockedController =
      StreamController<bool>.broadcast();
  final Map<Player, StreamSubscription<bool>> _players =
      <Player, StreamSubscription<bool>>{};

  bool _blocked = false;
  String _deviceId = '';
  String _platform = '';
  String _currentChannel = idleLabel;
  Timer? _timer;
  bool _started = false;
  bool _busy = false;

  bool get blocked => _blocked;
  Stream<bool> get blockedChanges => _blockedController.stream;
  String get deviceId => _deviceId;

  Uri _uri(String path) => Uri.parse('$databaseUrl/devices/$_deviceId$path.json');

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _deviceId = await _loadOrCreateId();
      _platform = await _detectPlatform();
    } catch (_) {
      _started = false;
      return;
    }
    unawaited(_tick());
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  Future<String> _loadOrCreateId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && RegExp(r'^ARO-[A-Z0-9]{4}$').hasMatch(existing)) {
      return existing;
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final code =
        'ARO-${List<String>.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}';
    await prefs.setString(_prefsKey, code);
    return code;
  }

  Future<String> _detectPlatform() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isWindows) {
        final w = await info.windowsInfo;
        final name = w.productName.isEmpty ? 'Windows' : w.productName;
        return 'Windows PC ($name)';
      }
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final model = a.model;
        final isAmazon = a.manufacturer.toLowerCase().contains('amazon') ||
            model.toUpperCase().startsWith('AFT');
        if (isAmazon) return 'Fire TV ($model)';
        if (a.systemFeatures.contains('android.software.leanback')) {
          return 'Android TV (${a.manufacturer} $model)';
        }
        return 'Android (${a.manufacturer} $model)';
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  void setWatching(String? name) {
    final value = (name == null || name.trim().isEmpty) ? idleLabel : name.trim();
    if (value == _currentChannel) return;
    _currentChannel = value;
    if (_started && _deviceId.isNotEmpty) unawaited(_tick());
  }

  void setIdle() => setWatching(null);

  Future<void> _tick() async {
    if (_busy || _deviceId.isEmpty) return;
    _busy = true;
    try {
      await http
          .patch(
            _uri(''),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'deviceId': _deviceId,
              'platform': _platform,
              'currentChannel': _currentChannel,
              'version': appVersion,
              'lastSeen': <String, String>{'.sv': 'timestamp'},
            }),
          )
          .timeout(_timeout);
    } catch (_) {}
    try {
      final res = await http.get(_uri('/blocked')).timeout(_timeout);
      if (res.statusCode == 200) {
        _setBlocked(res.body.trim() == 'true');
      }
    } catch (_) {}
    _busy = false;
    if (_blocked) _pauseAll();
  }

  void _setBlocked(bool value) {
    if (value == _blocked) return;
    _blocked = value;
    _blockedController.add(value);
    if (value) _pauseAll();
  }

  void _pauseAll() {
    for (final p in _players.keys.toList()) {
      try {
        p.pause();
      } catch (_) {}
    }
  }

  void registerPlayer(Player player) {
    if (_players.containsKey(player)) return;
    _players[player] = player.stream.playing.listen((playing) {
      if (playing && _blocked) {
        try {
          player.pause();
        } catch (_) {}
      }
    });
    if (_blocked) _pauseAll();
  }

  void unregisterPlayer(Player player) {
    _players.remove(player)?.cancel();
  }
}
