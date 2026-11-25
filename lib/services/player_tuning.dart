import 'package:media_kit/media_kit.dart';

Future<void> _setProperty(dynamic platform, String key, String value) async {
  try {
    await platform.setProperty(key, value);
  } catch (_) {}
}

Future<void> tunePlayer(Player player, {required bool live}) async {
  final dynamic platform = player.platform;
  if (platform == null) return;
  if (live) {
    await _setProperty(platform, 'cache-secs', '15');
    await _setProperty(platform, 'demuxer-readahead-secs', '15');
    await _setProperty(platform, 'demuxer-max-back-bytes', '5242880');
    await _setProperty(platform, 'demuxer-max-bytes', '16777216');
    await _setProperty(platform, 'network-timeout', '15');
    await _setProperty(platform, 'cache-pause-initial', 'no');
    await _setProperty(platform, 'cache-pause-wait', '1');
    return;
  }
  await _setProperty(platform, 'cache-secs', '30');
  await _setProperty(platform, 'demuxer-readahead-secs', '30');
  await _setProperty(platform, 'demuxer-max-back-bytes', '5242880');
  await _setProperty(platform, 'demuxer-max-bytes', '33554432');
  await _setProperty(platform, 'network-timeout', '15');
}

Future<void> setHwDec(Player player, bool hw) async {
  final dynamic platform = player.platform;
  if (platform == null) return;
  await _setProperty(platform, 'hwdec', hw ? 'auto-safe' : 'no');
}
