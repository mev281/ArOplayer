import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../main.dart';
import '../services/l10n.dart';

class _TrackChoice {
  const _TrackChoice({this.audio, this.subtitle, this.addUrl = false});

  final AudioTrack? audio;
  final SubtitleTrack? subtitle;
  final bool addUrl;
}

class _TrackOption {
  const _TrackOption({
    required this.label,
    required this.selected,
    required this.choice,
    this.icon,
  });

  final String label;
  final bool selected;
  final _TrackChoice choice;
  final IconData? icon;
}

String _audioLabel(AudioTrack track, int index) {
  final title = (track.title ?? '').trim();
  final language = (track.language ?? '').trim();
  final id = track.id.trim();
  final base = title.isNotEmpty
      ? title
      : (language.isNotEmpty
          ? t('Ses {n}').replaceAll('{n}', '$index')
          : (id.isNotEmpty ? id : t('Ses {n}').replaceAll('{n}', '$index')));
  if (language.isNotEmpty && language != base) {
    return '$base – $language';
  }
  return base;
}

String _subtitleLabel(SubtitleTrack track, int index) {
  final title = (track.title ?? '').trim();
  final language = (track.language ?? '').trim();
  final id = track.id.trim();
  final base = title.isNotEmpty
      ? title
      : (language.isNotEmpty
          ? t('Altyazı {n}').replaceAll('{n}', '$index')
          : (id.isNotEmpty
              ? id
              : t('Altyazı {n}').replaceAll('{n}', '$index')));
  if (language.isNotEmpty && language != base) {
    return '$base – $language';
  }
  return base;
}

Future<void> showAudioPicker(BuildContext context, Player player) async {
  final tracks = player.state.tracks.audio;
  final current = player.state.track.audio;
  final options = <_TrackOption>[];
  var index = 0;
  for (final track in tracks) {
    if (track.id == 'auto' || track.id == 'no') continue;
    index += 1;
    options.add(_TrackOption(
      label: _audioLabel(track, index),
      selected: current.id == track.id,
      choice: _TrackChoice(audio: track),
    ));
  }
  if (options.isNotEmpty) {
    options.insert(
      0,
      _TrackOption(
        label: t('Otomatik'),
        selected: current.id == 'auto',
        choice: _TrackChoice(audio: AudioTrack.auto()),
      ),
    );
  }
  final choice = await showDialog<_TrackChoice>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.62),
    builder: (context) => _TrackSheet(
      title: t('Ses Dili'),
      icon: Icons.audiotrack_rounded,
      emptyMessage: t('Ses bulunamadı'),
      options: options,
    ),
  );
  if (choice == null) return;
  final track = choice.audio;
  if (track == null) return;
  await player.setAudioTrack(track);
}

Future<void> showSubtitlePicker(BuildContext context, Player player) async {
  final tracks = player.state.tracks.subtitle;
  final current = player.state.track.subtitle;
  final options = <_TrackOption>[
    _TrackOption(
      label: t('Kapalı'),
      selected: current.id == 'no',
      choice: _TrackChoice(subtitle: SubtitleTrack.no()),
    ),
    _TrackOption(
      label: t('Otomatik'),
      selected: current.id == 'auto',
      choice: _TrackChoice(subtitle: SubtitleTrack.auto()),
    ),
  ];
  var index = 0;
  var embedded = 0;
  for (final track in tracks) {
    if (track.id == 'auto' || track.id == 'no') continue;
    index += 1;
    embedded += 1;
    options.add(_TrackOption(
      label: _subtitleLabel(track, index),
      selected: current.id == track.id,
      choice: _TrackChoice(subtitle: track),
    ));
  }
  options.add(
    _TrackOption(
      label: t('Harici altyazı ekle (URL)'),
      selected: false,
      icon: Icons.link_rounded,
      choice: const _TrackChoice(addUrl: true),
    ),
  );
  final choice = await showDialog<_TrackChoice>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.62),
    builder: (context) => _TrackSheet(
      title: t('Altyazı'),
      icon: Icons.subtitles_rounded,
      note: embedded == 0 ? t('Altyazı bulunamadı') : null,
      options: options,
    ),
  );
  if (choice == null) return;
  if (choice.addUrl) {
    final url = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (context) => const _SubtitleUrlDialog(),
    );
    if (url == null) return;
    await player.setSubtitleTrack(
      SubtitleTrack.uri(url, title: t('Harici')),
    );
    return;
  }
  final track = choice.subtitle;
  if (track == null) return;
  await player.setSubtitleTrack(track);
}

class _TrackSheet extends StatelessWidget {
  const _TrackSheet({
    required this.title,
    required this.icon,
    required this.options,
    this.emptyMessage,
    this.note,
  });

  final String title;
  final IconData icon;
  final List<_TrackOption> options;
  final String? emptyMessage;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final noteText = note;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        decoration: BoxDecoration(
          color: kNeonSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kNeonBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: <Widget>[
                  Icon(icon, size: 20, color: kNeonCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (noteText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Text(
                  noteText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A9AB5),
                  ),
                ),
              ),
            Flexible(
              child: options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                      child: Text(
                        emptyMessage ?? t('Kayıt bulunamadı'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8A9AB5),
                        ),
                      ),
                    )
                  : FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          return _TrackRow(
                            option: option,
                            autofocus: index == 0,
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

class _TrackRow extends StatefulWidget {
  const _TrackRow({required this.option, required this.autofocus});

  final _TrackOption option;
  final bool autofocus;

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  final FocusNode _node = FocusNode(debugLabel: 'track-row');
  bool _focused = false;
  bool _hovered = false;

  bool get _active => _focused || _hovered;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _activate() {
    Navigator.of(context).pop(widget.option.choice);
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.option.icon;
    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
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
            _activate();
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
          onTap: _activate,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _active ? kNeonCyanSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _active ? kNeonCyan : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 18,
                    color: _active ? kNeonCyan : const Color(0xFFB8C4D9),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    widget.option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.option.selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.option.selected
                          ? kNeonCyan
                          : (_active
                              ? Colors.white
                              : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                if (widget.option.selected) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: kNeonCyan,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleUrlDialog extends StatefulWidget {
  const _SubtitleUrlDialog();

  @override
  State<_SubtitleUrlDialog> createState() => _SubtitleUrlDialogState();
}

class _SubtitleUrlDialogState extends State<_SubtitleUrlDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValid(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('.srt') || path.endsWith('.vtt');
  }

  void _submit() {
    final value = _controller.text.trim();
    if (!_isValid(value)) {
      setState(() {
        _error = t('Geçerli bir http(s) .srt veya .vtt bağlantısı girin.');
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: kNeonSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kNeonBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.link_rounded, size: 20, color: kNeonCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('Harici altyazı ekle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                _submit();
              },
              style: const TextStyle(fontSize: 14, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://ornek.com/altyazi.srt',
                errorText: _error,
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(t('İptal')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(t('Ekle')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
