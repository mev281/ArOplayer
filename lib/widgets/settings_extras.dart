import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/l10n.dart';
import '../services/library_prefs.dart';
import '../services/storage_service.dart';

Future<bool> askPin(BuildContext context, String title) async {
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
        decoration: InputDecoration(labelText: t('PIN'), counterText: ''),
        onSubmitted: (value) {
          Navigator.of(dialogContext).pop(storage.verifyPin(value));
        },
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
  if (result == false && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('PIN yanlış veya iptal edildi.'))),
    );
  }
  return result ?? false;
}

class ListManagerBody extends StatefulWidget {
  const ListManagerBody({super.key});

  @override
  State<ListManagerBody> createState() => _ListManagerBodyState();
}

class _ListManagerBodyState extends State<ListManagerBody> {
  @override
  void initState() {
    super.initState();
    LibraryPrefs.instance.changes.addListener(_refresh);
    LibraryPrefs.instance.init();
  }

  @override
  void dispose() {
    LibraryPrefs.instance.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _activate(ListEntry entry) async {
    final storage = StorageService.instance;
    await storage.saveSource(type: SourceType.m3u, m3uUrl: entry.m3u);
    await storage.setEpgUrl(entry.epg);
    await storage.clearPlaylistCache();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const AppLoader()),
      (route) => false,
    );
  }

  Future<void> _saveCurrent() async {
    final storage = StorageService.instance;
    final url = storage.m3uUrl;
    if (url == null) return;
    final name = await _askName(t('Ana Liste'));
    if (name == null || !mounted) return;
    await LibraryPrefs.instance.addList(
      ListEntry(name: name, m3u: url, epg: storage.epgUrl),
    );
  }

  Future<String?> _askName(String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: Text(t('Liste adı')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t('Ana Liste')),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('İptal')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(t('Kaydet')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> _addNew() async {
    final name = TextEditingController();
    final m3u = TextEditingController();
    final epg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kNeonSurfaceHigh,
        title: Text(t('Yeni liste ekle')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: t('Liste adı')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: m3u,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'M3U URL'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: epg,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'EPG URL (${t('isteğe bağlı')})',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('İptal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('Kaydet')),
          ),
        ],
      ),
    );
    final entry = ListEntry(
      name: name.text.trim().isEmpty ? 'Liste' : name.text.trim(),
      m3u: m3u.text.trim(),
      epg: epg.text.trim(),
    );
    name.dispose();
    m3u.dispose();
    epg.dispose();
    if (ok != true || entry.m3u.isEmpty) return;
    await LibraryPrefs.instance.addList(entry);
  }

  @override
  Widget build(BuildContext context) {
    final lists = LibraryPrefs.instance.lists;
    final current = StorageService.instance.m3uUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entry in lists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  entry.m3u == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: entry.m3u == current ? kNeonCyan : Colors.white54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.epg.isEmpty ? entry.name : '${entry.name}  (EPG)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (entry.m3u != current)
                  TextButton(
                    onPressed: () => _activate(entry),
                    child: Text(t('Geç')),
                  ),
                IconButton(
                  tooltip: t('Sil'),
                  onPressed: () => LibraryPrefs.instance.removeList(entry),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            if (current != null && !lists.any((e) => e.m3u == current))
              OutlinedButton.icon(
                onPressed: _saveCurrent,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(t('Mevcut listeyi kaydet')),
              ),
            FilledButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_rounded),
              label: Text(t('Yeni liste ekle')),
            ),
          ],
        ),
      ],
    );
  }
}

class CategoryManagerBody extends StatelessWidget {
  const CategoryManagerBody({super.key, required this.categories});

  final List<String> categories;

  Future<void> _open(BuildContext context) async {
    await LibraryPrefs.instance.init();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _CategoryDialog(categories: categories, parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.visibility_off_outlined),
        label: Text(t('Kategorileri yönet')),
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.categories,
    required this.parentContext,
  });

  final List<String> categories;
  final BuildContext parentContext;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  Future<void> _toggleHidden(String name) async {
    final prefs = LibraryPrefs.instance;
    if (prefs.isHidden(name) && StorageService.instance.pin != null) {
      if (!await askPin(context, t('PIN doğrulama'))) return;
    }
    await prefs.setHidden(name, !prefs.isHidden(name));
    if (mounted) setState(() {});
  }

  Future<void> _toggleLocked(String name) async {
    final prefs = LibraryPrefs.instance;
    if (StorageService.instance.pin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Önce Ebeveyn kontrolü bölümünden 4 haneli PIN belirleyin.'),
          ),
        ),
      );
      return;
    }
    if (!await askPin(context, t('PIN doğrulama'))) return;
    await prefs.setLocked(name, !prefs.isLocked(name));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final prefs = LibraryPrefs.instance;
    return AlertDialog(
      backgroundColor: kNeonSurfaceHigh,
      title: Text(t('Kategorileri yönet')),
      content: SizedBox(
        width: 460,
        height: 420,
        child: widget.categories.isEmpty
            ? Center(child: Text(t('Kategori bulunamadı.')))
            : ListView.builder(
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final name = widget.categories[index];
                  final hidden = prefs.isHidden(name);
                  final locked = prefs.isLocked(name);
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hidden ? Colors.white38 : Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: t('Gizle'),
                        onPressed: () => _toggleHidden(name),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: hidden ? kNeonMagenta : Colors.white70,
                        ),
                      ),
                      IconButton(
                        tooltip: t('PIN ile kilitle'),
                        onPressed: () => _toggleLocked(name),
                        icon: Icon(
                          locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          color: locked ? kNeonCyan : Colors.white70,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: <Widget>[
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('Kapat')),
        ),
      ],
    );
  }
}
