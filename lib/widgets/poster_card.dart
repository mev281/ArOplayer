import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.badge,
    this.progress,
  });

  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final String? badge;
  final double? progress;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  final FocusNode _node = FocusNode(debugLabel: 'poster-card');
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

  Widget _buildImage() {
    if (widget.imageUrl.isEmpty) {
      return PosterFallback(title: widget.title);
    }
    return CachedNetworkImage(
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
      errorWidget: (context, value, error) => PosterFallback(
        title: widget.title,
      ),
    );
  }

  Widget _buildBadge() {
    final badge = widget.badge;
    if (badge == null || badge.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: kNeonMagenta,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final progress = widget.progress;
    if (progress == null || progress <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0).toDouble(),
          minHeight: 4,
          backgroundColor: kNeonSurfaceHigh,
          valueColor: const AlwaysStoppedAnimation<Color>(kNeonMagenta),
        ),
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
            scale: _active ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: kNeonSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _active ? kNeonCyan : Colors.transparent,
                    width: 2.5,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _buildImage(),
                      _buildBadge(),
                      AnimatedOpacity(
                        opacity: _active ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0x00000000),
                                  Color(0xF2000000),
                                ],
                              ),
                            ),
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildProgress(),
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
}

class PosterFallback extends StatelessWidget {
  const PosterFallback({
    super.key,
    required this.title,
    this.icon = Icons.movie_rounded,
  });

  final String title;
  final IconData icon;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF101B3B), Color(0xFF1E3A8A)],
    <Color>[Color(0xFF1B1035), Color(0xFF4C1D95)],
    <Color>[Color(0xFF0B1B2B), Color(0xFF1D4ED8)],
    <Color>[Color(0xFF1A1030), Color(0xFF312E81)],
    <Color>[Color(0xFF0F172A), Color(0xFF1E40AF)],
    <Color>[Color(0xFF22103A), Color(0xFF5B21B6)],
  ];

  int _hashOf(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[_hashOf(title) % _palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        border: Border.all(color: kNeonCyan.withOpacity(0.45), width: 1),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, size: 18, color: kNeonCyan.withOpacity(0.85)),
        ],
      ),
    );
  }
}
