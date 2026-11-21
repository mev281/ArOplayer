import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import 'live_player_screen.dart';
import 'multi_view_screen.dart';
import 'series_detail_screen.dart';
import 'setup_screen.dart';
import 'vod_grid_screen.dart';
import 'vod_player_screen.dart';

const List<_MenuEntry> _menuEntries = <_MenuEntry>[
  _MenuEntry('Ana sayfa', Icons.home_rounded),
  _MenuEntry('Canlı TV', Icons.live_tv_rounded),
  _MenuEntry('Çoklu Ekran', Icons.grid_view_rounded),
  _MenuEntry('Yeni Filmler', Icons.local_movies_rounded),
  _MenuEntry('Filmler', Icons.movie_rounded),
  _MenuEntry('Diziler', Icons.tv_rounded),
  _MenuEntry('Favoriler', Icons.favorite_rounded),
  _MenuEntry('Arama', Icons.search_rounded),
  _MenuEntry('Ayarlar', Icons.settings_rounded),
];

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

Widget _posterPlaceholder(String name, IconData icon) {
  return Container(
    color: kNeonSurfaceHigh,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: const Color(0xFF4A4A5E), size: 28),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8A8A9B)),
        ),
      ],
    ),
  );
}

Widget _posterImage(String url, String name, IconData icon) {
  if (url.isEmpty) {
    return _posterPlaceholder(name, icon);
  }
  return CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    placeholder: (context, value) => Container(
      color: kNeonSurfaceHigh,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    errorWidget: (context, value, error) => _posterPlaceholder(name, icon),
  );
}

class _MenuEntry {
  const _MenuEntry(this.label, this.icon);

  final String label;
  final IconData icon;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.data});

  final PlaylistData data;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _idxHome = 0;
  static const int _idxLive = 1;
  static const int _idxMulti = 2;
  static const int _idxNewMovies = 3;
  static const int _idxMovies = 4;
  static const int _idxSeries = 5;
  static const int _idxFavorites = 6;
  static const int _idxSearch = 7;
  static const int _idxSettings = 8;

  final List<FocusNode> _menuNodes = <FocusNode>[];
  final FocusNode _contentFocusNode = FocusNode(debugLabel: 'home-content');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'home-search');
  final TextEditingController _searchController = TextEditingController();

  int _section = _idxHome;
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _menuEntries.length; i++) {
      _menuNodes.add(FocusNode(debugLabel: 'home-menu-$i'));
    }
    StorageService.instance.changes.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    StorageService.instance.changes.removeListener(_onStorageChanged);
    for (final node in _menuNodes) {
      node.dispose();
    }
    _contentFocusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _focusMenu(int index) {
    if (index < 0 || index >= _menuNodes.length) return;
    _menuNodes[index].requestFocus();
  }

  void _selectMenu(int index) {
    if (index == _idxLive) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => LivePlayerScreen(data: widget.data),
        ),
      );
      return;
    }
    if (index == _idxMulti) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MultiViewScreen(channels: widget.data.live),
        ),
      );
      return;
    }
    setState(() {
      _section = index;
    });
    if (index == _idxSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _searchFocusNode.requestFocus();
      });
    }
  }

  Future<bool> _handleBack() async {
    if (_section != _idxHome) {
      setState(() {
        _section = _idxHome;
      });
      _focusMenu(_idxHome);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: kNeonBackground,
        body: SafeArea(
          child: Row(
            children: <Widget>[
              _buildSidebar(),
              Expanded(
                child: Focus(
                  focusNode: _contentFocusNode,
                  child: Container(
                    color: kNeonBackground,
                    child: _buildSection(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: kNeonSurface,
        border: Border(
          right: BorderSide(color: kNeonBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ArOplayer',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: kNeonCyan,
                    shadows: <Shadow>[
                      Shadow(color: kNeonCyanGlow, blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IPTV & Medya Oynatıcı',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: kNeonMagenta.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _menuEntries.length,
              itemBuilder: (context, index) {
                final entry = _menuEntries[index];
                return _SidebarItem(
                  label: entry.label,
                  icon: entry.icon,
                  selected: _section == index,
                  focusNode: _menuNodes[index],
                  onSelect: () {
                    _selectMenu(index);
                  },
                  onUp: () {
                    _focusMenu(index - 1);
                  },
                  onDown: () {
                    _focusMenu(index + 1);
                  },
                  onRight: () {
                    _contentFocusNode.requestFocus();
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              '${widget.data.live.length} kanal · ${widget.data.movies.length + widget.data.newMovies.length} film · ${widget.data.series.length} dizi',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6E6E80)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _idxNewMovies:
        return VodGridScreen(
          title: 'Yeni Filmler',
          movies: widget.data.newMovies,
          embedded: true,
        );
      case _idxMovies:
        return VodGridScreen(
          title: 'Filmler',
          movies: widget.data.movies,
          embedded: true,
        );
      case _idxSeries:
        return VodGridScreen(
          title: 'Diziler',
          series: widget.data.series,
          embedded: true,
        );
      case _idxFavorites:
        return _buildFavorites();
      case _idxSearch:
        return _buildSearch();
      case _idxSettings:
        return _buildSettings();
      case _idxHome:
        return _buildHome();
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    final storage = StorageService.instance;
    final continueList = storage.continueWatching();
    final favoriteChannels = storage.favorites
        .where((item) => item.type == MediaType.live)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: <Widget>[
        const Text(
          'Ana sayfa',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Kaldığın yerden devam et, favori kanallarına hızlıca geç.',
          style: TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'İzlemeye Devam Et',
          icon: Icons.play_circle_fill_rounded,
          trailing: continueList.isEmpty ? null : '${continueList.length} içerik',
        ),
        const SizedBox(height: 12),
        if (continueList.isEmpty)
          const _EmptyStrip(
            icon: Icons.play_circle_outline_rounded,
            message: 'Henüz izlemeye başladığın bir içerik yok.',
          )
        else
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: continueList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final progress = continueList[index];
                return _ContinueCard(
                  progress: progress,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => VodPlayerScreen(
                          item: progress.item,
                          startAt: Duration(seconds: progress.positionSec),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 32),
        _SectionHeader(
          title: 'Favori Kanallar',
          icon: Icons.favorite_rounded,
          trailing: favoriteChannels.isEmpty
              ? null
              : '${favoriteChannels.length} kanal',
        ),
        const SizedBox(height: 12),
        if (favoriteChannels.isEmpty)
          const _EmptyStrip(
            icon: Icons.star_border_rounded,
            message: 'Favori kanal eklemek için canlı TV panelindeki yıldızı kullan.',
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favoriteChannels.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final channel = favoriteChannels[index];
                return _ChannelCard(
                  channel: channel,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => LivePlayerScreen(
                          data: widget.data,
                          initialChannel: channel,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFavorites() {
    final favorites = StorageService.instance.favorites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 4),
          child: _SectionHeader(
            title: 'Favoriler',
            icon: Icons.favorite_rounded,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Text(
            '${favorites.length} favori içerik',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
          ),
        ),
        Expanded(
          child: favorites.isEmpty
              ? const _EmptyArea(
                  icon: Icons.favorite_border_rounded,
                  message: 'Henüz favori eklemedin.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    return _PosterCard(
                      title: item.name,
                      subtitle: item.type == MediaType.live
                          ? (item.groupTitle.isEmpty
                              ? 'Canlı kanal'
                              : item.groupTitle)
                          : 'İçerik',
                      imageUrl: item.logo,
                      icon: item.type == MediaType.live
                          ? Icons.live_tv_rounded
                          : Icons.movie_rounded,
                      onTap: () {
                        if (item.type == MediaType.live) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => LivePlayerScreen(
                                data: widget.data,
                                initialChannel: item,
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => VodPlayerScreen(item: item),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    final hits = _searchHits();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 24, 28, 4),
          child: _SectionHeader(
            title: 'Arama',
            icon: Icons.search_rounded,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Kanal, film veya dizi ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: _query.trim().isEmpty
              ? const _EmptyArea(
                  icon: Icons.search_rounded,
                  message: 'Aramak için bir şeyler yaz.',
                )
              : hits.isEmpty
                  ? const _EmptyArea(
                      icon: Icons.search_off_rounded,
                      message: 'Sonuç bulunamadı.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      itemCount: hits.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final hit = hits[index];
                        return _ResultRow(
                          title: hit.title,
                          subtitle: hit.subtitle,
                          icon: hit.icon,
                          onTap: hit.onTap,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  List<_SearchHit> _searchHits() {
    final folded = _foldText(_query.trim());
    if (folded.isEmpty) return <_SearchHit>[];
    final hits = <_SearchHit>[];
    for (final item in widget.data.live) {
      if (!_foldText(item.name).contains(folded)) continue;
      hits.add(_SearchHit(
        title: item.name,
        subtitle: item.groupTitle.isEmpty ? 'Canlı kanal' : item.groupTitle,
        icon: Icons.live_tv_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => LivePlayerScreen(
                data: widget.data,
                initialChannel: item,
              ),
            ),
          );
        },
      ));
    }
    for (final item in <MediaItem>[
      ...widget.data.newMovies,
      ...widget.data.movies,
    ]) {
      if (!_foldText(item.name).contains(folded)) continue;
      hits.add(_SearchHit(
        title: item.name,
        subtitle: item.type == MediaType.newMovie ? 'Yeni film' : 'Film',
        icon: Icons.movie_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => VodPlayerScreen(item: item),
            ),
          );
        },
      ));
    }
    for (final entry in widget.data.series) {
      if (!_foldText(entry.name).contains(folded)) continue;
      hits.add(_SearchHit(
        title: entry.name,
        subtitle: '${entry.episodeCount} bölüm',
        icon: Icons.tv_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => SeriesDetailScreen(series: entry),
            ),
          );
        },
      ));
    }
    return hits;
  }

  Widget _buildSettings() {
    final storage = StorageService.instance;
    final sourceType = storage.sourceType;
    final sourceLabel = sourceType == null
        ? 'Kaynak tanımlı değil'
        : sourceType == SourceType.xtream
            ? 'Xtream Codes'
            : 'M3U Linki';
    final pin = storage.pin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: <Widget>[
        const _SectionHeader(
          title: 'Ayarlar',
          icon: Icons.settings_rounded,
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: 'Kaynak',
          subtitle: sourceLabel,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                _changeSource();
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Kaynağı değiştir'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: 'Ebeveyn kontrolü',
          subtitle: pin == null
              ? 'PIN tanımlı değil'
              : 'PIN tanımlı (4 hane)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SwitchListTile(
                value: storage.hideAdult,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Yetişkin kategorilerini gizle',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Değiştirmek için PIN doğrulaması gerekir.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A8A9B)),
                ),
                onChanged: (value) {
                  _toggleHideAdult(value);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _changePin();
                  },
                  icon: const Icon(Icons.pin_rounded),
                  label: Text(pin == null ? 'PIN belirle' : 'PIN değiştir'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: 'Liste',
          subtitle: 'Kaynak listesini yeniden indirir.',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                _reloadPlaylist();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Listeyi yenile'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeSource() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: const Text('Kaynağı değiştir'),
        content: const Text(
          'Mevcut kaynak bilgileri silinecek ve kurulum ekranı açılacak. Devam edilsin mi?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await StorageService.instance.clearSource();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const SetupScreen()),
      (route) => false,
    );
  }

  void _reloadPlaylist() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const AppLoader()),
      (route) => false,
    );
  }

  Future<void> _toggleHideAdult(bool value) async {
    final storage = StorageService.instance;
    if (storage.pin != null) {
      final verified = await _verifyPinDialog('PIN doğrulama');
      if (!verified || !mounted) return;
    }
    await storage.setHideAdult(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Yetişkin kategorileri gizlendi.'
              : 'Yetişkin kategorileri gösteriliyor.',
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    final storage = StorageService.instance;
    if (storage.pin != null) {
      final verified = await _verifyPinDialog('Mevcut PIN');
      if (!verified || !mounted) return;
    }
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: const Text('PIN değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Yeni 4 haneli PIN gir. Alanı boş bırakırsan ebeveyn kilidi kaldırılır.',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Yeni PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    if (value.isNotEmpty && value.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 4 haneli olmalıdır.')),
      );
      return;
    }
    await storage.setPin(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value.isEmpty ? 'PIN kaldırıldı.' : 'PIN güncellendi.'),
      ),
    );
  }

  Future<bool> _verifyPinDialog(String title) async {
    final storage = StorageService.instance;
    if (storage.pin == null) return true;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            labelText: 'PIN',
            counterText: '',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(storage.verifyPin(controller.text));
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? false;
  }
}

class _SearchHit {
  const _SearchHit({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.focusNode,
    required this.onSelect,
    required this.onUp,
    required this.onDown,
    required this.onRight,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRight;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      widget.onUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onRight();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground = widget.selected
        ? kNeonCyan
        : (_active ? Colors.white : const Color(0xFFB9B9C9));
    return Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _handleKey, child: FocusableActionDetector(
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
            widget.onSelect();
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
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? kNeonCyanSoft
                  : (_active ? kNeonSurfaceHigh : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _active
                    ? kNeonCyan
                    : (widget.selected ? kNeonCyanSoft : Colors.transparent),
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
            child: Row(
              children: <Widget>[
                Icon(widget.icon, size: 20, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                if (widget.selected)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kNeonCyan,
                      borderRadius: BorderRadius.circular(2),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: kNeonCyan),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A9B)),
          ),
      ],
    );
  }
}

class _EmptyStrip extends StatelessWidget {
  const _EmptyStrip({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kNeonSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeonBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 20, color: const Color(0xFF6E6E80)),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
          ),
        ],
      ),
    );
  }
}

class _EmptyArea extends StatelessWidget {
  const _EmptyArea({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: const Color(0xFF4A4A5E)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A9B)),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatefulWidget {
  const _ContinueCard({required this.progress, required this.onTap});

  final WatchProgress progress;
  final VoidCallback onTap;

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  final FocusNode _node = FocusNode(debugLabel: 'continue-card');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.progress.item;
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
          child: AnimatedScale(
            scale: _active ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 240,
              decoration: BoxDecoration(
                color: kNeonSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _active ? kNeonCyan : kNeonBorder,
                  width: _active ? 2 : 1,
                ),
                boxShadow: _active
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    child: SizedBox(
                      height: 120,
                      child: _posterImage(
                        item.logo,
                        item.name,
                        Icons.movie_rounded,
                      ),
                    ),
                  ),
                  LinearProgressIndicator(
                    value: widget.progress.fraction,
                    minHeight: 4,
                    backgroundColor: kNeonSurfaceHigh,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kNeonCyan),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatSeconds(widget.progress.positionSec)} / ${_formatSeconds(widget.progress.durationSec)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                      ],
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

String _formatSeconds(int total) {
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

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({required this.channel, required this.onTap});

  final MediaItem channel;
  final VoidCallback onTap;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  final FocusNode _node = FocusNode(debugLabel: 'channel-card');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedScale(
            scale: _active ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 170,
              decoration: BoxDecoration(
                color: kNeonSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _active ? kNeonCyan : kNeonBorder,
                  width: _active ? 2 : 1,
                ),
                boxShadow: _active
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    child: SizedBox(
                      height: 100,
                      child: _posterImage(
                        widget.channel.logo,
                        widget.channel.name,
                        Icons.live_tv_rounded,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.channel.groupTitle.isEmpty
                              ? 'Canlı kanal'
                              : widget.channel.groupTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                      ],
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

class _PosterCard extends StatefulWidget {
  const _PosterCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  final FocusNode _node = FocusNode(debugLabel: 'poster-card');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: AnimatedScale(
            scale: _active ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: kNeonSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _active ? kNeonCyan : kNeonBorder,
                  width: _active ? 2 : 1,
                ),
                boxShadow: _active
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _posterImage(widget.imageUrl, widget.title, widget.icon),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Color(0x00000000),
                              Color(0xE6000000),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFB9B9C9),
                              ),
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
    );
  }
}

class _ResultRow extends StatefulWidget {
  const _ResultRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends State<_ResultRow> {
  final FocusNode _node = FocusNode(debugLabel: 'result-row');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _active ? kNeonSurfaceHigh : kNeonSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _active ? kNeonCyan : kNeonBorder,
                width: _active ? 2 : 1,
              ),
              boxShadow: _active
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: kNeonCyanGlow,
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.icon,
                  size: 20,
                  color: _active ? kNeonCyan : const Color(0xFF9A9AAB),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8A8A9B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF6E6E80),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kNeonSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeonBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A9B)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
