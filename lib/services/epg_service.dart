import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// XMLTV EPG verisini indirip "şu an" oynayan programı tutar.
class EpgService {
  EpgService._();

  static final EpgService instance = EpgService._();

  /// Veri her yenilendiğinde artar; ekranlar dinleyerek yeniden çizer.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Map<String, String> _now = <String, String>{};
  bool _loading = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Kanalın şu an oynayan programını döner, yoksa null.
  String? nowPlaying(String tvgId) {
    final key = tvgId.trim().toLowerCase();
    if (key.isEmpty) return null;
    return _now[key];
  }

  /// İlk EPG adresini indirir. Zaten yüklüyse veya liste boşsa hiçbir şey yapmaz.
  Future<void> load(List<String> urls) async {
    if (_loading || _loaded) return;
    if (urls.isEmpty) return;
    final url = urls.first.trim();
    if (url.isEmpty) return;
    _loading = true;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      List<int> bytes = response.bodyBytes;
      if (bytes.length > 30 * 1024 * 1024) return;
      if (url.toLowerCase().endsWith('.gz')) {
        bytes = gzip.decode(bytes);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final parsed = await compute(_parseXmltvNow, text);
      _now = parsed;
      _loaded = true;
      changes.value = changes.value + 1;
    } catch (_) {
      // EPG isteğe bağlıdır; hata sessizce yok sayılır.
    } finally {
      _loading = false;
    }
  }
}

/// XMLTV metninden yalnızca şu anki zamanı kapsayan programları çıkarır.
Map<String, String> _parseXmltvNow(String xml) {
  final result = <String, String>{};
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
    if (!now.isAfter(start) || !now.isBefore(stop)) continue;
    final channel = (channelRe.firstMatch(attrs)?.group(1) ?? '')
        .trim()
        .toLowerCase();
    if (channel.isEmpty) continue;
    final title = titleRe.firstMatch(match.group(2) ?? '')?.group(1) ?? '';
    final clean = _decodeEntities(title).trim();
    if (clean.isEmpty) continue;
    result[channel] = clean;
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
