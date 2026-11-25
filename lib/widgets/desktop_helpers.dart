import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindow {
  DesktopWindow._();

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    await windowManager.ensureInitialized();
  }

  static Future<void> toggleFullscreen() async {
    if (!Platform.isWindows) return;
    final on = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!on);
  }
}

class AutoHideCursor extends StatefulWidget {
  const AutoHideCursor({super.key, required this.child});

  final Widget child;

  @override
  State<AutoHideCursor> createState() => _AutoHideCursorState();
}

class _AutoHideCursorState extends State<AutoHideCursor> {
  bool _hidden = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _wake() {
    if (_hidden && mounted) {
      setState(() {
        _hidden = false;
      });
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hidden = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _hidden ? SystemMouseCursors.none : SystemMouseCursors.basic,
      onHover: (_) => _wake(),
      child: widget.child,
    );
  }
}
