import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/l10n.dart';
import '../services/update_service.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  bool get _canInstall => Platform.isAndroid && widget.info.apkUrl.isNotEmpty;

  String get _notes {
    final raw = widget.info.notes.trim();
    if (raw.isEmpty) return '';
    if (raw.length <= 400) return raw;
    return '${raw.substring(0, 400)}...';
  }

  Future<void> _start() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await UpdateService.downloadAndInstall(widget.info, (value) {
        if (!mounted) return;
        setState(() {
          _progress = value;
        });
      });
      if (!mounted) return;
      setState(() {
        _downloading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = t('Güncelleme indirilemedi.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).round();
    final notes = _notes;
    return AlertDialog(
      backgroundColor: kNeonSurfaceHigh.withOpacity(0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kNeonBorder),
      ),
      title: Text(
        t('Yeni Sürüm Mevcut'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${t('Sürüm')}: v${widget.info.version}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kNeonCyan,
              ),
            ),
            if (notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                notes,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFFB9B9C9),
                ),
              ),
            ],
            if (!_canInstall) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                t('Yeni sürüm var: v{version}, Release sayfasından indirin.')
                    .replaceAll('{version}', widget.info.version),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFFB9B9C9),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.info.pageUrl,
                style: const TextStyle(
                  fontSize: 11,
                  color: kNeonCyan,
                ),
              ),
            ],
            if (_downloading) ...<Widget>[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB9B9C9),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: kNeonMagenta),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _downloading
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: Text(t('Sonra')),
        ),
        if (_canInstall)
          FilledButton(
            autofocus: true,
            onPressed: _downloading
                ? null
                : () {
                    _start();
                  },
            child: Text(t('Güncelle')),
          ),
      ],
    );
  }
}
