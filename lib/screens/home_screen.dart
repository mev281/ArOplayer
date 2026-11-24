import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/epg_service.dart';
import '../services/library_prefs.dart';
import '../services/l10n.dart';
import '../services/m3u_parser.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../widgets/settings_extras.dart';
import '../widgets/update_dialog.dart';
import 'live_player_screen.dart';
import 'multi_view_screen.dart';
import 'series_detail_screen.dart';
import 'setup_screen.dart';
import 'vod_grid_screen.dart';
import 'vod_player_screen.dart';

List<_MenuEntry> _menuEntries() {
  return <_MenuEntry>[
    _MenuEntry(t('Ana sayfa'), Icons.home_rounded),
    _MenuEntry(t('Canlı TV'), Icons.live_tv_rounded),
    _MenuEntry(t('Çoklu Ekran'), Icons.grid_view_rounded),
    _MenuEntry(t('Yeni Filmler'), Icons.local_movies_rounded),
    _MenuEntry(t('Filmler'), Icons.movie_rounded),
    _MenuEntry(t('Diziler'), Icons.tv_rounded),
    _MenuEntry(t('Favoriler'), Icons.favorite_rounded),
    _MenuEntry(t('Arama'), Icons.search_rounded),
    _MenuEntry(t('Ayarlar'), Icons.settings_rounded),
  ];
}

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
  String _version = '';

  static bool _updateChecked = false;
  static bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    final entries = _menuEntries();
    for (var i = 0; i < entries.length; i++) {
      _menuNodes.add(FocusNode(debugLabel: 'home-menu-$i'));
    }
    StorageService.instance.changes.addListener(_onStorageChanged);
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupTasks();
    });
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

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.version;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _startupTasks() async {
    await _checkUpdatesSilently();
    if (!mounted) return;
    await _maybeAutoPlayLast();
  }

  Future<void> _checkUpdatesSilently() async {
    if (_updateChecked) return;
    _updateChecked = true;
    final info = await UpdateService.check();
    if (info == null || !mounted) return;
    await showUpdateDialog(context, info);
  }

  Future<void> _checkUpdates() async {
    final info = await UpdateService.check();
    if (!mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Uygulama güncel'))),
      );
      return;
    }
    await showUpdateDialog(context, info);
  }

  Future<void> _maybeAutoPlayLast() async {
    if (_autoPlayed) return;
    _autoPlayed = true;
    final storage = StorageService.instance;
    if (!storage.autoPlayLast) return;
    final id = storage.lastChannelId;
    if (id == null) return;
    MediaItem? found;
    for (final item in widget.data.live) {
      if (item.id == id) {
        found = item;
        break;
      }
    }
    final channel = found;
    if (channel == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LivePlayerScreen(
          data: widget.data,
          initialChannel: channel,
        ),
      ),
    );
  }

  Future<void> _setLanguage(String code) async {
    await StorageService.instance.setLanguage(code);
    L10n.language.value = code;
  }

  Future<void> _toggleAutoPlayLast(bool value) async {
    await StorageService.instance.setAutoPlayLast(value);
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
    final media = MediaQuery.of(context);
    final scale = (media.size.height / 720).clamp(0.72, 1.0).toDouble();
    return WillPopScope(
      onWillPop: _handleBack,
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(scale)),
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
      ),
    );
  }

  Widget _buildSidebar() {
    final entries = _menuEntries();
    return Container(
      width: MediaQuery.of(context).size.width < 900 ? 200 : 240,
      decoration: const BoxDecoration(
        color: kNeonSurface,
        border: Border(
          right: BorderSide(color: kNeonBorder),
        ),
      ),
      child: SingleChildScrollView(
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
                  t('IPTV & Medya Oynatıcı'),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: <Widget>[
                for (var index = 0; index < entries.length; index++)
                  _SidebarItem(
                    label: entries[index].label,
                    icon: entries[index].icon,
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
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              '${t('{n} kanal').replaceAll('{n}', '${widget.data.live.length}')} · '
              '${t('{n} film').replaceAll('{n}', '${widget.data.movies.length + widget.data.newMovies.length}')} · '
              '${t('{n} dizi').replaceAll('{n}', '${widget.data.series.length}')}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF6E6E80)),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case _idxNewMovies:
        return VodGridScreen(
          title: t('Yeni Filmler'),
          movies: widget.data.newMovies,
          embedded: true,
        );
      case _idxMovies:
        return VodGridScreen(
          title: t('Filmler'),
          movies: widget.data.movies,
          embedded: true,
        );
      case _idxSeries:
        return VodGridScreen(
          title: t('Diziler'),
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
        Text(
          t('Ana sayfa'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('Kaldığın yerden devam et, favori kanallarına hızlıca geç.'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: t('İzlemeye Devam Et'),
          icon: Icons.play_circle_fill_rounded,
          trailing: continueList.isEmpty
              ? null
              : t('{n} içerik')
                  .replaceAll('{n}', '${continueList.length}'),
        ),
        const SizedBox(height: 12),
        if (continueList.isEmpty)
          _EmptyStrip(
            icon: Icons.play_circle_outline_rounded,
            message: t('Henüz izlemeye başladığın bir içerik yok.'),
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
          title: t('Favori Kanallar'),
          icon: Icons.favorite_rounded,
          trailing: favoriteChannels.isEmpty
              ? null
              : t('{n} kanal').replaceAll('{n}', '${favoriteChannels.length}'),
        ),
        const SizedBox(height: 12),
        if (favoriteChannels.isEmpty)
          _EmptyStrip(
            icon: Icons.star_border_rounded,
            message: t(
              'Favori kanal eklemek için canlı TV panelindeki yıldızı kullan.',
            ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 4),
          child: _SectionHeader(
            title: t('Favoriler'),
            icon: Icons.favorite_rounded,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Text(
            t('{n} favori içerik').replaceAll('{n}', '${favorites.length}'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A9B)),
          ),
        ),
        Expanded(
          child: favorites.isEmpty
              ? _EmptyArea(
                  icon: Icons.favorite_border_rounded,
                  message: t('Henüz favori eklemedin.'),
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
                              ? t('Canlı kanal')
                              : item.groupTitle)
                          : t('İçerik'),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 4),
          child: _SectionHeader(
            title: t('Arama'),
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
              hintText: t('Kanal, film veya dizi ara'),
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
              ? _EmptyArea(
                  icon: Icons.search_rounded,
                  message: t('Aramak için bir şeyler yaz.'),
                )
              : hits.isEmpty
                  ? _EmptyArea(
                      icon: Icons.search_off_rounded,
                      message: t('Sonuç bulunamadı.'),
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
        subtitle: item.groupTitle.isEmpty ? t('Canlı kanal') : item.groupTitle,
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
        subtitle: item.type == MediaType.newMovie ? t('Yeni film') : t('Film'),
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
        subtitle: t('{n} bölüm').replaceAll('{n}', '${entry.episodeCount}'),
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
        ? t('Kaynak tanımlı değil')
        : sourceType == SourceType.xtream
            ? 'Xtream Codes'
            : t('M3U Linki');
    final pin = storage.pin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: <Widget>[
        _SectionHeader(
          title: t('Ayarlar'),
          icon: Icons.settings_rounded,
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: t('Kaynak'),
          subtitle: sourceLabel,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                _changeSource();
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(t('Kaynağı değiştir')),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Ebeveyn kontrolü'),
          subtitle: pin == null
              ? t('PIN tanımlı değil')
              : t('PIN tanımlı (4 hane)'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SwitchListTile(
                value: storage.hideAdult,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t('Yetişkin kategorilerini gizle'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  t('Değiştirmek için PIN doğrulaması gerekir.'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8A9B),
                  ),
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
                  label: Text(
                    pin == null ? t('PIN belirle') : t('PIN değiştir'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Liste'),
          subtitle: t('Kaynak listesini yeniden indirir.'),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                _reloadPlaylist();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('Listeyi yenile')),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Listelerim'),
          subtitle: t('M3U ve EPG listelerini adlandırıp kaydedin, tek tıkla geçin.'),
          child: const ListManagerBody(),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Kategori gizleme ve kilit'),
          subtitle: t('İstenmeyen kategorileri gizleyin veya PIN ile kilitleyin.'),
          child: CategoryManagerBody(categories: _liveCategories()),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: 'EPG',
          subtitle: t('Boş bırakılırsa M3U içindeki url-tvg adresi kullanılır.'),
          child: const _EpgUrlField(),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Dil'),
          subtitle: t('Arayüz dilini seçin.'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final entry in L10n.languageNames.entries)
                if (L10n.language.value == entry.key)
                  FilledButton(
                    onPressed: () {
                      _setLanguage(entry.key);
                    },
                    child: Text(entry.value),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      _setLanguage(entry.key);
                    },
                    child: Text(entry.value),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Oynatma'),
          subtitle: t('Açılış davranışı'),
          child: SwitchListTile(
            value: storage.autoPlayLast,
            contentPadding: EdgeInsets.zero,
            title: Text(
              t('Açılışta son izlenen kanalı otomatik oynat'),
              style: const TextStyle(color: Colors.white),
            ),
            onChanged: (value) {
              _toggleAutoPlayLast(value);
            },
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: t('Güncelleme'),
          subtitle: _version.isEmpty
              ? t('Sürüm bilgisi alınamadı')
              : '${t('Sürüm')}: v$_version',
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                _checkUpdates();
              },
              icon: const Icon(Icons.system_update_rounded),
              label: Text(t('Güncellemeleri Denetle')),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _liveCategories() {
    final seen = <String>{};
    final list = <String>[];
    for (final item in widget.data.live) {
      final value = item.subCategory.trim().isEmpty
          ? 'Genel'
          : item.subCategory.trim();
      if (seen.add(value)) list.add(value);
    }
    return list;
  }

  Future<void> _changeSource() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: Text(t('Kaynağı değiştir')),
        content: Text(
          t(
            'Kayıtlı M3U adresi, kanal listesi önbelleği, favoriler, son izlenenler ve izleme geçmişi tamamen silinecek ve kurulum ekranı açılacak. Devam edilsin mi?',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: Text(t('İptal')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(t('Devam et')),
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
      final verified = await _verifyPinDialog(t('PIN doğrulama'));
      if (!verified || !mounted) return;
    }
    await storage.setHideAdult(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? t('Yetişkin kategorileri gizlendi.')
              : t('Yetişkin kategorileri gösteriliyor.'),
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    final storage = StorageService.instance;
    if (storage.pin != null) {
      final verified = await _verifyPinDialog(t('Mevcut PIN'));
      if (!verified || !mounted) return;
    }
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: Text(t('PIN değiştir')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              t(
                'Yeni 4 haneli PIN gir. Alanı boş bırakırsan ebeveyn kilidi kaldırılır.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8A9B),
              ),
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
              decoration: InputDecoration(
                labelText: t('Yeni PIN'),
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
            child: Text(t('İptal')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(controller.text.trim());
            },
            child: Text(t('Kaydet')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    if (value.isNotEmpty && value.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('PIN 4 haneli olmalıdır.'))),
      );
      return;
    }
    await storage.setPin(value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value.isEmpty ? t('PIN kaldırıldı.') : t('PIN güncellendi.'),
        ),
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
          decoration: InputDecoration(
            labelText: t('PIN'),
            counterText: '',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: Text(t('İptal')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(storage.verifyPin(controller.text));
            },
            child: Text(t('Onayla')),
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
                              ? t('Canlı kanal')
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

class _EpgUrlField extends StatefulWidget {
  const _EpgUrlField();

  @override
  State<_EpgUrlField> createState() => _EpgUrlFieldState();
}

class _EpgUrlFieldState extends State<_EpgUrlField> {
  late final TextEditingController _controller =
      TextEditingController(text: StorageService.instance.epgUrl);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await StorageService.instance.setEpgUrl(_controller.text);
    unawaited(EpgService.instance.reload(M3uService.lastEpgUrls));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('EPG adresi kaydedildi.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'https://.../epg.xml',
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: _save,
          child: Text(t('Kaydet')),
        ),
      ],
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
