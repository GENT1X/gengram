import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounts.dart';

final localEmoji = LocalEmoji();

String? customEmojiIdOf(Map sticker) {
  final id = (sticker['full_type'] as Map?)?['custom_emoji_id'] ??
      sticker['custom_emoji_id'];
  return id == null ? null : '$id';
}

bool hasCustomEmoji(Map? text) {
  final list = (text?['entities'] as List?) ?? const [];
  return list.any((e) => (e as Map)['type']?['@type'] == 'textEntityTypeCustomEmoji');
}

class LocalEmoji extends ChangeNotifier {
  static const _kItems = 'local_emoji_items';
  static const _limit = 500;

  final Map<String, Map<String, dynamic>> _items = {};
  final Map<String, Map<String, dynamic>> _pending = {};
  SharedPreferences? _p;

  Future<void> load() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      final raw = p.getString(_kItems);
      if (raw != null) {
        (jsonDecode(raw) as Map).forEach(
            (k, v) => _items['$k'] = (v as Map).cast<String, dynamic>());
      }
      notifyListeners();
    } catch (_) {}
  }

  String _key(int chat, int msg) => '${accounts.active.id}:$chat:$msg';

  Map<String, dynamic>? of(int chat, int msg) =>
      _items[_key(chat, msg)] ?? _pending[_key(chat, msg)];

  void pend(int chat, int tempId, Map<String, dynamic> text) {
    _pending[_key(chat, tempId)] = text;
  }

  void settle(int chat, int oldId, int newId) {
    final t = _pending.remove(_key(chat, oldId));
    if (t == null) return;
    _items[_key(chat, newId)] = t;
    while (_items.length > _limit) {
      _items.remove(_items.keys.first);
    }
    _saveItems();
    notifyListeners();
  }

  Future<void> _saveItems() async {
    try {
      await _p?.setString(_kItems, jsonEncode(_items));
    } catch (_) {}
  }
}
