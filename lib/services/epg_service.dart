import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

class EpgProgram {
  const EpgProgram(this.title, this.start, this.stop);

  final String title;
  final DateTime start;
  final DateTime stop;

  String get timeRange => '${_hm(start)} - ${_hm(stop)}';

  static String _hm(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// XMLTV EPG verisini indirip "şu an" ve "sıradaki" programı tutar.
class EpgService {
  EpgService._();

  static final EpgService instance = EpgService._();

  /// Veri her yenilendiğinde artar; ekranlar dinleyerek yeniden çizer.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Map<String, EpgProgram> _now = <String, EpgProgram>{};
  Map<String, EpgProgram> _next = <String, EpgProgram>{};
  bool _loading = false;
  bool _loaded = false;
  String _loadedUrl = '';

  bool get isLoaded => _loaded;

  EpgProgram? current(String tvgId) {
    final key = tvgId.trim().toLowerCase();
    if (key.isEmpty) return null;
    final now = DateTime.now().toUtc();
    final cur = _now[key];
    if (cur != null && now.isBefore(cur.stop)) return cur;
    final nxt = _next[key];
    if (nxt != null && !now.isBefore(nxt.start) && now.isBefore(nxt.stop)) {
      return nxt;
    }
    return null;
  }

  EpgProgram? next(String tvgId) {
    final key = tvgId.trim().toLowerCase();
    if (key.isEmpty) return null;
    final cur = current(tvgId);
    final nxt = _next[key];
    if (nxt == null) return null;
    if (cur != null && identical(cur, nxt)) return null;
    if (!nxt.start.isAfter(DateTime.now().toUtc())) return null;
    return nxt;
  }

  /// Kanalın şu an oynayan programını döner, yoksa null.
  String? nowPlaying(String tvgId) => current(tvgId)?.title;

  /// Elle girilen adres varsa onu, yoksa M3U başlığındaki ilk adresi indirir.
  Future<void> load(List<String> urls) async {
    if (_loading) return;
    final manual = StorageService.instance.epgUrl.trim();
    final url = manual.isNotEmpty
        ? manual
        : (urls.isEmpty ? '' : urls.first.trim());
    if (url.isEmpty) return;
    if (_loaded && url == _loadedUrl) return;
    _loading = true;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      List<int> bytes = response.bodyBytes;
      if (bytes.length > 30 * 1024 * 1024) return;
      if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        bytes = gzip.decode(bytes);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final parsed = await compute(_parseXmltv, text);
      final now = <String, EpgProgram>{};
      final next = <String, EpgProgram>{};
      for (final entry in parsed.entries) {
        final v = entry.value;
        final program = EpgProgram(
          v[0] as String,
          DateTime.fromMillisecondsSinceEpoch(v[1] as int, isUtc: true),
          DateTime.fromMillisecondsSinceEpoch(v[2] as int, isUtc: true),
        );
        if (entry.key.startsWith('n:')) {
          now[entry.key.substring(2)] = program;
        } else {
          next[entry.key.substring(2)] = program;
        }
      }
      _now = now;
      _next = next;
      _loaded = true;
      _loadedUrl = url;
      changes.value = changes.value + 1;
    } catch (_) {
      // EPG isteğe bağlıdır; hata sessizce yok sayılır.
    } finally {
      _loading = false;
    }
  }

  /// Ayarlardan adres değişince yeniden indirmek için.
  Future<void> reload(List<String> urls) {
    _loaded = false;
    return load(urls);
  }
}

/// XMLTV metninden şu anki ve sıradaki programı çıkarır.
/// Anahtarlar "n:kanal" (şu an) ve "x:kanal" (sıradaki); değer [başlık, başlangıçMs, bitişMs].
Map<String, List<Object>> _parseXmltv(String xml) {
  final result = <String, List<Object>>{};
  final now = DateTime.now().toUtc();
  final programmeRe = RegExp(r'<programme\b([^>]*)>([\s\S]*?)</programme>');
  final startRe = RegExp(r'start="([^"]*)"');
  final stopRe = RegExp(r'stop="([^"]*)"');
  final channelRe = RegExp(r'channel="([^"]*)"');
  final titleRe = RegExp(r'<title[^>]*>([\s\S]*?)</title>');
  for (final match in programmeRe.allMatches(xml)) {
    final attrs = match.group(1) ?? '';
    final start = _parseXmltvTime(startRe.firstMatch(attrs)?.group(1) ?? '');
    final stop = _parseXmltvTime(stopRe.firstMatch(attrs)?.group(1) ?? '');
    if (start == null || stop == null) continue;
    final isNow = !now.isBefore(start) && now.isBefore(stop);
    final isFuture = start.isAfter(now);
    if (!isNow && !isFuture) continue;
    final channel = (channelRe.firstMatch(attrs)?.group(1) ?? '')
        .trim()
        .toLowerCase();
    if (channel.isEmpty) continue;
    final title = titleRe.firstMatch(match.group(2) ?? '')?.group(1) ?? '';
    var clean = _decodeEntities(title).trim();
    final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*)\]\]>$').firstMatch(clean);
    if (cdata != null) clean = (cdata.group(1) ?? '').trim();
    if (clean.isEmpty) continue;
    final entry = <Object>[
      clean,
      start.millisecondsSinceEpoch,
      stop.millisecondsSinceEpoch,
    ];
    if (isNow) {
      result['n:$channel'] = entry;
    } else {
      final key = 'x:$channel';
      final existing = result[key];
      if (existing == null || start.millisecondsSinceEpoch < (existing[1] as int)) {
        result[key] = entry;
      }
    }
  }
  return result;
}

/// "YYYYMMDDHHMMSS +ZZZZ" biçimini UTC zamana çevirir.
DateTime? _parseXmltvTime(String raw) {
  final text = raw.trim();
  final digits =
      RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})').firstMatch(text);
  if (digits == null) return null;
  final year = int.tryParse(digits.group(1) ?? '');
  final month = int.tryParse(digits.group(2) ?? '');
  final day = int.tryParse(digits.group(3) ?? '');
  final hour = int.tryParse(digits.group(4) ?? '');
  final minute = int.tryParse(digits.group(5) ?? '');
  final second = int.tryParse(digits.group(6) ?? '');
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  var utc = DateTime.utc(year, month, day, hour, minute, second);
  final offset = RegExp(r'([+-])(\d{2})(\d{2})\s*$').firstMatch(text);
  if (offset != null) {
    final sign = offset.group(1) == '-' ? -1 : 1;
    final offsetMinutes = sign *
        (int.parse(offset.group(2) ?? '0') * 60 +
            int.parse(offset.group(3) ?? '0'));
    utc = utc.subtract(Duration(minutes: offsetMinutes));
  }
  return utc;
}

String _decodeEntities(String input) {
  var text = input;
  text = text.replaceAll('&amp;', '&');
  text = text.replaceAll('&lt;', '<');
  text = text.replaceAll('&gt;', '>');
  text = text.replaceAll('&quot;', '"');
  text = text.replaceAll('&apos;', "'");
  text = text.replaceAll('&#39;', "'");
  text = text.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (match) => String.fromCharCode(int.tryParse(match.group(1) ?? '') ?? 0),
  );
  return text;
}
