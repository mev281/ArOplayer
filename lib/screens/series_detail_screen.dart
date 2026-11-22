import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';
import '../widgets/poster_card.dart';
import 'vod_player_screen.dart';

class _PlayTarget {
  const _PlayTarget({
    required this.item,
    required this.playlist,
    required this.startSec,
  });

  final MediaItem item;
  final List<MediaItem> playlist;
  final int startSec;
}

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final SeriesItem series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late int _season;

  @override
  void initState() {
    super.initState();
    final keys = widget.series.seasons.keys.toList()..sort();
    _season = keys.isEmpty ? 1 : keys.first;
    StorageService.instance.changes.addListener(_onStorageChanged);
  }

  @override
  void dispose() {
    StorageService.instance.changes.removeListener(_onStorageChanged);
    super.dispose();
  }

  void _onStorageChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<int> get _seasonKeys {
    final keys = widget.series.seasons.keys.toList()..sort();
    return keys;
  }

  List<MediaItem> get _episodes {
    final list = widget.series.seasons[_season];
    if (list == null) return <MediaItem>[];
    return list;
  }

  double _fractionFor(String id) {
    for (final entry in StorageService.instance.continueWatching()) {
      if (entry.item.id == id) return entry.fraction;
    }
    return 0;
  }

  _PlayTarget? _playTarget() {
    for (final key in _seasonKeys) {
      final list = widget.series.seasons[key];
      if (list == null) continue;
      for (final episode in list) {
        final saved = StorageService.instance.progressFor(episode.id);
        if (saved != null) {
          return _PlayTarget(
            item: episode,
            playlist: list,
            startSec: saved,
          );
        }
      }
    }
    for (final key in _seasonKeys) {
      final list = widget.series.seasons[key];
      if (list == null || list.isEmpty) continue;
      return _PlayTarget(item: list.first, playlist: list, startSec: 0);
    }
    return null;
  }

  void _openTarget(_PlayTarget target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => VodPlayerScreen(
          item: target.item,
          startAt: Duration(seconds: target.startSec),
          playlist: target.playlist,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNeonBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHero(),
            _buildSeasonBar(),
            Expanded(child: _buildEpisodes()),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final target = _playTarget();
    return SizedBox(
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildHeroBackdrop(),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    kNeonBackground.withOpacity(0.96),
                    kNeonBackground.withOpacity(0.72),
                    kNeonBackground.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    kNeonBackground,
                    kNeonBackground.withOpacity(0.35),
                    Colors.transparent,
                  ],
                  stops: const <double>[0, 0.45, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 28,
            child: _BackButton(
              onTap: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _buildHeroPoster(),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.series.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_seasonKeys.length} Sezon · ${widget.series.episodeCount} Bölüm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB9B9C9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.series.groupTitle.isEmpty
                            ? 'Dizi'
                            : widget.series.groupTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A8A9B),
                        ),
                      ),
                      if (target != null) ...<Widget>[
                        const SizedBox(height: 16),
                        _PlayButton(
                          label: target.startSec > 0 ? 'Devam Et' : 'İzle',
                          onTap: () {
                            _openTarget(target);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBackdrop() {
    final logo = widget.series.logo;
    if (logo.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: kNeonSurface),
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
            tileMode: TileMode.clamp,
          ),
          child: CachedNetworkImage(
            imageUrl: logo,
            fit: BoxFit.cover,
            placeholder: (context, value) => Container(color: kNeonSurface),
            errorWidget: (context, value, error) =>
                Container(color: kNeonSurface),
          ),
        ),
        Container(color: Colors.black.withOpacity(0.35)),
      ],
    );
  }

  Widget _buildHeroPoster() {
    return SizedBox(
      width: 140,
      height: 210,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kNeonCyan.withOpacity(0.45), width: 1),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: _buildPosterImage(),
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    final logo = widget.series.logo;
    if (logo.isEmpty) {
      return PosterFallback(
        title: widget.series.name,
        icon: Icons.tv_rounded,
      );
    }
    return CachedNetworkImage(
      imageUrl: logo,
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
      errorWidget: (context, value, error) => PosterFallback(
        title: widget.series.name,
        icon: Icons.tv_rounded,
      ),
    );
  }

  Widget _buildSeasonBar() {
    final keys = _seasonKeys;
    if (keys.isEmpty) {
      return const SizedBox(height: 8);
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
        itemCount: keys.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final seasonNo = keys[index];
          return _SeasonChip(
            label: 'Sezon $seasonNo',
            selected: _season == seasonNo,
            onTap: () {
              setState(() {
                _season = seasonNo;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEpisodes() {
    final episodes = _episodes;
    if (episodes.isEmpty) {
      return const Center(
        child: Text(
          'Bu sezonda bölüm bulunamadı.',
          style: TextStyle(fontSize: 13, color: Color(0xFF8A8A9B)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      itemCount: episodes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final saved = StorageService.instance.progressFor(episode.id);
        return _EpisodeRow(
          episode: episode,
          number: episode.episode ?? index + 1,
          savedSeconds: saved,
          fraction: saved == null ? 0 : _fractionFor(episode.id),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => VodPlayerScreen(
                  item: episode,
                  startAt: Duration(seconds: saved ?? 0),
                  playlist: episodes,
                ),
              ),
            );
          },
        );
      },
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
  final FocusNode _node = FocusNode(debugLabel: 'series-back');
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

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  final FocusNode _node = FocusNode(debugLabel: 'series-play');
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
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: BoxDecoration(
              color: kNeonMagenta,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _active ? Colors.white : kNeonMagenta,
                width: _active ? 2.5 : 1,
              ),
              boxShadow: _active
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: kNeonMagentaGlow,
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeasonChip extends StatefulWidget {
  const _SeasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SeasonChip> createState() => _SeasonChipState();
}

class _SeasonChipState extends State<_SeasonChip> {
  final FocusNode _node = FocusNode(debugLabel: 'season-chip');
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
    final Color foreground = widget.selected
        ? kNeonCyan
        : (_active ? Colors.white : const Color(0xFFB9B9C9));
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
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected ? kNeonCyanSoft : kNeonSurface,
              borderRadius: BorderRadius.circular(20),
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
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    widget.selected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({
    required this.episode,
    required this.number,
    required this.savedSeconds,
    required this.fraction,
    required this.onTap,
  });

  final MediaItem episode;
  final int number;
  final int? savedSeconds;
  final double fraction;
  final VoidCallback onTap;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  final FocusNode _node = FocusNode(debugLabel: 'episode-row');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  String _code() {
    return 'E${widget.number.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    final saved = widget.savedSeconds;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                SizedBox(
                  width: 54,
                  child: Text(
                    _code(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _active ? kNeonCyan : const Color(0xFFB9B9C9),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.episode.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (saved != null) ...<Widget>[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: widget.fraction,
                            minHeight: 4,
                            backgroundColor: kNeonSurfaceHigh,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              kNeonCyan,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kaldığın yer: ${_formatSeconds(saved)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8A9B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _active ? kNeonCyanSoft : kNeonSurfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _active ? kNeonCyan : kNeonBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 22,
                    color: _active ? kNeonCyan : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
