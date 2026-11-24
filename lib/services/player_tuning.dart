import 'package:media_kit/media_kit.dart';

/// Platform özelliğini sessizce ayarlar; desteklenmeyen anahtarlar yok sayılır.
Future<void> _setProperty(dynamic platform, String key, String value) async {
  try {
    await platform.setProperty(key, value);
  } catch (_) {
    // Özellik desteklenmiyorsa hata sessizce yutulur.
  }
}

/// Oynatıcının tampon/gecikme ayarlarını uygular.
/// Canlıda düşük gecikme, VOD'da geniş tampon hedeflenir.
Future<void> tunePlayer(Player player, {required bool live}) async {
  final dynamic platform = player.platform;
  if (platform == null) return;
  await _setProperty(platform, 'user-agent', 'Lavf/58.76.100');
  await _setProperty(platform, 'hwdec', 'auto-safe');
  await _setProperty(platform, 'network-timeout', '20');
  if (live) {
    await _setProperty(platform, 'cache-secs', '15');
    await _setProperty(platform, 'demuxer-readahead-secs', '15');
    await _setProperty(platform, 'demuxer-max-back-bytes', '5242880');
    await _setProperty(platform, 'demuxer-max-bytes', '16777216');
    await _setProperty(platform, 'cache-pause-initial', 'no');
    await _setProperty(platform, 'cache-pause-wait', '1');
    await _setProperty(platform, 'demuxer-lavf-analyzeduration', '5');
    await _setProperty(platform, 'demuxer-lavf-probesize', '2000000');
    return;
  }
  await _setProperty(platform, 'cache-secs', '30');
  await _setProperty(platform, 'demuxer-readahead-secs', '30');
  await _setProperty(platform, 'demuxer-max-back-bytes', '5242880');
  await _setProperty(platform, 'demuxer-max-bytes', '33554432');
  await _setProperty(platform, 'demuxer-lavf-analyzeduration', '1');
  await _setProperty(platform, 'demuxer-lavf-probesize', '500000');
}

/// Donanım (HW) / yazılım (SW) kod çözücü seçimini uygular.
Future<void> setHwDec(Player player, bool hw) async {
  final dynamic platform = player.platform;
  if (platform == null) return;
  await _setProperty(platform, 'hwdec', hw ? 'auto-safe' : 'no');
}
