import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class QrSetupSubmission {
  const QrSetupSubmission({
    required this.type,
    required this.m3uUrl,
    required this.host,
    required this.username,
    required this.password,
    required this.epgUrl,
  });

  final String type;
  final String m3uUrl;
  final String host;
  final String username;
  final String password;
  final String epgUrl;
}

class QrSetupServer {
  QrSetupServer._();

  static final QrSetupServer instance = QrSetupServer._();

  static const int port = 8787;

  HttpServer? _server;
  String _token = '';
  final StreamController<QrSetupSubmission> _submissions =
      StreamController<QrSetupSubmission>.broadcast();

  Stream<QrSetupSubmission> get submissions => _submissions.stream;

  Future<String> start() async {
    await stop();
    final rnd = Random.secure();
    _token = List<String>.generate(6, (_) => rnd.nextInt(10).toString())
        .join();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handle, onError: (_) {});
    final ip = await _localIp();
    return 'http://$ip:$port/?k=$_token';
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = '';
    if (server != null) {
      await server.close(force: true);
    }
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          if (!address.isLoopback) return address.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method == 'GET' && request.uri.path == '/') {
        final k = request.uri.queryParameters['k'] ?? '';
        if (k != _token) {
          response
            ..statusCode = HttpStatus.forbidden
            ..headers.contentType = ContentType.text
            ..write('Gecersiz veya suresi dolmus kod.');
        } else {
          response
            ..headers.contentType = ContentType.html
            ..write(_formHtml(_token));
        }
      } else if (request.method == 'POST' && request.uri.path == '/submit') {
        final body = await utf8.decoder.bind(request).join();
        final form = Uri.splitQueryString(body);
        if (form['k'] != _token || _token.isEmpty) {
          response
            ..statusCode = HttpStatus.forbidden
            ..headers.contentType = ContentType.text
            ..write('Gecersiz veya suresi dolmus kod.');
        } else {
          final submission = QrSetupSubmission(
            type: form['type'] == 'xtream' ? 'xtream' : 'm3u',
            m3uUrl: (form['m3u'] ?? '').trim(),
            host: (form['host'] ?? '').trim(),
            username: (form['user'] ?? '').trim(),
            password: form['pass'] ?? '',
            epgUrl: (form['epg'] ?? '').trim(),
          );
          _token = '';
          response
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body style="font-family:sans-serif;background:#0b0b12;'
              'color:#fff;padding:24px"><h2>Gonderildi</h2>'
              '<p>Bilgiler TV ekranina aktarildi. Bu sayfayi kapatabilirsiniz.</p>'
              '</body></html>',
            );
          _submissions.add(submission);
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  String _formHtml(String token) {
    return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ArOplayer Kurulum</title>
<style>
body{font-family:sans-serif;background:#0b0b12;color:#fff;margin:0;padding:20px}
h2{color:#33e6ff}label{display:block;margin-top:12px;font-size:14px}
input,select{width:100%;box-sizing:border-box;padding:10px;margin-top:4px;
font-size:16px;border-radius:8px;border:1px solid #2a2a3a;background:#161622;color:#fff}
button{margin-top:20px;width:100%;padding:14px;font-size:17px;border:0;
border-radius:10px;background:#33e6ff;color:#000;font-weight:bold}
</style></head><body>
<h2>ArOplayer - TV Kurulumu</h2>
<form method="post" action="/submit">
<input type="hidden" name="k" value="$token">
<label>Kaynak
<select name="type"><option value="m3u">M3U Linki</option>
<option value="xtream">Xtream Codes</option></select></label>
<label>M3U Linki<input name="m3u" placeholder="http://ornek.com/liste.m3u"></label>
<label>Sunucu URL (Xtream)<input name="host" placeholder="http://sunucu.com:8080"></label>
<label>Kullanici Adi (Xtream)<input name="user"></label>
<label>Sifre (Xtream)<input name="pass" type="password"></label>
<label>EPG URL (istege bagli)<input name="epg"></label>
<button type="submit">TV'ye Gonder</button>
</form></body></html>
''';
  }
}
