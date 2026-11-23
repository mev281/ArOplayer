import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/l10n.dart';
import '../services/storage_service.dart';
import '../widgets/poster_card.dart';
import 'series_detail_screen.dart';
import 'vod_player_screen.dart';

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

class _VodEntry {
  const _VodEntry({
    required this.title,
    required this.logo,
    required this.group,
    this.movie,
    this.series,
    this.badge,
  });

  final String title;
  final String logo;
  final String group;
  final MediaItem? movie;
  final SeriesItem? series;
  final String? badge;
}

class _VodRow {
  const _VodRow({required this.title, required this.entries});

  final String title;
  final List<_VodEntry> entries;
}

class _EpisodeRef {
  const _EpisodeRef({
    required this.series,
    required this.season,
    required this.episode,
  });

  final SeriesItem series;
  final int season;
  final MediaItem episode;
}

void _openEntry(BuildContext context, _VodEntry entry) {
  final series = entry.series;
  if (series != null) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SeriesDetailScreen(series: series),
      ),
    );
    return;
  }
  final movie = entry.movie;
  if (movie == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => VodPlayerScreen(item: movie),
    ),
  );
}

class VodGridScreen extends StatefulWidget {
  const VodGridScreen({
    super.key,
    required this.title,
    this.movies = const <MediaItem>[],
    this.series = const <SeriesItem>[],
    this.embedded = false,
  });

  final String title;
  final List<MediaItem> movies;
  final List<SeriesItem> series;
  final bool embedded;

  @override
  State<VodGridScreen> createState() => _VodGridScreenState();
}

class _VodGridScreenState extends State<VodGridScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();
    StorageService.instance.changes.addListener(_onStorageChanged);
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    StorageService.instance.changes.removeListener(_onStorageChanged);
    _searchController.dispose();
    super.dispose();
  }

  Map<String, _EpisodeRef> _episodeIndex() {
    final index = <String, _EpisodeRef>{};
    for (final series in widget.series) {
      for (final entry in series.seasons.entries) {
        for (final episode in entry.value) {
          index[episode.id] = _EpisodeRef(
            series: series,
            season: entry.key,
            episode: episode,
          );
        }
      }
    }
    return index;
  }

  List<WatchProgress> _continueEntries() {
    final movieIds = <String>{};
    for (final movie in widget.movies) {
      movieIds.add(movie.id);
    }
    final episodes = _episodeIndex();
    final result = <WatchProgress>[];
    for (final progress in StorageService.instance.continueWatching()) {
      final id = progress.item.id;
      if (!movieIds.contains(id) && !episodes.containsKey(id)) continue;
      result.add(progress);
      if (result.length >= 20) break;
    }
    return result;
  }

  void _openContinue(WatchProgress progress) {
    final startAt = Duration(seconds: progress.positionSec);
    for (final movie in widget.movies) {
      if (movie.id != progress.item.id) continue;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => VodPlayerScreen(
            item: movie,
            startAt: startAt,
          ),
        ),
      );
      return;
    }
    final ref = _episodeIndex()[progress.item.id];
    if (ref == null) return;
    final playlist = ref.series.seasons[ref.season] ?? const <MediaItem>[];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => VodPlayerScreen(
          item: ref.episode,
          startAt: startAt,
          playlist: playlist,
        ),
      ),
    );
  }

  List<_VodEntry> _entries() {
    final list = <_VodEntry>[];
    for (final item in widget.movies) {
      final group = item.groupTitle.trim();
      list.add(_VodEntry(
        title: item.name,
        logo: item.logo,
        group: group.isEmpty ? t('Diğer') : group,
        movie: item,
      ));
    }
    for (final entry in widget.series) {
      final group = entry.groupTitle.trim();
      list.add(_VodEntry(
        title: entry.name,
        logo: entry.logo,
        group: group.isEmpty ? t('Diğer') : group,
        series: entry,
        badge: t('{n} bölüm').replaceAll('{n}', '${entry.episodeCount}'),
      ));
    }
    return list;
  }

  List<_VodEntry> _filtered() {
    final all = _entries();
    final folded = _foldText(_query.trim());
    if (folded.isEmpty) return all;
    return all
        .where((entry) => _foldText(entry.title).contains(folded))
        .toList();
  }

  List<_VodRow> _rows(List<_VodEntry> entries) {
    final rows = <_VodRow>[];
    if (entries.isEmpty) return rows;
    final newest = entries.length > 20 ? entries.sublist(0, 20) : entries;
    rows.add(_VodRow(title: t('Yeni Eklenenler'), entries: newest));
    final buckets = <String, List<_VodEntry>>{};
    for (final entry in entries) {
      buckets.putIfAbsent(entry.group, () => <_VodEntry>[]).add(entry);
    }
    final groups = buckets.keys.toList()
      ..sort((a, b) {
        final diff = buckets[b]!.length.compareTo(buckets[a]!.length);
        if (diff != 0) return diff;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
    for (final group in groups) {
      rows.add(_VodRow(title: group, entries: buckets[group]!));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(),
        _buildSearchField(),
        if (_query.trim().isEmpty) _buildContinueRow(),
        Expanded(child: _buildBody()),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: kNeonBackground,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader() {
    final count = _entries().length;
    final label = widget.series.isNotEmpty && widget.movies.isEmpty
        ? t('{n} dizi').replaceAll('{n}', '$count')
        : t('{n} içerik').replaceAll('{n}', '$count');
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Row(
        children: <Widget>[
          if (!widget.embedded) ...<Widget>[
            _BackButton(
              onTap: () {
                Navigator.of(context).maybePop();
              },
            ),
            const SizedBox(width: 14),
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
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8A9B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final String hint;
    if (widget.series.isNotEmpty && widget.movies.isEmpty) {
      hint = t('Dizi ara');
    } else if (widget.movies.isNotEmpty && widget.series.isEmpty) {
      hint = t('Film ara');
    } else {
      hint = t('Film veya dizi ara');
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _query = value;
          });
        },
        decoration: InputDecoration(
          hintText: hint,
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
    );
  }

  Widget _buildContinueRow() {
    final entries = _continueEntries();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
          child: Text(
            t('İzlemeye Devam Et'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 225 * 1.1 + 20,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final progress = entries[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 150,
                    height: 225,
                    child: PosterCard(
                      title: progress.item.name,
                      imageUrl: progress.item.logo,
                      progress: progress.fraction,
                      onTap: () {
                        _openContinue(progress);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final entries = _filtered();
    if (entries.isEmpty) {
      final String message;
      if (_query.trim().isNotEmpty) {
        message = t('Aramanızla eşleşen içerik bulunamadı.');
      } else if (widget.series.isNotEmpty) {
        message = t('Dizi bulunamadı.');
      } else {
        message = t('Film bulunamadı.');
      }
      return _EmptyGrid(message: message);
    }
    if (_query.trim().isNotEmpty) {
      return _buildSearchGrid(entries);
    }
    return _buildRows(entries);
  }

  Widget _buildSearchGrid(List<_VodEntry> entries) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return PosterCard(
            title: entry.title,
            imageUrl: entry.logo,
            badge: entry.badge,
            onTap: () {
              _openEntry(context, entry);
            },
          );
        },
      ),
    );
  }

  Widget _buildRows(List<_VodEntry> entries) {
    final rows = _rows(entries);
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return _CategoryRow(
            row: row,
            onOpenAll: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => _CategoryGridPage(
                    title: row.title,
                    entries: row.entries,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.row, required this.onOpenAll});

  final _VodRow row;
  final VoidCallback onOpenAll;

  static const double _cardWidth = 150;
  static const double _cardHeight = 225;

  @override
  Widget build(BuildContext context) {
    final total = row.entries.length;
    final visible = total > 60 ? row.entries.sublist(0, 60) : row.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t('{n} içerik').replaceAll('{n}', '$total'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A8A9B),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _cardHeight * 1.1 + 20,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            itemCount: visible.length + 1,
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: _cardWidth,
                      height: _cardHeight,
                      child: _SeeAllCard(
                        label: t('Tümünü gör ({n})')
                            .replaceAll('{n}', '$total'),
                        onTap: onOpenAll,
                      ),
                    ),
                  ),
                );
              }
              final entry = visible[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: _cardWidth,
                    height: _cardHeight,
                    child: PosterCard(
                      title: entry.title,
                      imageUrl: entry.logo,
                      badge: entry.badge,
                      onTap: () {
                        _openEntry(context, entry);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeeAllCard extends StatefulWidget {
  const _SeeAllCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SeeAllCard> createState() => _SeeAllCardState();
}

class _SeeAllCardState extends State<_SeeAllCard> {
  final FocusNode _node = FocusNode(debugLabel: 'see-all-card');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _revealCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
        if (value) {
          _revealCard();
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
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _active ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _active ? kNeonSurfaceHigh : kNeonSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _active ? kNeonCyan : kNeonBorder,
                  width: _active ? 2.5 : 1,
                ),
                boxShadow: _active
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: kNeonCyanGlow,
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.grid_view_rounded,
                    size: 26,
                    color: _active ? kNeonCyan : const Color(0xFF8A8A9B),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _active ? Colors.white : const Color(0xFFB9B9C9),
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

class _CategoryGridPage extends StatelessWidget {
  const _CategoryGridPage({required this.title, required this.entries});

  final String title;
  final List<_VodEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNeonBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
              child: Row(
                children: <Widget>[
                  _BackButton(
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
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('{n} içerik')
                              .replaceAll('{n}', '${entries.length}'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 2 / 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return PosterCard(
                      title: entry.title,
                      imageUrl: entry.logo,
                      badge: entry.badge,
                      onTap: () {
                        _openEntry(context, entry);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  final FocusNode _node = FocusNode(debugLabel: 'grid-back');
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _active ? kNeonCyanSoft : kNeonSurface,
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
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: _active ? kNeonCyan : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyGrid extends StatelessWidget {
  const _EmptyGrid({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.movie_filter_rounded,
            size: 44,
            color: Color(0xFF4A4A5E),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A9B)),
          ),
        ],
      ),
    );
  }
}
