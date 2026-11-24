import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ListEntry {
  const ListEntry({required this.name, required this.m3u, this.epg = ''});

  final String name;
  final String m3u;
  final String epg;

  Map<String, String> toJson() => <String, String>{
        'name': name,
        'm3u': m3u,
        'epg': epg,
      };

  factory ListEntry.fromJson(Map<String, dynamic> j) => ListEntry(
        name: (j['name'] ?? '') as String,
        m3u: (j['m3u'] ?? '') as String,
        epg: (j['epg'] ?? '') as String,
      );
}

class LibraryPrefs {
  LibraryPrefs._();

  static final LibraryPrefs instance = LibraryPrefs._();

  static const String _keyLists = 'source_lists_v1';
  static const String _keyHidden = 'hidden_categories_v1';
  static const String _keyLocked = 'locked_categories_v1';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final Set<String> _unlockedThisSession = <String>{};

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  List<ListEntry> _lists = <ListEntry>[];
  Set<String> _hidden = <String>{};
  Set<String> _locked = <String>{};
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await _prefs;
    try {
      final raw = prefs.getString(_keyLists);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _lists = decoded
              .whereType<Map>()
              .map((e) => ListEntry.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.m3u.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      _lists = <ListEntry>[];
    }
    _hidden = (prefs.getStringList(_keyHidden) ?? <String>[]).toSet();
    _locked = (prefs.getStringList(_keyLocked) ?? <String>[]).toSet();
    _loaded = true;
    changes.value++;
  }

  List<ListEntry> get lists => List<ListEntry>.unmodifiable(_lists);

  Future<void> _saveLists() async {
    final prefs = await _prefs;
    await prefs.setString(
      _keyLists,
      jsonEncode(_lists.map((e) => e.toJson()).toList()),
    );
    changes.value++;
  }

  Future<void> addList(ListEntry entry) async {
    final index = _lists.indexWhere((e) => e.m3u == entry.m3u);
    if (index >= 0) {
      _lists[index] = entry;
    } else {
      _lists.add(entry);
    }
    await _saveLists();
  }

  Future<void> removeList(ListEntry entry) async {
    _lists.removeWhere((e) => e.m3u == entry.m3u);
    await _saveLists();
  }

  bool isHidden(String category) => _hidden.contains(category);
  bool isLocked(String category) => _locked.contains(category);
  bool isUnlocked(String category) => _unlockedThisSession.contains(category);
  Set<String> get hidden => Set<String>.unmodifiable(_hidden);
  Set<String> get locked => Set<String>.unmodifiable(_locked);

  Future<void> setHidden(String category, bool value) async {
    if (value) {
      _hidden.add(category);
    } else {
      _hidden.remove(category);
    }
    final prefs = await _prefs;
    await prefs.setStringList(_keyHidden, _hidden.toList());
    changes.value++;
  }

  Future<void> setLocked(String category, bool value) async {
    if (value) {
      _locked.add(category);
    } else {
      _locked.remove(category);
      _unlockedThisSession.remove(category);
    }
    final prefs = await _prefs;
    await prefs.setStringList(_keyLocked, _locked.toList());
    changes.value++;
  }

  void unlockForSession(String category) {
    _unlockedThisSession.add(category);
  }
}
