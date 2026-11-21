import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';

class VodPlayerScreen extends StatefulWidget {
  const VodPlayerScreen({
    super.key,
    required this.item,
    this.startAt = Duration.zero,
    this.playlist = const <MediaItem>[],
  });

  final MediaItem item;
  final Duration startAt;
  final List<MediaItem> playlist;

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'vod-player');

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  Timer? _saveTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _dragging = false;
  bool _startApplied = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _positionSub = _player.stream.position.listen((value) {
      if (!mounted) return;
      setState(() {
        _position = value;
      });
    });
    _durationSub = _player.stream.duration.listen((value) {
      if (!mounted) return;
      setState(() {
        _duration = value;
      });
      if (!_startApplied &&
          widget.startAt > Duration.zero &&
          value > Duration.zero) {
        _startApplied = true;
        _player.seek(widget.startAt);
      }
    });
    _playingSub = _player.stream.playing.listen((value) {
      if (!mounted) return;
      setState(() {
        _playing = value;
      });
    });
    _completedSub = _player.stream.completed.listen((value) {
      if (value) {
        _handleCompleted();
      }
    });
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveProgress();
    });
    _player.open(Media(widget.item.url));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _focusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  void _saveProgress() {
    final durationSec = _duration.inSeconds;
    final positionSec = _position.inSeconds;
    if (durationSec <= 0 || positionSec <= 0) return;
    StorageService.instance.saveProgress(widget.item, positionSec, durationSec);
  }

  void _handleCompleted() {
    final playlist = widget.playlist;
    if (playlist.isEmpty) return;
    final index = playlist.indexWhere((item) => item.id == widget.item.id);
    if (index < 0 || index + 1 >= playlist.length) return;
    final next = playlist[index + 1];
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => VodPlayerScreen(
          item: next,
          playlist: playlist,
        ),
      ),
    );
  }

  void _seekBy(Duration delta) {
    var target = _position + delta;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (_duration > Duration.zero && target > _duration) {
      target = _duration;
    }
    _player.seek(target);
    setState(() {
      _position = target;
    });
  }

  void _togglePlay() {
    _player.playOrPause();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  double get _sliderMax {
    final ms = _duration.inMilliseconds;
    return ms > 0 ? ms.toDouble() : 1.0;
  }

  double get _sliderValue {
    if (_dragging) {
      return _dragValue.clamp(0.0, _sliderMax);
    }
    return _position.inMilliseconds.toDouble().clamp(0.0, _sliderMax);
  }

  String _formatDuration(Duration value) {
    final total = value.inSeconds;
    if (total <= 0) return '00:00';
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xCC000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: <Widget>[
            _ControlButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Geri',
              onTap: () {
                Navigator.of(context).maybePop();
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    widget.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.groupTitle.isEmpty
                        ? 'Oynatıcı'
                        : widget.item.groupTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB9B9C9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            Color(0xE6000000),
            Color(0x00000000),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB9B9C9),
                  ),
                ),
                Expanded(
                  child: ExcludeFocus(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: kNeonCyan,
                        inactiveTrackColor: kNeonSurfaceHigh,
                        thumbColor: kNeonCyan,
                        overlayColor: kNeonCyanSoft,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        max: _sliderMax,
                        onChanged: (value) {
                          setState(() {
                            _dragging = true;
                            _dragValue = value;
                          });
                        },
                        onChangeEnd: (value) {
                          _player.seek(
                            Duration(milliseconds: value.round()),
                          );
                          setState(() {
                            _dragging = false;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB9B9C9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _ControlButton(
                  icon: Icons.replay_10_rounded,
                  tooltip: '10 saniye geri',
                  onTap: () {
                    _seekBy(const Duration(seconds: -10));
                  },
                ),
                const SizedBox(width: 22),
                _ControlButton(
                  icon: _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: _playing ? 'Duraklat' : 'Oynat',
                  large: true,
                  onTap: _togglePlay,
                ),
                const SizedBox(width: 22),
                _ControlButton(
                  icon: Icons.forward_10_rounded,
                  tooltip: '10 saniye ileri',
                  onTap: () {
                    _seekBy(const Duration(seconds: 10));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool large;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final double size = widget.large ? 60 : 44;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (event) {
          if (_hovered) return;
          setState(() {
            _hovered = true;
          });
        },
        onExit: (event) {
          if (!_hovered) return;
          setState(() {
            _hovered = false;
          });
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _hovered
                  ? kNeonCyanSoft
                  : Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: _hovered ? kNeonCyan : const Color(0x33FFFFFF),
                width: _hovered ? 2 : 1,
              ),
              boxShadow: _hovered
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: kNeonCyanGlow,
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Icon(
              widget.icon,
              size: widget.large ? 32 : 22,
              color: _hovered ? kNeonCyan : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
