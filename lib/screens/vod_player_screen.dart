import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/l10n.dart';
import '../services/player_tuning.dart';
import '../services/remote_service.dart';
import '../services/storage_service.dart';
import '../widgets/desktop_helpers.dart';
import '../widgets/track_picker.dart';

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
  final FocusNode _audioFocus = FocusNode(debugLabel: 'vod-audio');
  final FocusNode _subtitleFocus = FocusNode(debugLabel: 'vod-subtitle');
  final FocusNode _fitFocus = FocusNode(debugLabel: 'vod-fit');
  final FocusNode _codecFocus = FocusNode(debugLabel: 'vod-codec');

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
  int _fitMode = 0;
  bool _hwDec = true;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    RemoteService.instance.registerPlayer(_player);
    RemoteService.instance.setWatching(widget.item.name);
    unawaited(tunePlayer(_player, live: false));
    unawaited(_enableWakelock());
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
      if (!value) {
        _saveProgress();
      }
    });
    _completedSub = _player.stream.completed.listen((value) {
      if (value) {
        _handleCompleted();
      }
    });
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveProgress();
    });
    _player.open(Media(widget.item.url, httpHeaders: widget.item.httpHeaders));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveProgress();
    unawaited(_disableWakelock());
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _focusNode.dispose();
    _audioFocus.dispose();
    _subtitleFocus.dispose();
    _fitFocus.dispose();
    _codecFocus.dispose();
    RemoteService.instance.unregisterPlayer(_player);
    RemoteService.instance.setIdle();
    _player.dispose();
    super.dispose();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Desteklenmeyen platformlarda sessizce yok sayılır.
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Desteklenmeyen platformlarda sessizce yok sayılır.
    }
  }

  String get _fitLabel {
    switch (_fitMode) {
      case 1:
        return t('Sığdır');
      case 2:
        return t('Doldur');
      default:
        return '16:9';
    }
  }

  void _cycleFit() {
    setState(() {
      _fitMode = (_fitMode + 1) % 3;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(_fitLabel),
      ),
    );
  }

  Future<void> _toggleHwDec() async {
    final target = _position;
    setState(() {
      _hwDec = !_hwDec;
    });
    await setHwDec(_player, _hwDec);
    await _player.open(
      Media(widget.item.url, httpHeaders: widget.item.httpHeaders),
      play: true,
    );
    if (target > Duration.zero) {
      await _player.seek(target);
    }
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

  Future<void> _openAudioPicker() async {
    await showAudioPicker(context, _player);
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  Future<void> _openSubtitlePicker() async {
    await showSubtitlePicker(context, _player);
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.f11) {
      DesktopWindow.toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _audioFocus.requestFocus();
      return KeyEventResult.handled;
    }
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
              child: AutoHideCursor(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: DesktopWindow.toggleFullscreen,
                  child: _buildVideo(),
                ),
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

  Widget _buildVideo() {
    final video = Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: _fitMode == 2 ? BoxFit.cover : BoxFit.contain,
    );
    if (_fitMode != 0) return video;
    return Center(
      child: AspectRatio(aspectRatio: 16 / 9, child: video),
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
              tooltip: t('Geri'),
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
                        ? t('Oynatıcı')
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
                  tooltip: t('10 saniye geri'),
                  onTap: () {
                    _seekBy(const Duration(seconds: -10));
                  },
                ),
                const SizedBox(width: 22),
                _ControlButton(
                  icon: _playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: _playing ? t('Duraklat') : t('Oynat'),
                  large: true,
                  onTap: _togglePlay,
                ),
                const SizedBox(width: 22),
                _ControlButton(
                  icon: Icons.forward_10_rounded,
                  tooltip: t('10 saniye ileri'),
                  onTap: () {
                    _seekBy(const Duration(seconds: 10));
                  },
                ),
                const SizedBox(width: 22),
                _ControlButton(
                  icon: Icons.audiotrack_rounded,
                  tooltip: t('Ses Dili'),
                  focusNode: _audioFocus,
                  onTap: () {
                    _openAudioPicker();
                  },
                ),
                const SizedBox(width: 12),
                _ControlButton(
                  icon: Icons.subtitles_rounded,
                  tooltip: t('Altyazı'),
                  focusNode: _subtitleFocus,
                  onTap: () {
                    _openSubtitlePicker();
                  },
                ),
                const SizedBox(width: 12),
                _ControlButton(
                  icon: Icons.aspect_ratio_rounded,
                  tooltip: t('Görüntü Oranı'),
                  text: _fitLabel,
                  focusNode: _fitFocus,
                  onTap: _cycleFit,
                ),
                const SizedBox(width: 12),
                _ControlButton(
                  icon: Icons.memory_rounded,
                  tooltip: t('Kod Çözücü'),
                  text: _hwDec ? 'HW' : 'SW',
                  focusNode: _codecFocus,
                  onTap: () {
                    unawaited(_toggleHwDec());
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
    this.focusNode,
    this.text,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool large;
  final FocusNode? focusNode;
  final String? text;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final double size = widget.large ? 60 : 44;
    return Tooltip(
      message: widget.tooltip,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        onShowFocusHighlight: (value) {
          if (_focused == value) return;
          setState(() {
            _focused = value;
          });
        },
        shortcuts: const <ShortcutActivator, Intent>{},
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              widget.onTap();
              return null;
            },
          ),
        },
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
                color: _active
                    ? kNeonCyanSoft
                    : Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _active ? kNeonCyan : const Color(0x33FFFFFF),
                  width: _active ? 2 : 1,
                ),
                boxShadow: _active
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: widget.text == null
                  ? Icon(
                      widget.icon,
                      size: widget.large ? 32 : 22,
                      color: _active ? kNeonCyan : Colors.white,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.text!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _active ? kNeonCyan : Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
