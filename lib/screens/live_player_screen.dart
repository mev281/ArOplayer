import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';

const String _kAllCountries = 'Tümü';
const String _kAllChannels = 'Tüm Kanallar';
const String _kOtherCountry = 'Diğer';
const double _kMenuWidth = 360;
const double _kRowMinHeight = 56;

const Map<String, String> _kTrFold = <String, String>{
  'İ': 'i',
  'I': 'i',
  'ı': 'i',
  'Ş': 's',
  'ş': 's',
  'Ğ': 'g',
  'ğ': 'g',
  'Ü': 'u',
  'ü': 'u',
  'Ö': 'o',
  'ö': 'o',
  'Ç': 'c',
  'ç': 'c',
  'Â': 'a',
  'â': 'a',
  'Î': 'i',
  'î': 'i',
  'Û': 'u',
  'û': 'u',
};

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
  final FocusNode _playerFocus = FocusNode(debugLabel: 'live-player');
  final FocusNode _prevFocus = FocusNode(debugLabel: 'live-prev');
  final FocusNode _nextFocus = FocusNode(debugLabel: 'live-next');
  final TextEditingController _searchController = TextEditingController();
  final Map<String, FocusNode> _rowNodes = <String, FocusNode>{};

  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;
  Timer? _barTimer;
  Timer? _clockTimer;

  MediaItem? _current;
  bool _fullscreen = false;
  bool _barOpen = false;
  bool _buffering = false;
  bool _failed = false;
  String _clockText = '';

  int _level = 1;
  String _country = _kAllCountries;
  bool _favoritesOnly = false;
  String _searchQuery = '';
  String? _selectedKey;

  List<String> _countryList = <String>[];
  final Map<String, List<MediaItem>> _byCountry = <String, List<MediaItem>>{};
  List<String> _subList = <String>[];
  final Map<String, int> _subCounts = <String, int>{};
  List<MediaItem> _channelList = <MediaItem>[];
  List<MediaItem> _favoriteChannels = <MediaItem>[];
  List<MediaItem> _searchResults = <MediaItem>[];
  List<MediaItem> _activeList = <MediaItem>[];

  List<MediaItem> get _channels => widget.data.live;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    _controller = VideoController(_player);
    _bufferingSub = _player.stream.buffering.listen(_onBuffering);
    _errorSub = _player.stream.error.listen(_onPlayerError);
    _buildIndex();
    _refreshSubs();
    _refreshFavorites();
    _clockText = _formatClock(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), _tickClock);
    final channels = _channels;
    if (channels.isNotEmpty) {
      final initial = widget.initialChannel ?? channels.first;
      _current = initial;
      _player.open(Media(initial.url, httpHeaders: initial.httpHeaders));
    }
    StorageService.instance.changes.addListener(_onStorageChanged);
    _focusFirstRow();
  }

  @override
  void dispose() {
    StorageService.instance.changes.removeListener(_onStorageChanged);
    _barTimer?.cancel();
    _clockTimer?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _searchController.dispose();
    _rootFocus.dispose();
    _playerFocus.dispose();
    _prevFocus.dispose();
    _nextFocus.dispose();
    for (final node in _rowNodes.values) {
      node.dispose();
    }
    _rowNodes.clear();
    _player.dispose();
    super.dispose();
  }

  void _onBuffering(bool value) {
    if (!mounted || _buffering == value) return;
    setState(() {
      _buffering = value;
    });
  }

  void _onPlayerError(String value) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _buffering = false;
    });
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {
      _refreshFavorites();
    });
  }

  void _tickClock(Timer timer) {
    if (!mounted) return;
    final next = _formatClock(DateTime.now());
    if (next == _clockText) return;
    setState(() {
      _clockText = next;
    });
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _normalize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_kTrFold[char] ?? char);
    }
    return buffer.toString().toLowerCase();
  }

  String _countryOf(MediaItem item) {
    final value = item.country.trim();
    return value.isEmpty ? _kOtherCountry : value;
  }

  String _subOf(MediaItem item) {
    final value = item.subCategory.trim();
    return value.isEmpty ? 'Genel' : value;
  }

  void _buildIndex() {
    _byCountry.clear();
    for (final item in _channels) {
      _byCountry.putIfAbsent(_countryOf(item), () => <MediaItem>[]).add(item);
    }
    const preferred = <String>[
      'Türkiye',
      'Almanya',
      'İngiltere',
      'ABD',
      'Fransa',
      'Hollanda',
    ];
    final list = <String>[_kAllCountries];
    for (final name in preferred) {
      if (_byCountry.containsKey(name)) list.add(name);
    }
    final others = _byCountry.keys
        .where((name) => name != _kOtherCountry && !preferred.contains(name))
        .toList()
      ..sort((a, b) {
        final diff = _byCountry[b]!.length.compareTo(_byCountry[a]!.length);
        if (diff != 0) return diff;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    list.addAll(others);
    if (_byCountry.containsKey(_kOtherCountry)) list.add(_kOtherCountry);
    _countryList = list;
  }

  List<MediaItem> _itemsOfCountry(String country) {
    if (country == _kAllCountries) return _channels;
    return _byCountry[country] ?? const <MediaItem>[];
  }

  int _countryCount(String country) => _itemsOfCountry(country).length;

  void _refreshSubs() {
    _subCounts.clear();
    for (final item in _itemsOfCountry(_country)) {
      final sub = _subOf(item);
      _subCounts[sub] = (_subCounts[sub] ?? 0) + 1;
    }
    _subList = _subCounts.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void _refreshFavorites() {
    final list = <MediaItem>[];
    for (final item in StorageService.instance.favorites) {
      if (item.type == MediaType.live) list.add(item);
    }
    _favoriteChannels = list;
  }

  FocusNode _nodeFor(String key) {
    return _rowNodes.putIfAbsent(key, () => FocusNode(debugLabel: key));
  }

  String? _firstRowKey() {
    if (_searchQuery.isNotEmpty) {
      if (_searchResults.isEmpty) return null;
      return 'search-${_searchResults.first.id}';
    }
    if (_favoritesOnly) {
      if (_favoriteChannels.isEmpty) return null;
      return 'fav-${_favoriteChannels.first.id}';
    }
    if (_level == 1) return 'country-$_kAllCountries';
    if (_level == 2) return 'sub-$_country-$_kAllChannels';
    if (_channelList.isEmpty) return null;
    return 'ch-${_channelList.first.id}';
  }

  void _focusFirstRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final preferred = _selectedKey;
      if (preferred != null) {
        final node = _rowNodes[preferred];
        if (node != null && node.context != null) {
          node.requestFocus();
          return;
        }
      }
      final key = _firstRowKey();
      final node = key == null ? null : _rowNodes[key];
      if (node != null && node.context != null) {
        node.requestFocus();
        return;
      }
      _rootFocus.requestFocus();
    });
  }

  void _focusPlayer() {
    _playerFocus.requestFocus();
  }

  void _playChannel(MediaItem item) {
    setState(() {
      _current = item;
      _failed = false;
    });
    _player.open(Media(item.url, httpHeaders: item.httpHeaders));
  }

  void _onChannelTap(MediaItem item) {
    final current = _current;
    if (current != null && current.id == item.id) {
      _enterFullscreen();
      return;
    }
    _playChannel(item);
  }

  void _stepChannel(int delta) {
    final list = _activeList.isNotEmpty ? _activeList : _channels;
    if (list.isEmpty) return;
    final current = _current;
    var index = current == null
        ? -1
        : list.indexWhere((item) => item.id == current.id);
    if (index < 0) index = 0;
    var next = index + delta;
    if (next < 0) next = list.length - 1;
    if (next >= list.length) next = 0;
    _playChannel(list[next]);
    _openBar();
  }

  void _enterFullscreen() {
    if (_fullscreen) return;
    _barTimer?.cancel();
    setState(() {
      _fullscreen = true;
      _barOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootFocus.requestFocus();
    });
  }

  void _exitFullscreen() {
    if (!_fullscreen) return;
    _barTimer?.cancel();
    setState(() {
      _fullscreen = false;
      _barOpen = false;
    });
    _focusFirstRow();
  }

  void _openBar() {
    _barTimer?.cancel();
    if (!_barOpen) {
      setState(() {
        _barOpen = true;
      });
    }
    _barTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _barOpen = false;
      });
    });
  }

  void _closeBar() {
    _barTimer?.cancel();
    if (!_barOpen) return;
    setState(() {
      _barOpen = false;
    });
  }

  void _toggleBar() {
    if (_barOpen) {
      _closeBar();
    } else {
      _openBar();
    }
  }

  bool _handleBack() {
    if (_fullscreen) {
      if (_barOpen) {
        _closeBar();
        return true;
      }
      _exitFullscreen();
      return true;
    }
    return false;
  }

  Future<bool> _handleWillPop() async {
    return !_handleBack();
  }

  void _selectCountry(String country) {
    setState(() {
      _country = country;
      _favoritesOnly = false;
      _refreshSubs();
      _level = 2;
    });
    _focusFirstRow();
  }

  void _selectSub(String sub) {
    final items = _itemsOfCountry(_country);
    final list = sub == _kAllChannels
        ? items
        : items.where((item) => _subOf(item) == sub).toList();
    setState(() {
      _channelList = list;
      _activeList = list;
      _level = 3;
    });
    _focusFirstRow();
  }

  void _openFavorites() {
    setState(() {
      _favoritesOnly = true;
      _activeList = _favoriteChannels;
    });
    _focusFirstRow();
  }

  void _goBackLevel() {
    if (_searchQuery.isNotEmpty) {
      _clearSearch();
      return;
    }
    if (_favoritesOnly) {
      setState(() {
        _favoritesOnly = false;
      });
      _focusFirstRow();
      return;
    }
    if (_level == 3) {
      setState(() {
        _level = 2;
      });
      _focusFirstRow();
      return;
    }
    if (_level == 2) {
      setState(() {
        _level = 1;
      });
      _focusFirstRow();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = <MediaItem>[];
    });
    _focusFirstRow();
  }

  void _onSearchChanged(String value) {
    final query = _normalize(value.trim());
    final results = <MediaItem>[];
    if (query.isNotEmpty) {
      for (final item in _channels) {
        if (_normalize(item.name).contains(query)) {
          results.add(item);
          if (results.length >= 200) break;
        }
      }
    }
    setState(() {
      _searchQuery = value.trim();
      _searchResults = results;
      if (results.isNotEmpty) _activeList = results;
    });
  }

  KeyEventResult _handleRootKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      if (_handleBack()) return KeyEventResult.handled;
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (!_fullscreen) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.pageUp) {
      _stepChannel(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown) {
      _stepChannel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _toggleBar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handlePlayerKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _enterFullscreen();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_channels.isEmpty) {
      return Scaffold(
        backgroundColor: kNeonBackground,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.live_tv_rounded,
                  size: 48,
                  color: Color(0xFF4A5A75),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kanal bulunamadı.',
                  style: TextStyle(fontSize: 15, color: Color(0xFFB9C6D8)),
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
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: kNeonBackground,
        body: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _handleRootKey,
          child: _fullscreen ? _buildFullscreen() : _buildNormal(),
        ),
      ),
    );
  }

  Widget _buildNormal() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = math.min(_kMenuWidth, constraints.maxWidth * 0.5);
        return Row(
          children: <Widget>[
            SizedBox(
              width: menuWidth,
              child: _buildMenu(),
            ),
            Expanded(
              child: _buildPlayerArea(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFullscreen() {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: _buildVideoSurface(radius: BorderRadius.zero),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleBar,
            onDoubleTap: _exitFullscreen,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildInfoBar(),
        ),
      ],
    );
  }

  Widget _buildPlayerArea() {
    return Container(
      color: kNeonBackground,
      padding: const EdgeInsets.all(18),
      child: Focus(
        focusNode: _playerFocus,
        onKeyEvent: _handlePlayerKey,
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _buildVideoSurface(radius: BorderRadius.circular(16)),
                Positioned(
                  left: 14,
                  top: 14,
                  child: _buildOsd(),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _enterFullscreen,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSurface({required BorderRadius radius}) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Video(
              controller: _controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),
            if (_buffering)
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kNeonCyan,
                  ),
                ),
              ),
            if (_failed)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kNeonMagenta.withOpacity(0.7)),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 30,
                        color: kNeonMagenta,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Yayın açılamadı',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOsd() {
    final item = _current;
    if (item == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNeonBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kNeonMagenta,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
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
    );
  }

  Widget _buildInfoBar() {
    final item = _current;
    if (item == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !_barOpen,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _barOpen ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: _barOpen ? 1 : 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: kNeonSurface.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kNeonBorder),
                  ),
                  child: Row(
                    children: <Widget>[
                      _ChannelLogo(channel: item, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              item.name,
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
                              '${_subOf(item)} · ${_countryOf(item)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9FB0C9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _BarButton(
                        node: _prevFocus,
                        label: 'Önceki kanal',
                        icon: Icons.chevron_left_rounded,
                        onTap: () {
                          _stepChannel(-1);
                        },
                      ),
                      const SizedBox(width: 8),
                      _BarButton(
                        node: _nextFocus,
                        label: 'Sonraki',
                        icon: Icons.chevron_right_rounded,
                        onTap: () {
                          _stepChannel(1);
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _clockText,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StarButton(
                                active: StorageService.instance
                                    .isFavorite(item),
                                size: 24,
                                onTap: () {
                                  StorageService.instance
                                      .toggleFavorite(item);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: kNeonSurface.withOpacity(0.78),
            border: const Border(
              right: BorderSide(color: kNeonBorder),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildMenuHeader(),
                _buildSearchField(),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: _buildMenuBody(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 4),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('Geri'),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Canlı TV',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        cursorColor: kNeonCyan,
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Kanal ara…',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A9AB5),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF8A9AB5),
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF8A9AB5),
                ),
          isDense: true,
          filled: true,
          fillColor: kNeonSurfaceHigh,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
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
        ),
      ),
    );
  }

  Widget _buildMenuBody() {
    if (_searchQuery.isNotEmpty) {
      return _buildChannelList(_searchResults, 'search');
    }
    if (_favoritesOnly) {
      return _buildChannelList(_favoriteChannels, 'fav');
    }
    if (_level == 1) return _buildCountries();
    if (_level == 2) return _buildSubs();
    return _buildChannelList(_channelList, 'ch');
  }

  Widget _buildCountries() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _countryList.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MenuRow(
            node: _nodeFor('favorites'),
            title: 'Favoriler',
            subtitle: '${_favoriteChannels.length} kanal',
            leading: const Icon(
              Icons.star_rounded,
              size: 20,
              color: kNeonMagenta,
            ),
            trailing: _CountBadge(count: _favoriteChannels.length),
            chevron: true,
            onTap: _openFavorites,
            onLeft: _goBackLevel,
            onRight: _focusPlayer,
            onFocus: () {
              _selectedKey = 'favorites';
            },
          );
        }
        if (index == 1) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Text(
              'Tüm Ülkeler',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Color(0xFF8A9AB5),
              ),
            ),
          );
        }
        final name = _countryList[index - 2];
        return _MenuRow(
          node: _nodeFor('country-$name'),
          title: name,
          subtitle: '${_countryCount(name)} kanal',
          leading: const Icon(
            Icons.public_rounded,
            size: 18,
            color: Color(0xFF8A9AB5),
          ),
          chevron: true,
          onTap: () {
            _selectCountry(name);
          },
          onLeft: _goBackLevel,
          onRight: _focusPlayer,
          onFocus: () {
            _selectedKey = 'country-$name';
          },
        );
      },
    );
  }

  Widget _buildSubs() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _subList.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _MenuRow(
            node: _nodeFor('subs-back'),
            title: '‹ Ülkeler',
            onTap: _goBackLevel,
            onLeft: _goBackLevel,
            onRight: _focusPlayer,
            onFocus: () {
              _selectedKey = 'subs-back';
            },
          );
        }
        if (index == 1) {
          return _MenuRow(
            node: _nodeFor('sub-$_country-$_kAllChannels'),
            title: _kAllChannels,
            subtitle: '${_itemsOfCountry(_country).length} kanal',
            leading: const Icon(
              Icons.apps_rounded,
              size: 18,
              color: Color(0xFF8A9AB5),
            ),
            chevron: true,
            onTap: () {
              _selectSub(_kAllChannels);
            },
            onLeft: _goBackLevel,
            onRight: _focusPlayer,
            onFocus: () {
              _selectedKey = 'sub-$_country-$_kAllChannels';
            },
          );
        }
        final sub = _subList[index - 2];
        return _MenuRow(
          node: _nodeFor('sub-$_country-$sub'),
          title: sub,
          subtitle: '${_subCounts[sub] ?? 0} kanal',
          leading: const Icon(
            Icons.category_rounded,
            size: 18,
            color: Color(0xFF8A9AB5),
          ),
          chevron: true,
          onTap: () {
            _selectSub(sub);
          },
          onLeft: _goBackLevel,
          onRight: _focusPlayer,
          onFocus: () {
            _selectedKey = 'sub-$_country-$sub';
          },
        );
      },
    );
  }

  Widget _buildChannelList(List<MediaItem> items, String prefix) {
    if (items.isEmpty) {
      return const _MenuEmpty(message: 'Kanal bulunamadı.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final channel = items[index];
        final current = _current;
        final playing = current != null && current.id == channel.id;
        final key = '$prefix-${channel.id}';
        return _MenuRow(
          node: _nodeFor(key),
          title: channel.name,
          subtitle: '${_subOf(channel)} · ${_countryOf(channel)}',
          leading: _ChannelLogo(channel: channel),
          playing: playing,
          trailing: _StarButton(
            active: StorageService.instance.isFavorite(channel),
            onTap: () {
              StorageService.instance.toggleFavorite(channel);
            },
          ),
          onTap: () {
            _onChannelTap(channel);
          },
          onLeft: _goBackLevel,
          onRight: _focusPlayer,
          onFocus: () {
            _selectedKey = key;
          },
        );
      },
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.node,
    required this.title,
    required this.onTap,
    required this.onLeft,
    required this.onRight,
    this.subtitle,
    this.leading,
    this.trailing,
    this.playing = false,
    this.chevron = false,
    this.onFocus,
  });

  final FocusNode node;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool playing;
  final bool chevron;
  final VoidCallback onTap;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback? onFocus;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.node.focusInDirection(TraversalDirection.up);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.node.focusInDirection(TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color titleColor = widget.playing
        ? kNeonCyan
        : (_active ? Colors.white : const Color(0xFFE2E8F0));
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: FocusableActionDetector(
        focusNode: widget.node,
        onShowFocusHighlight: (value) {
          if (_focused != value) {
            setState(() {
              _focused = value;
            });
          }
          if (value) {
            widget.onFocus?.call();
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 160),
            );
          }
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
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: const BoxConstraints(minHeight: _kRowMinHeight),
              decoration: BoxDecoration(
                color: _active
                    ? kNeonCyanSoft
                    : (widget.playing
                        ? kNeonCyanSoft.withOpacity(0.5)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _active
                      ? kNeonCyan
                      : (widget.playing
                          ? kNeonCyan.withOpacity(0.6)
                          : Colors.transparent),
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
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: widget.playing
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            if (widget.playing) ...<Widget>[
                              const SizedBox(width: 8),
                              const _NowBadge(),
                            ],
                          ],
                        ),
                        if (widget.subtitle != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Row(
                            children: <Widget>[
                              if (widget.playing) ...<Widget>[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: kNeonMagenta,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'CANLI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: kNeonMagenta,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8A9AB5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...<Widget>[
                    const SizedBox(width: 6),
                    widget.trailing!,
                  ],
                  if (widget.chevron) ...<Widget>[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF8A9AB5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.node,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final FocusNode node;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: FocusableActionDetector(
        focusNode: widget.node,
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
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _active ? kNeonCyanSoft : kNeonSurfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _active ? kNeonCyan : kNeonBorder,
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
                  Icon(
                    widget.icon,
                    size: 18,
                    color: _active ? kNeonCyan : const Color(0xFFB8C4D9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _active ? Colors.white : const Color(0xFFD5DCE8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.active,
    required this.onTap,
    this.size = 22,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          active ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: active ? kNeonMagenta : const Color(0xFF8A9AB5),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.channel, this.size = 40});

  final MediaItem channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kNeonSurfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.live_tv_rounded,
        size: size * 0.45,
        color: const Color(0xFF7A8AA5),
      ),
    );
    if (channel.logo.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: channel.logo,
          fit: BoxFit.cover,
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );
  }
}

class _NowBadge extends StatelessWidget {
  const _NowBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kNeonCyanSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kNeonCyan.withOpacity(0.7)),
      ),
      child: const Text(
        'şu an',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kNeonCyan,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kNeonMagentaSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNeonMagenta.withOpacity(0.6)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kNeonMagenta,
        ),
      ),
    );
  }
}

class _MenuEmpty extends StatelessWidget {
  const _MenuEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8A9AB5)),
        ),
      ),
    );
  }
}
