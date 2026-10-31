import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'media.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';
import 'video_player.dart';

final keeper = Keeper();

class _Watch {
  _Watch(this.chatId, this.messageId, this.kind);
  final int chatId;
  final int messageId;
  final String kind; // photo | video
}

class Keeper {
  final Map<String, _Watch> _watch = {};

  void onUpdate(Account account, Map<String, dynamic> u) {
    if (!settings.keepSelfDestruct) return;
    switch (u['@type']) {
      case 'updateNewMessage':
        _inspect(account, u['message'] as Map<String, dynamic>);
      case 'updateMessageContent':
        _inspectContent(account, u['chat_id'] as int, u['message_id'] as int,
            u['new_content'] as Map);
      case 'updateFile':
        _onFile(account, u['file'] as Map);
    }
  }

  void _inspect(Account a, Map<String, dynamic> m) =>
      _inspectContent(a, m['chat_id'] as int, m['id'] as int, m['content'] as Map);

  bool _selfDestructs(Map c) =>
      c['self_destruct_type'] != null || c['is_secret'] == true;

  void _inspectContent(Account a, int chatId, int msgId, Map content) {
    final type = content['@type'];
    if (type != 'messagePhoto' && type != 'messageVideo') return;
    if (!_selfDestructs(content)) return;
    Map? file;
    String kind;
    if (type == 'messagePhoto') {
      final sizes = (content['photo']?['sizes'] as List?) ?? const [];
      if (sizes.isEmpty) return;
      file = sizes.last['photo'] as Map?;
      kind = 'photo';
    } else {
      file = content['video']?['video'] as Map?;
      kind = 'video';
    }
    final id = file?['id'];
    if (id is! int) return;
    _watch['${a.id}:$id'] = _Watch(chatId, msgId, kind);
    if (readyPath(file) != null) {
      unawaited(_copy(a, id, file!));
    } else {
      unawaited(a.td.request({
        '@type': 'downloadFile',
        'file_id': id,
        'priority': 12,
        'offset': 0,
        'limit': 0,
        'synchronous': false,
      }));
    }
  }

  void _onFile(Account a, Map file) {
    final id = file['id'];
    if (id is! int) return;
    if (!_watch.containsKey('${a.id}:$id')) return;
    if (readyPath(file) != null) unawaited(_copy(a, id, file));
  }

  Future<void> _copy(Account a, int fileId, Map file) async {
    final w = _watch.remove('${a.id}:$fileId');
    final src = readyPath(file);
    if (w == null || src == null) return;
    try {
      final dir = await savedDir();
      final dot = src.lastIndexOf('.');
      final ext = dot >= 0 ? src.substring(dot) : (w.kind == 'photo' ? '.jpg' : '.mp4');
      final target =
          File('${dir.path}/${a.id}_${w.chatId}_${w.messageId}$ext');
      if (!await target.exists()) {
        await File(src).copy(target.path);
        tgToast('Исчезающее медиа сохранено');
      }
    } catch (_) {
    }
  }

  Future<Directory> savedDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/gengram_saved');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

class SavedMediaPage extends StatefulWidget {
  const SavedMediaPage({super.key});

  @override
  State<SavedMediaPage> createState() => _SavedMediaPageState();
}

class _SavedMediaPageState extends State<SavedMediaPage> {
  late Future<List<File>> _files = _load();

  Future<List<File>> _load() async {
    final dir = await keeper.savedDir();
    final list = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return list;
  }

  bool _isImage(String p) {
    final l = p.toLowerCase();
    return l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    return TgPage(title: 'Сохранённые исчезающие', children: [
      FutureBuilder<List<File>>(
        future: _files,
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) {
            return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()));
          }
          if (list.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Text('Пока пусто. Сюда попадают исчезающие и одноразовые '
                  'фото и видео, которые Telegram доставил этому устройству.',
                  style: TextStyle(color: Tg.textSecondary)),
            );
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final f = list[i];
              final img = _isImage(f.path);
              return GestureDetector(
                onTap: () => img
                    ? showDialog<void>(
                        context: context,
                        builder: (_) => Dialog.fullscreen(
                          backgroundColor: Colors.black,
                          child: Stack(children: [
                            Positioned.fill(
                                child: InteractiveViewer(child: Image.file(f))),
                            const BackButton(color: Colors.white),
                          ]),
                        ))
                    : playInApp(f.path),
                onLongPress: () async {
                  if (await tgConfirm(context,
                      title: 'Удалить копию?',
                      text: 'Файл будет удалён с этого устройства.',
                      yes: 'Удалить',
                      danger: true)) {
                    await f.delete();
                    setState(() => _files = _load());
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: img
                      ? Image.file(f, fit: BoxFit.cover, cacheWidth: 300)
                      : Container(
                          color: Tg.panelOver,
                          child: const Icon(Icons.play_circle_outline,
                              size: 40, color: Colors.white70)),
                ),
              );
            },
          );
        },
      ),
    ]);
  }
}
