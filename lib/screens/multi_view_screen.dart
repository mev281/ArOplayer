import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models/media_item.dart';

String _foldText(String input) {
  var text = input.replaceAll('\u0130', 'i').replaceAll('I', 'i');
  text = text.replaceAll('\u0131', 'i');
  text = text.toLowerCase();
  text = text.replaceAll('\u015F', 's');
  text = text.replaceAll('\u011F', 'g');
  text = text.replaceAll('\u00FC', 'u');
  text = text.replaceAll('\u00F6', 'o');
  text = text.replaceAll('\u00E7', 'c');
  return text;
}

class MultiViewScreen extends StatefulWidget {
  const MultiViewScreen({super.key, required this.channels});

  final List<MediaItem> channels;

  @override
  State<MultiViewScreen> createState() => _MultiViewScreenState();
}

class _MultiViewScreenState extends State<MultiViewScreen> {
  final FocusNode _rootFocus = FocusNode(debugLabel: 'multi-root');
  final List<MediaItem?> _slots = <MediaItem?>[null, null, null, null];
  final List<Player?> _players = <Player?>[null, null, null, null];
  final List<VideoController?> _controllers = <VideoController?>[
    null,
    null,
    null,
    null,
  ];

  int _layout = 2;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _syncPlayers();
  }

  @override
  void dispose() {
    for (var i = 0; i < 4; i++) {
      final player = _players[i];
      _controllers[i] = null;
      _players[i] = null;
      player?.dispose();
    }
    _rootFocus.dispose();
    super.dispose();
  }

  void _syncPlayers() {
    for (var i = 0; i < 4; i++) {
      final needed = i < _layout;
      if (needed && _players[i] == null) {
        final player = Player();
        _players[i] = player;
        _controllers[i] = VideoController(player);
      } else if (!needed && _players[i] != null) {
        final player = _players[i];
        _controllers[i] = null;
        _players[i] = null;
        _slots[i] = null;
        player?.dispose();
      }
    }
    _applyVolumes();
  }

  void _applyVolumes() {
    for (var i = 0; i < _layout; i++) {
      final player = _players[i];
      if (player == null) continue;
      player.setVolume(i == _active ? 100 : 0);
    }
  }

  void _setLayout(int layout) {
    if (_layout == layout) return;
    setState(() {
      _layout = layout;
      if (_active >= layout) {
        _active = 0;
      }
      _syncPlayers();
    });
  }

  void _selectCell(int index) {
    if (index < 0 || index >= _layout) return;
    if (_active == index) return;
    setState(() {
      _active = index;
    });
    _applyVolumes();
  }

  void _moveActive(int dx, int dy) {
    if (_layout == 2) {
      if (dx == 0) return;
      final next = _active + dx;
      if (next < 0 || next >= 2) return;
      _selectCell(next);
      return;
    }
    final row = _active ~/ 2;
    final col = _active % 2;
    var nextRow = row + dy;
    var nextCol = col + dx;
    if (nextRow < 0 || nextRow > 1) nextRow = row;
    if (nextCol < 0 || nextCol > 1) nextCol = col;
    final next = nextRow * 2 + nextCol;
    if (next == _active) return;
    _selectCell(next);
  }

  Future<void> _openPicker(int index) async {
    final channels = widget.channels;
    if (channels.isEmpty) return;
    final selected = await showModalBottomSheet<MediaItem>(
      context: context,
      backgroundColor: kNeonSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ChannelPickerSheet(channels: channels),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _slots[index] = selected;
    });
    final player = _players[index];
    if (player != null) {
      player.open(Media(selected.url, httpHeaders: selected.httpHeaders));
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (FocusManager.instance.primaryFocus != _rootFocus) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveActive(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveActive(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveActive(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveActive(0, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _openPicker(_active);
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        backgroundColor: kNeonBackground,
        body: SafeArea(
          child: Focus(
            focusNode: _rootFocus,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildTopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildCells(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: kNeonSurface,
        border: Border(
          bottom: BorderSide(color: kNeonBorder),
        ),
      ),
      child: Row(
        children: <Widget>[
          _TopButton(
            icon: Icons.arrow_back_rounded,
            label: 'Geri',
            onTap: () {
              Navigator.of(context).maybePop();
            },
            onArrowDown: () {
              _rootFocus.requestFocus();
            },
          ),
          const SizedBox(width: 14),
          const Text(
            'Çoklu Ekran',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${widget.channels.length} kanal',
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A9B)),
          ),
          const Spacer(),
          _TopButton(
            icon: Icons.view_agenda_rounded,
            label: '2\'li',
            selected: _layout == 2,
            onTap: () {
              _setLayout(2);
            },
            onArrowDown: () {
              _rootFocus.requestFocus();
            },
          ),
          const SizedBox(width: 8),
          _TopButton(
            icon: Icons.grid_view_rounded,
            label: '4\'lü',
            selected: _layout == 4,
            onTap: () {
              _setLayout(4);
            },
            onArrowDown: () {
              _rootFocus.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCells() {
    if (_layout == 2) {
      return Row(
        children: <Widget>[
          Expanded(child: _buildCell(0)),
          const SizedBox(width: 10),
          Expanded(child: _buildCell(1)),
        ],
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _buildCell(0)),
              const SizedBox(width: 10),
              Expanded(child: _buildCell(1)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _buildCell(2)),
              const SizedBox(width: 10),
              Expanded(child: _buildCell(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCell(int index) {
    final controller = _controllers[index];
    final channel = _slots[index];
    final active = _active == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _selectCell(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? kNeonCyan : kNeonBorder,
            width: active ? 3 : 1,
          ),
          boxShadow: active
              ? const <BoxShadow>[
                  BoxShadow(
                    color: kNeonCyanGlow,
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (controller != null)
                Video(
                  controller: controller,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                )
              else
                Container(color: Colors.black),
              if (channel == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 34,
                        color: active ? kNeonCyan : const Color(0xFF4A4A5E),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kanal seçmek için OK',
                        style: TextStyle(
                          fontSize: 12,
                          color: active
                              ? Colors.white
                              : const Color(0xFF8A8A9B),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? kNeonCyan : kNeonBorder,
                    ),
                  ),
                  child: Text(
                    channel == null ? 'Hücre ${index + 1}' : channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active ? kNeonCyan : Colors.white,
                    ),
                  ),
                ),
              ),
              if (active)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kNeonCyanSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kNeonCyan),
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      size: 16,
                      color: kNeonCyan,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatefulWidget {
  const _TopButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.onArrowDown,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final VoidCallback? onArrowDown;

  @override
  State<_TopButton> createState() => _TopButtonState();
}

class _TopButtonState extends State<_TopButton> {
  final FocusNode _node = FocusNode(debugLabel: 'multi-top-button');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final callback = widget.onArrowDown;
      if (callback != null) {
        callback();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground = widget.selected
        ? kNeonCyan
        : (_active ? Colors.white : const Color(0xFFB9B9C9));
    return Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _handleKey, child: FocusableActionDetector(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected ? kNeonCyanSoft : kNeonSurfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _active
                    ? kNeonCyan
                    : (widget.selected ? kNeonCyan : kNeonBorder),
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
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(widget.icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class _ChannelPickerSheet extends StatefulWidget {
  const _ChannelPickerSheet({required this.channels});

  final List<MediaItem> channels;

  @override
  State<_ChannelPickerSheet> createState() => _ChannelPickerSheetState();
}

class _ChannelPickerSheetState extends State<_ChannelPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MediaItem> _filtered() {
    final folded = _foldText(_query.trim());
    if (folded.isEmpty) return widget.channels;
    return widget.channels
        .where((item) => _foldText(item.name).contains(folded))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: <Widget>[
                const Text(
                  'Kanal seç',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Kanal ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Kanal bulunamadı.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8A9B),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final channel = items[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.live_tv_rounded,
                          size: 20,
                          color: kNeonCyan.withOpacity(0.8),
                        ),
                        title: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          channel.groupTitle.isEmpty
                              ? channel.subCategory
                              : channel.groupTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(channel);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
