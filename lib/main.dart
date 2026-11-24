import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'models/media_item.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/l10n.dart';
import 'services/library_prefs.dart';
import 'services/m3u_parser.dart';
import 'services/remote_service.dart';
import 'services/storage_service.dart';

const Color kNeonCyan = Color(0xFF3B8BFF);
const Color kNeonMagenta = Color(0xFFE50914);
const Color kNeonBackground = Color(0xFF0F172A);
const Color kNeonSurface = Color(0xFF1E293B);
const Color kNeonSurfaceHigh = Color(0xFF273449);
const Color kNeonBorder = Color(0xFF334155);
const Color kNeonCyanSoft = Color(0x333B8BFF);
const Color kNeonCyanGlow = Color(0x733B8BFF);
const Color kNeonMagentaSoft = Color(0x33E50914);
const Color kNeonMagentaGlow = Color(0x73E50914);

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      return true;
    };
    ErrorWidget.builder = (details) {
      return const ColoredBox(color: kNeonBackground);
    };
    MediaKit.ensureInitialized();
    await StorageService.instance.init();
    await LibraryPrefs.instance.init();
    PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSize = 300;
    unawaited(RemoteService.instance.start());
    runApp(const ArOplayerApp());
  }, (error, stack) {});
}

PlaylistData applyParental(PlaylistData data) {
  final storage = StorageService.instance;
  if (!storage.hideAdult) return data;

  bool blocked(MediaItem item) =>
      isAdultText(item.name) || isAdultText(item.groupTitle);

  final live = data.live.where((item) => !blocked(item)).toList();
  final newMovies = data.newMovies.where((item) => !blocked(item)).toList();
  final movies = data.movies.where((item) => !blocked(item)).toList();

  final series = <SeriesItem>[];
  for (final entry in data.series) {
    if (isAdultText(entry.name) || isAdultText(entry.groupTitle)) continue;
    final seasons = <int, List<MediaItem>>{};
    entry.seasons.forEach((seasonNo, episodes) {
      final filtered = episodes.where((item) => !blocked(item)).toList();
      if (filtered.isNotEmpty) {
        seasons[seasonNo] = filtered;
      }
    });
    if (seasons.isEmpty) continue;
    series.add(SeriesItem(
      name: entry.name,
      logo: entry.logo,
      groupTitle: entry.groupTitle,
      seasons: seasons,
    ));
  }

  return PlaylistData(
    live: live,
    newMovies: newMovies,
    movies: movies,
    series: series,
  );
}

ThemeData buildNeonTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kNeonCyan,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kNeonCyan,
    onPrimary: Colors.black,
    secondary: kNeonMagenta,
    onSecondary: Colors.white,
    surface: kNeonSurface,
    onSurface: Colors.white,
    error: kNeonMagenta,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: kNeonBackground,
    canvasColor: kNeonBackground,
    focusColor: kNeonCyanSoft,
    hoverColor: kNeonCyanSoft,
    splashColor: kNeonCyanSoft,
    highlightColor: kNeonCyanSoft,
    dividerColor: kNeonBorder,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: Color(0xFFB9B9C9)),
      bodySmall: TextStyle(color: Color(0xFF8A8A9B)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kNeonCyan,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kNeonCyan,
        side: const BorderSide(color: kNeonCyan, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kNeonCyan),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kNeonSurfaceHigh,
      hintStyle: const TextStyle(color: Color(0xFF6E6E80)),
      labelStyle: const TextStyle(color: Color(0xFF9A9AAB)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNeonBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNeonBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNeonCyan, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNeonMagenta, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kNeonMagenta, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kNeonSurfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kNeonCyan,
      linearTrackColor: kNeonSurfaceHigh,
      circularTrackColor: kNeonSurfaceHigh,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  );
}

class ShortcutsActivate extends StatelessWidget {
  const ShortcutsActivate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: child,
    );
  }
}

class ArOplayerApp extends StatelessWidget {
  const ArOplayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L10n.language,
      builder: (context, lang, child) {
        return MaterialApp(
          title: 'ArOplayer',
          debugShowCheckedModeBanner: false,
          theme: buildNeonTheme(),
          builder: (context, child) => ShortcutsActivate(
            child: KeyedSubtree(
              key: ValueKey<String>(lang),
              child: BlockedGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
          home: const AppLoader(),
        );
      },
    );
  }
}

class BlockedGate extends StatelessWidget {
  const BlockedGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: RemoteService.instance.blockedChanges,
      initialData: RemoteService.instance.blocked,
      builder: (context, snapshot) {
        final blocked = snapshot.data ?? false;
        return Stack(
          children: [
            child,
            if (blocked)
              Positioned.fill(
                child: Focus(
                  autofocus: true,
                  onKeyEvent: (node, event) => KeyEventResult.handled,
                  child: const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Bu cihaz yönetici tarafından devre dışı bırakıldı',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  PlaylistData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = StorageService.instance;
    if (!storage.hasSource) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _data = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final cached = await storage.readCachedPlaylist();
    if (cached != null) {
      PlaylistData? parsed;
      try {
        parsed = await M3uService.parse(cached);
      } catch (_) {
        parsed = null;
      }
      if (parsed != null && !parsed.isEmpty) {
        if (!mounted) return;
        setState(() {
          _data = parsed;
          _loading = false;
          _error = null;
        });
        _refreshFromNetwork();
        return;
      }
    }

    await _fetchAndShow();
  }

  Future<void> _refreshFromNetwork() async {
    final storage = StorageService.instance;
    final url = storage.m3uUrl;
    if (url == null) return;
    try {
      final text = await M3uService.fetch(url);
      await storage.cachePlaylist(text);
      final parsed = await M3uService.parse(text);
      if (!mounted || parsed.isEmpty) return;
      setState(() {
        _data = parsed;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _fetchAndShow() async {
    final storage = StorageService.instance;
    final url = storage.m3uUrl;
    if (url == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t('Kaynak adresi bulunamadı.');
      });
      return;
    }
    try {
      final text = await M3uService.fetch(url);
      await storage.cachePlaylist(text);
      final parsed = await M3uService.parse(text);
      if (!mounted) return;
      setState(() {
        _data = parsed;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${t('Liste yüklenemedi')}: $error';
      });
    }
  }

  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService.instance;
    if (!storage.hasSource) {
      return const SetupScreen();
    }
    if (_loading) {
      return const _LoadingScreen();
    }
    final error = _error;
    if (error != null) {
      return _ErrorScreen(
        message: error,
        onRetry: _load,
        onSetup: _openSetup,
      );
    }
    final data = _data;
    if (data == null) {
      return _ErrorScreen(
        message: t('Liste yüklenemedi.'),
        onRetry: _load,
        onSetup: _openSetup,
      );
    }
    return HomeScreen(data: applyParental(data));
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text(
              'ArOplayer',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: kNeonCyan,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('Liste yükleniyor...'),
              style: const TextStyle(color: Color(0xFF9A9AAB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSetup,
  });

  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: kNeonMagenta,
                ),
                const SizedBox(height: 20),
                Text(
                  t('Bağlantı kurulamadı'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF9A9AAB)),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () {
                    onRetry();
                  },
                  child: Text(t('Yeniden dene')),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onSetup,
                  child: Text(t('Ayarlar / Kaynak değiştir')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
