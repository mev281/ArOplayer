import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';

class LivePlayerScreen extends StatefulWidget {
  const LivePlayerScreen({
    super.key,
    required this.data,
    this.initialChannel,
  });

  final PlaylistData data;
  final MediaItem? initialChannel;

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final FocusNode _rootFocus = FocusNode(debugLabel: 'live-root');

  MediaItem? _current;
  bool _panelOpen = false;
  int _level = 1;
  String? _country;
  String? _subCategory;
  bool _osdVisible = false;
  Timer? _osdTimer;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    final channels = widget.data.live;
    if (channels.isNotEmpty) {
      final initial = widget.initialChannel ?? channels.first;
      _current = initial;
      _player.open(Media(initial.url));
    }
    StorageService.instance.changes.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    StorageService.instance.changes.removeListener(_onStorageChanged);
    _osdTimer?.cancel();
    _rootFocus.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<MediaItem> get _channels => widget.data.live;

  String _countryOf(MediaItem item) {
    return item.country.trim().isEmpty ? 'Diğer' : item.country.trim();
  }

  String _subOf(MediaItem item) {
    return item.subCategory.trim().isEmpty ? 'Genel' : item.subCategory.trim();
  }

  List<String> _countries() {
    final values = <String>{};
    for (final item in _channels) {
      values.add(_countryOf(item));
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int _countryCount(String country) {
    var count = 0;
    for (final item in _channels) {
      if (_countryOf(item) == country) count++;
    }
    return count;
  }

  List<String> _subCategories(String country) {
    final values = <String>{};
    for (final item in _channels) {
      if (_countryOf(item) != country) continue;
      values.add(_subOf(item));
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  int _subCount(String country, String sub) {
    var count = 0;
    for (final item in _channels) {
      if (_countryOf(item) != country) continue;
      if (_subOf(item) != sub) continue;
      count++;
    }
    return count;
  }

  List<MediaItem> _channelsFor(String country, String sub) {
    return _channels
        .where((item) => _countryOf(item) == country && _subOf(item) == sub)
        .toList();
  }

  void _playChannel(MediaItem item) {
    setState(() {
      _current = item;
    });
    _player.open(Media(item.url));
    _showOsd();
  }

  void _showOsd() {
    _osdTimer?.cancel();
    setState(() {
      _osdVisible = true;
    });
    _osdTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _osdVisible = false;
      });
    });
  }

  void _stepChannel(int delta) {
    final channels = _channels;
    final current = _current;
    if (channels.isEmpty || current == null) return;
    final index = channels.indexWhere((item) => item.id == current.id);
    if (index < 0) return;
    var next = index + delta;
    if (next < 0) next = channels.length - 1;
    if (next >= channels.length) next = 0;
    _playChannel(channels[next]);
  }

  void _openPanel() {
    if (_panelOpen) return;
    setState(() {
      _panelOpen = true;
      _level = 1;
      _country = null;
      _subCategory = null;
    });
  }

  void _closePanel() {
    if (!_panelOpen) return;
    setState(() {
      _panelOpen = false;
    });
    _rootFocus.requestFocus();
  }

  void _togglePanel() {
    if (_panelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  void _panelBack() {
    if (!_panelOpen) return;
    if (_level == 3) {
      setState(() {
        _level = 2;
        _subCategory = null;
      });
      return;
    }
    if (_level == 2) {
      setState(() {
        _level = 1;
        _country = null;
      });
      return;
    }
    _closePanel();
  }

  Future<bool> _handleBack() async {
    if (_panelOpen) {
      _panelBack();
      return false;
    }
    return true;
  }

  KeyEventResult _handleRootKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!_panelOpen) {
        _openPanel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_panelOpen) {
        _panelBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_panelOpen) return KeyEventResult.ignored;
      _stepChannel(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_panelOpen) return KeyEventResult.ignored;
      _stepChannel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_panelOpen) {
        _panelBack();
        return KeyEventResult.handled;
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_channels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.live_tv_rounded,
                  size: 48,
                  color: Color(0xFF4A4A5E),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kanal bulunamadı.',
                  style: TextStyle(fontSize: 14, color: Color(0xFFB9B9C9)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Geri'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _handleRootKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth =
                  math.min(constraints.maxWidth * 0.38, 460.0);
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePanel,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 20,
                    child: SafeArea(
                      child: _buildOsd(),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    width: panelWidth,
                    right: _panelOpen ? 0 : -panelWidth,
                    child: ExcludeFocus(
                      excluding: !_panelOpen,
                      child: _buildPanel(panelWidth),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOsd() {
    final item = _current;
    if (item == null) return const SizedBox.shrink();
    final index = _channels.indexWhere((channel) => channel.id == item.id);
    return AnimatedOpacity(
      opacity: _osdVisible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNeonCyan.withOpacity(0.55)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: kNeonCyanGlow,
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              index >= 0 ? '${index + 1}' : '-',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kNeonCyan,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: const Border(
          left: BorderSide(color: kNeonBorder),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _panelBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Geri'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _panelTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: _buildLevel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _panelTitle() {
    if (_level == 1) return 'Ülkeler';
    if (_level == 2) return _country ?? 'Kategoriler';
    final country = _country ?? '';
    final sub = _subCategory ?? '';
    return '$country · $sub';
  }

  Widget _buildLevel() {
    if (_level == 1) {
      final countries = _countries();
      if (countries.isEmpty) {
        return const _PanelEmpty(message: 'Ülke bulunamadı.');
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final country = countries[index];
          return _PanelRow(
            key: ValueKey<String>('country-$country'),
            title: country,
            subtitle: '${_countryCount(country)} kanal',
            leading: const Icon(
              Icons.public_rounded,
              size: 18,
              color: Color(0xFF9A9AAB),
            ),
            autofocus: _panelOpen && index == 0,
            onTap: () {
              setState(() {
                _country = country;
                _level = 2;
              });
            },
            onBack: _panelBack,
          );
        },
      );
    }

    if (_level == 2) {
      final country = _country;
      if (country == null) {
        return const _PanelEmpty(message: 'Ülke seçilmedi.');
      }
      final subs = _subCategories(country);
      if (subs.isEmpty) {
        return const _PanelEmpty(message: 'Kategori bulunamadı.');
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: subs.length,
        itemBuilder: (context, index) {
          final sub = subs[index];
          return _PanelRow(
            key: ValueKey<String>('sub-$country-$sub'),
            title: sub,
            subtitle: '${_subCount(country, sub)} kanal',
            leading: const Icon(
              Icons.category_rounded,
              size: 18,
              color: Color(0xFF9A9AAB),
            ),
            autofocus: _panelOpen && index == 0,
            onTap: () {
              setState(() {
                _subCategory = sub;
                _level = 3;
              });
            },
            onBack: _panelBack,
          );
        },
      );
    }

    final country = _country;
    final sub = _subCategory;
    if (country == null || sub == null) {
      return const _PanelEmpty(message: 'Kategori seçilmedi.');
    }
    final channels = _channelsFor(country, sub);
    if (channels.isEmpty) {
      return const _PanelEmpty(message: 'Kanal bulunamadı.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        final playing = _current != null && _current!.id == channel.id;
        final favorite = StorageService.instance.isFavorite(channel);
        return _PanelRow(
          key: ValueKey<String>('channel-${channel.id}'),
          title: channel.name,
          subtitle: channel.groupTitle.isEmpty
              ? _subOf(channel)
              : channel.groupTitle,
          selected: playing,
          leading: _buildChannelLogo(channel),
          autofocus: _panelOpen && index == 0,
          trailing: GestureDetector(
            onTap: () {
              StorageService.instance.toggleFavorite(channel);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                favorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 20,
                color: favorite ? kNeonMagenta : const Color(0xFF8A8A9B),
              ),
            ),
          ),
          onTap: () {
            _playChannel(channel);
          },
          onBack: _panelBack,
        );
      },
    );
  }

  Widget _buildChannelLogo(MediaItem channel) {
    if (channel.logo.isEmpty) {
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kNeonSurfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.live_tv_rounded,
          size: 16,
          color: Color(0xFF6E6E80),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 34,
        height: 34,
        child: CachedNetworkImage(
          imageUrl: channel.logo,
          fit: BoxFit.cover,
          placeholder: (context, value) => Container(
            color: kNeonSurfaceHigh,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, value, error) => Container(
            color: kNeonSurfaceHigh,
            alignment: Alignment.center,
            child: const Icon(
              Icons.live_tv_rounded,
              size: 16,
              color: Color(0xFF6E6E80),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelRow extends StatefulWidget {
  const _PanelRow({
    super.key,
    required this.title,
    required this.onTap,
    required this.onBack,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onBack;

  @override
  State<_PanelRow> createState() => _PanelRowState();
}

class _PanelRowState extends State<_PanelRow> {
  final FocusNode _node = FocusNode(debugLabel: 'panel-row');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _node.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PanelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autofocus && widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color titleColor = widget.selected
        ? kNeonCyan
        : (_active ? Colors.white : const Color(0xFFD5D5E0));
    return FocusableActionDetector(
      focusNode: _node,
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
      onKeyEvent: _handleKey,
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
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: widget.selected
                  ? kNeonCyanSoft
                  : (_active ? kNeonSurfaceHigh : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _active
                    ? kNeonCyan
                    : (widget.selected ? kNeonCyan : Colors.transparent),
                width: _active ? 2 : 1,
              ),
              boxShadow: _active
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: kNeonCyanGlow,
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              children: <Widget>[
                if (widget.leading != null) ...<Widget>[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      if (widget.subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...<Widget>[
                  const SizedBox(width: 6),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
        ),
      ),
    );
  }
}
