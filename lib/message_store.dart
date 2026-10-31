import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'accounts.dart';
import 'app_state.dart';

class SavedMessage {
  SavedMessage({
    required this.id,
    required this.chatId,
    required this.date,
    required this.outgoing,
    required this.text,
    this.deletedAt,
    List<EditVersion>? edits,
  }) : edits = edits ?? [];

  final int id;
  final int chatId;
  final int date; // unix-время отправки
  final bool outgoing;
  String text;
  int? deletedAt;

  final List<EditVersion> edits;

  bool get deleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'chat': chatId,
        'date': date,
        'out': outgoing,
        'text': text,
        if (deletedAt != null) 'del': deletedAt,
        if (edits.isNotEmpty) 'edits': edits.map((e) => e.toJson()).toList(),
      };

  factory SavedMessage.fromJson(Map<String, dynamic> j) => SavedMessage(
        id: j['id'] as int,
        chatId: j['chat'] as int,
        date: j['date'] as int,
        outgoing: j['out'] as bool,
        text: j['text'] as String,
        deletedAt: j['del'] as int?,
        edits: [
          for (final e in (j['edits'] as List? ?? const []))
            EditVersion.fromJson(e as Map<String, dynamic>),
        ],
      );
}

class EditVersion {
  const EditVersion(this.text, this.until);

  final String text;
  final int until;

  Map<String, dynamic> toJson() => {'t': text, 'u': until};

  factory EditVersion.fromJson(Map<String, dynamic> j) =>
      EditVersion(j['t'] as String, j['u'] as int);
}

class MessageStore {
  MessageStore(this.fileName);

  final String fileName;

  static const _maxPerChat = 300;

  final Map<int, Map<int, SavedMessage>> _byChat = {};
  File? _file;
  Timer? _saveTimer;

  Future<void> load() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/$fileName');
    if (!await _file!.exists()) return;
    try {
      final list = jsonDecode(await _file!.readAsString()) as List;
      for (final item in list) {
        final m = SavedMessage.fromJson(item as Map<String, dynamic>);
        (_byChat[m.chatId] ??= {})[m.id] = m;
      }
    } catch (_) {
    }
  }

  void remember(Map<String, dynamic> msg) {
    final chatId = msg['chat_id'] as int;
    final id = msg['id'] as int;
    final chat = _byChat[chatId] ??= {};
    final text = messageText(msg['content'] as Map);
    final existing = chat[id];
    if (existing != null) {
      _noteEdit(existing, text);
    } else {
      chat[id] = SavedMessage(
        id: id,
        chatId: chatId,
        date: msg['date'] as int,
        outgoing: msg['is_outgoing'] == true,
        text: text,
      );
      _trim(chat);
    }
    _scheduleSave();
  }

  void updateContent(int chatId, int id, Map content) {
    final m = _byChat[chatId]?[id];
    if (m == null) return;
    _noteEdit(m, messageText(content));
    _scheduleSave();
  }

  void _noteEdit(SavedMessage m, String text) {
    if (m.text == text) return;
    if (m.text.isNotEmpty) {
      m.edits.add(EditVersion(
          m.text, DateTime.now().millisecondsSinceEpoch ~/ 1000));
      if (m.edits.length > 30) m.edits.removeAt(0);
    }
    m.text = text;
  }

  List<SavedMessage> markDeleted(int chatId, List ids) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final result = <SavedMessage>[];
    for (final id in ids) {
      final m = _byChat[chatId]?[id as int];
      if (m != null && !m.deleted) {
        m.deletedAt = now;
        result.add(m);
      }
    }
    if (result.isNotEmpty) _scheduleSave();
    return result;
  }

  bool isDeleted(int chatId, int id) => _byChat[chatId]?[id]?.deleted ?? false;

  SavedMessage? find(int chatId, int id) => _byChat[chatId]?[id];

  List<SavedMessage> deletedFor(int chatId) =>
      (_byChat[chatId]?.values ?? const <SavedMessage>[])
          .where((m) => m.deleted)
          .toList();

  int get deletedCount => _byChat.values
      .expand((c) => c.values)
      .where((m) => m.deleted)
      .length;

  Future<void> clearDeleted() async {
    for (final chat in _byChat.values) {
      chat.removeWhere((_, m) => m.deleted);
    }
    await _save();
  }

  void _trim(Map<int, SavedMessage> chat) {
    if (chat.length <= _maxPerChat) return;
    final regular = chat.values.where((m) => !m.deleted).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    var extra = chat.length - _maxPerChat;
    for (final m in regular) {
      if (extra-- <= 0) break;
      chat.remove(m.id);
    }
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _save();
  }

  void _scheduleSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    final all = _byChat.values.expand((c) => c.values).map((m) => m.toJson());
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(all.toList()), flush: true);
    await tmp.rename(file.path);
  }
}

MessageStore get store => accounts.active.store;
