import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.pageUrl,
    this.zipUrl = '',
  });

  final String version;
  final String notes;
  final String apkUrl;
  final String pageUrl;
  final String zipUrl;
}

class UpdateService {
  UpdateService._();

  static const String _releaseApi =
      'https://api.github.com/repos/mev281/ArOplayer/releases/latest';
  static const String _fallbackPage =
      'https://github.com/mev281/ArOplayer/releases/latest';

  static Future<UpdateInfo?> check() async {
    try {
      final response = await http.get(
        Uri.parse(_releaseApi),
        headers: const <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ArOplayer',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final tag = decoded['tag_name'];
      if (tag is! String) return null;
      final remote = _normalize(tag);
      if (remote.isEmpty) return null;
      final packageInfo = await PackageInfo.fromPlatform();
      final current = _normalize(packageInfo.version);
      if (_compare(remote, current) <= 0) return null;

      var apkUrl = '';
      var zipUrl = '';
      final assets = decoded['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is! Map) continue;
          final name = asset['name'];
          final url = asset['browser_download_url'];
          if (name is! String || url is! String) continue;
          final lower = name.toLowerCase();
          if (apkUrl.isEmpty && lower.endsWith('.apk')) {
            apkUrl = url;
          } else if (zipUrl.isEmpty && lower.endsWith('.zip')) {
            zipUrl = url;
          }
        }
      }
      if (Platform.isAndroid && apkUrl.isEmpty) return null;
      if (Platform.isWindows && zipUrl.isEmpty) return null;

      final page = decoded['html_url'];
      final notes = decoded['body'];
      return UpdateInfo(
        version: remote,
        notes: notes is String ? notes : '',
        apkUrl: apkUrl,
        pageUrl: page is String && page.isNotEmpty ? page : _fallbackPage,
        zipUrl: zipUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> downloadAndInstall(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    if (Platform.isWindows) {
      await _downloadAndInstallWindows(info, onProgress);
      return;
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('Guncelleme yalnizca Android ve Windows uzerinde kurulur.');
    }
    if (info.apkUrl.isEmpty) {
      throw StateError('APK adresi bulunamadi.');
    }
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}ArOplayer-update.apk',
    );
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw HttpException('Indirme basarisiz: ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress((received / total).clamp(0.0, 1.0).toDouble());
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress(1);
    } finally {
      client.close();
    }
    await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
  }

  static Future<void> _downloadAndInstallWindows(
    UpdateInfo info,
    void Function(double) onProgress,
  ) async {
    if (info.zipUrl.isEmpty) {
      throw StateError('ZIP adresi bulunamadi.');
    }
    final sep = Platform.pathSeparator;
    final workDir = Directory(
      '${(await getTemporaryDirectory()).path}${sep}ArOplayer-update',
    );
    if (await workDir.exists()) {
      await workDir.delete(recursive: true);
    }
    await workDir.create(recursive: true);
    final zipFile = File('${workDir.path}${sep}update.zip');
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(info.zipUrl)));
      if (response.statusCode != 200) {
        throw HttpException('Indirme basarisiz: ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      final sink = zipFile.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress((received / total).clamp(0.0, 1.0).toDouble());
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      onProgress(1);
    } finally {
      client.close();
    }

    final exePath = Platform.resolvedExecutable;
    final exeName = exePath.substring(exePath.lastIndexOf(sep) + 1);
    final appDir = exePath.substring(0, exePath.lastIndexOf(sep));
    final extractDir = '${workDir.path}${sep}extracted';
    final script = File('${workDir.path}${sep}update.bat');
    final lines = <String>[
      '@echo off',
      'setlocal',
      'timeout /t 3 /nobreak >nul',
      'taskkill /F /IM "$exeName" >nul 2>&1',
      'timeout /t 1 /nobreak >nul',
      'powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath \'${zipFile.path}\' -DestinationPath \'$extractDir\' -Force"',
      'if errorlevel 1 goto restart',
      'xcopy "$extractDir\\*" "$appDir" /E /Y /I /Q >nul',
      ':restart',
      'start "" "$exePath"',
      'endlocal',
    ];
    await script.writeAsString(lines.join('\r\n'));
    await Process.start(
      'cmd.exe',
      <String>['/c', script.path],
      mode: ProcessStartMode.detached,
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    exit(0);
  }

  static String _normalize(String raw) {
    var value = raw.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final plus = value.indexOf('+');
    if (plus >= 0) value = value.substring(0, plus);
    final dash = value.indexOf('-');
    if (dash >= 0) value = value.substring(0, dash);
    return value.trim();
  }

  static int _compare(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? int.tryParse(left[i]) ?? 0 : 0;
      final r = i < right.length ? int.tryParse(right[i]) ?? 0 : 0;
      if (l != r) return l > r ? 1 : -1;
    }
    return 0;
  }
}
