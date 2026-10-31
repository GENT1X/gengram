import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'media.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

Future<void> showNewChatDialog(
    BuildContext context, void Function(Map<String, dynamic> chat) onOpen) async {
  final title = TextEditingController();
  final about = TextEditingController();
  var channel = false;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => Theme(
      data: Tg.theme,
      child: StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(channel ? 'Новый канал' : 'Новая группа'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  ChoiceChip(
                      label: const Text('Группа'),
                      selected: !channel,
                      onSelected: (_) => setS(() => channel = false)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                      label: const Text('Канал'),
                      selected: channel,
                      onSelected: (_) => setS(() => channel = true)),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: title,
                    autofocus: true,
                    decoration: InputDecoration(
                        hintText: channel ? 'Название канала' : 'Название группы')),
                const SizedBox(height: 8),
                TextField(
                    controller: about,
                    maxLines: 3,
                    minLines: 1,
                    decoration:
                        const InputDecoration(hintText: 'Описание (необязательно)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Создать')),
          ],
        ),
      ),
    ),
  );
  final name = title.text.trim();
  final desc = about.text.trim();
  title.dispose();
  about.dispose();
  if (go != true || name.isEmpty) return;
  final r = await td.request({
    '@type': 'createNewSupergroupChat',
    'title': name,
    'is_forum': false,
    'is_channel': channel,
    'description': desc,
    'message_auto_delete_time': 0,
    'for_import': false,
  });
  if (r['@type'] != 'chat') {
    tgToast('Не получилось: ${r['message'] ?? 'ошибка'}');
    return;
  }
  onOpen(r);
}

Future<void> openFavorites(void Function(Map<String, dynamic> chat) onOpen) async {
  final me = await td.request({'@type': 'getMe'});
  if (me['@type'] != 'user') {
    tgToast('Не получилось открыть избранное');
    return;
  }
  final chat = await td.request(
      {'@type': 'createPrivateChat', 'user_id': me['id'], 'force': false});
  if (chat['@type'] != 'chat') {
    tgToast('Не получилось открыть избранное');
    return;
  }
  onOpen(chat);
}

class PinnedBar extends StatefulWidget {
  const PinnedBar({super.key, required this.chatId});
  final int chatId;

  @override
  State<PinnedBar> createState() => _PinnedBarState();
}

class _PinnedBarState extends State<PinnedBar> {
  Map<String, dynamic>? _msg;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = td.updates.listen((u) {
      if (u['@type'] == 'updateChatPinnedMessage' &&
          u['chat_id'] == widget.chatId) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await td
        .request({'@type': 'getChatPinnedMessage', 'chat_id': widget.chatId});
    if (!mounted) return;
    setState(() => _msg = r['@type'] == 'message' ? r : null);
  }

  Future<void> _unpin() async {
    final m = _msg;
    if (m == null) return;
    final ok = await tgConfirm(context,
        title: 'Открепить сообщение?', text: 'Оно исчезнет из верхней плашки.', yes: 'Открепить');
    if (!ok) return;
    final r = await td.request({
      '@type': 'unpinChatMessage',
      'chat_id': widget.chatId,
      'message_id': m['id'],
    });
    if (r['@type'] == 'error') tgToast('Не получилось: ${r['message']}');
  }

  @override
  Widget build(BuildContext context) {
    final m = _msg;
    if (m == null) return const SizedBox.shrink();
    return Container(
      color: Tg.panel,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: Tg.link),
          const SizedBox(width: 10),
          Icon(Icons.push_pin, size: 16, color: Tg.link),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Закреплённое сообщение',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Tg.link)),
                Text(messageText(m['content'] as Map),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: Tg.text)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Открепить',
            icon: Icon(Icons.close, size: 18, color: Tg.textSecondary),
            onPressed: _unpin,
          ),
        ],
      ),
    );
  }
}

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  final Map<int, List<int>> _stories = {}; // chat_id -> story_id
  final Map<int, Map> _chats = {};
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = td.updates.listen(_onUpdate);
    td.request({
      '@type': 'loadActiveStories',
      'story_list': {'@type': 'storyListMain'},
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onUpdate(Map<String, dynamic> u) async {
    if (u['@type'] != 'updateChatActiveStories') return;
    final a = u['active_stories'] as Map?;
    if (a == null) return;
    final id = a['chat_id'] as int;
    final ids = [
      for (final s in ((a['stories'] as List?) ?? const []))
        if (s is Map && s['story_id'] is int) s['story_id'] as int
    ];
    if (ids.isEmpty) {
      if (mounted) setState(() => _stories.remove(id));
      return;
    }
    if (!_chats.containsKey(id)) {
      final c = await td.request({'@type': 'getChat', 'chat_id': id});
      if (c['@type'] == 'chat') _chats[id] = c;
    }
    if (mounted) setState(() => _stories[id] = ids);
  }

  @override
  Widget build(BuildContext context) {
    if (_stories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (final e in _stories.entries)
            GestureDetector(
              onTap: () => _open(e.key, e.value),
              child: Container(
                width: 66,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [Color(0xFF5288C1), Color(0xFF6AB2F2)])),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Tg.bg),
                        child: TgAvatar(
                            id: e.key,
                            title: '${_chats[e.key]?['title'] ?? ''}',
                            photo: _chats[e.key]?['photo']?['small'] as Map?,
                            size: 40),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${_chats[e.key]?['title'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: Tg.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _open(int chatId, List<int> ids) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) =>
          Theme(data: Tg.theme, child: _StoryViewer(chatId: chatId, ids: ids)),
    );
  }
}

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({required this.chatId, required this.ids});
  final int chatId;
  final List<int> ids;

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  int _i = 0;
  Map? _story;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _story = null);
    final r = await td.request({
      '@type': 'getStory',
      'story_sender_chat_id': widget.chatId,
      'story_id': widget.ids[_i],
      'only_local': false,
    });
    if (!mounted) return;
    setState(() => _story = r['@type'] == 'story' ? r : <String, dynamic>{});
  }

  void _go(int d) {
    final n = _i + d;
    if (n >= widget.ids.length) {
      Navigator.pop(context);
      return;
    }
    if (n < 0) return;
    _i = n;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _story;
    final content = s?['content'] as Map?;
    Widget body;
    if (s == null) {
      body = Center(child: CircularProgressIndicator(color: Tg.link));
    } else if (content?['@type'] == 'storyContentPhoto') {
      final sizes = (content!['photo']?['sizes'] as List?) ?? const [];
      body = sizes.isEmpty
          ? const SizedBox.shrink()
          : TgImage(
              file: (sizes.last as Map)['photo'] as Map?,
              fit: BoxFit.contain,
              priority: 16);
    } else if (content?['@type'] == 'storyContentVideo') {
      final video = content!['video'] as Map?;
      body = Stack(
        alignment: Alignment.center,
        children: [
          TgImage(
              file: (video?['thumbnail'] as Map?)?['file'] as Map?,
              fit: BoxFit.contain),
          IconButton(
            iconSize: 56,
            color: Colors.white,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => openFileMap(video?['video'] as Map?),
          ),
        ],
      );
    } else {
      body = const Center(
          child: Text('История недоступна',
              style: TextStyle(color: Colors.white70)));
    }
    final caption = '${(s?['caption'] as Map?)?['text'] ?? ''}';
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: SafeArea(
              child: Row(
                children: [
                  for (var k = 0; k < widget.ids.length; k++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: k <= _i ? Colors.white : Colors.white24,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
              left: 0,
              top: 80,
              bottom: 80,
              width: 90,
              child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _go(-1))),
          Positioned(
              right: 0,
              top: 80,
              bottom: 80,
              width: 90,
              child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _go(1))),
          if (caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Text(caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
        ],
      ),
    );
  }
}
