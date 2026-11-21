import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media_item.dart';
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
  String? _group;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _groups() {
    final values = <String>{};
    for (final item in widget.movies) {
      if (item.groupTitle.trim().isNotEmpty) {
        values.add(item.groupTitle.trim());
      }
    }
    for (final item in widget.series) {
      if (item.groupTitle.trim().isNotEmpty) {
        values.add(item.groupTitle.trim());
      }
    }
    final list = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool _matchesQuery(String name) {
    final folded = _foldText(_query.trim());
    if (folded.isEmpty) return true;
    return _foldText(name).contains(folded);
  }

  List<MediaItem> _filteredMovies() {
    return widget.movies.where((item) {
      if (_group != null && item.groupTitle.trim() != _group) return false;
      return _matchesQuery(item.name);
    }).toList();
  }

  List<SeriesItem> _filteredSeries() {
    return widget.series.where((item) {
      if (_group != null && item.groupTitle.trim() != _group) return false;
      return _matchesQuery(item.name);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(),
        _buildFilters(),
        _buildSearchField(),
        Expanded(child: _buildGrid()),
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
    final count = widget.series.isNotEmpty
        ? widget.series.length
        : widget.movies.length;
    final label = widget.series.isNotEmpty
        ? '$count dizi'
        : '$count içerik';
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

  Widget _buildFilters() {
    final groups = _groups();
    if (groups.isEmpty) {
      return const SizedBox(height: 8);
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
        itemCount: groups.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterChip(
              label: 'Tümü',
              selected: _group == null,
              onTap: () {
                setState(() {
                  _group = null;
                });
              },
            );
          }
          final group = groups[index - 1];
          return _FilterChip(
            label: group,
            selected: _group == group,
            onTap: () {
              setState(() {
                _group = group;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
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
          hintText: widget.series.isNotEmpty ? 'Dizi ara' : 'Film ara',
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

  Widget _buildGrid() {
    if (widget.series.isNotEmpty) {
      final items = _filteredSeries();
      if (items.isEmpty) {
        return const _EmptyGrid(message: 'Dizi bulunamadı.');
      }
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final entry = items[index];
          return _GridCard(
            title: entry.name,
            subtitle: '${entry.episodeCount} bölüm',
            imageUrl: entry.logo,
            icon: Icons.tv_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SeriesDetailScreen(series: entry),
                ),
              );
            },
          );
        },
      );
    }

    final items = _filteredMovies();
    if (items.isEmpty) {
      return const _EmptyGrid(message: 'Film bulunamadı.');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _GridCard(
          title: item.name,
          subtitle: item.groupTitle.isEmpty ? 'Film' : item.groupTitle,
          imageUrl: item.logo,
          icon: Icons.movie_rounded,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => VodPlayerScreen(item: item),
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

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  final FocusNode _node = FocusNode(debugLabel: 'filter-chip');
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _GridCard extends StatefulWidget {
  const _GridCard({
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
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  final FocusNode _node = FocusNode(debugLabel: 'grid-card');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  Widget _placeholder() {
    return Container(
      color: kNeonSurfaceHigh,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(widget.icon, color: const Color(0xFF4A4A5E), size: 32),
          const SizedBox(height: 8),
          Text(
            widget.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8A8A9B)),
          ),
        ],
      ),
    );
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
            scale: _active ? 1.08 : 1.0,
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
                          blurRadius: 20,
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
                    if (widget.imageUrl.isEmpty)
                      _placeholder()
                    else
                      CachedNetworkImage(
                        imageUrl: widget.imageUrl,
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
                        errorWidget: (context, value, error) => _placeholder(),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 26, 10, 10),
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
