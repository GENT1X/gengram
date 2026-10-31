import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'media.dart';
import 'message_store.dart';
import 'notifier.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';
import 'video_player.dart';

Future<Map<String, dynamic>?> pickSendOptions(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Tg.panelOver,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.notifications_off_outlined),
          title: const Text('Отправить без звука'),
          onTap: () => Navigator.pop(ctx, 'silent'),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_send_outlined),
          title: const Text('Отправить позже'),
          onTap: () => Navigator.pop(ctx, 'later'),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'silent') {
    return {'@type': 'messageSendOptions', 'disable_notification': true};
  }
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
  );
  if (time == null) return null;
  final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  if (at.isBefore(now.add(const Duration(seconds: 30)))) {
    tgToast('Выберите время в будущем');
    return null;
  }
  return {
    '@type': 'messageSendOptions',
    'scheduling_state': {
      '@type': 'messageSchedulingStateSendAtDate',
      'send_date': at.millisecondsSinceEpoch ~/ 1000,
    },
  };
}

// ---------- Цитата ----------

Future<String?> pickQuote(BuildContext context, String text) {
  final ctl = TextEditingController(text: text);
  return showDialog<String>(
    context: context,
    builder: (ctx) => Theme(
      data: Tg.theme,
      child: AlertDialog(
        backgroundColor: Tg.panelOver,
        title: const Text('Выделите часть для цитаты'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctl,
            readOnly: true,
            maxLines: 8,
            minLines: 2,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final sel = ctl.selection;
              final part = (sel.isValid && !sel.isCollapsed)
                  ? sel.textInside(text)
                  : text;
              Navigator.pop(ctx, part);
            },
            child: const Text('Цитировать'),
          ),
        ],
      ),
    ),
  ).whenComplete(ctl.dispose);
}

Future<void> showEditHistory(BuildContext context, SavedMessage m) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Tg.panelOver,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('История правок',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            for (final e in m.edits.reversed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Tg.panel, borderRadius: BorderRadius.circular(12)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.text),
                      const SizedBox(height: 4),
                      Text('заменено ${tgHhmm(e.until)}',
                          style: TextStyle(
                              fontSize: 12, color: Tg.textSecondary)),
                    ]),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  border: Border.all(color: Tg.link.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text),
                    const SizedBox(height: 4),
                    Text('сейчас',
                        style:
                            TextStyle(fontSize: 12, color: Tg.textSecondary)),
                  ]),
            ),
          ],
        ),
      ),
    ),
  );
}

String _snippet(Map m) => messageText(m['content'] as Map);

Future<void> showPinnedList(BuildContext context, int chatId) {
  return tgPush(context, _MessageListPage(
    title: 'Закреплённые сообщения',
    load: () async {
      final r = await td.request({
        '@type': 'searchChatMessages',
        'chat_id': chatId,
        'query': '',
        'filter': {'@type': 'searchMessagesFilterPinned'},
        'limit': 100,
      });
      return ((r['messages'] as List?) ?? const []).cast<Map>();
    },
  ));
}

Future<void> showScheduledList(BuildContext context, int chatId) {
  return tgPush(context, _MessageListPage(
    title: 'Отложенные сообщения',
    load: () async {
      final r = await td.request(
          {'@type': 'getChatScheduledMessages', 'chat_id': chatId});
      return ((r['messages'] as List?) ?? const []).cast<Map>();
    },
    actions: (m, reload) => [
      TextButton(
        onPressed: () async {
          await td.request({
            '@type': 'editMessageSchedulingState',
            'chat_id': chatId,
            'message_id': m['id'],
          });
          reload();
        },
        child: const Text('Отправить сейчас'),
      ),
      TextButton(
        onPressed: () async {
          await td.request({
            '@type': 'deleteMessages',
            'chat_id': chatId,
            'message_ids': [m['id']],
            'revoke': true,
          });
          reload();
        },
        child: const Text('Отменить', style: TextStyle(color: Tg.danger)),
      ),
    ],
  ));
}

class _MessageListPage extends StatefulWidget {
  const _MessageListPage({required this.title, required this.load, this.actions});

  final String title;
  final Future<List<Map>> Function() load;
  final List<Widget> Function(Map m, VoidCallback reload)? actions;

  @override
  State<_MessageListPage> createState() => _MessageListPageState();
}

class _MessageListPageState extends State<_MessageListPage> {
  late Future<List<Map>> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return TgPage(title: widget.title, children: [
      FutureBuilder<List<Map>>(
        future: _future,
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
                child: Text('Пусто', style: TextStyle(color: Tg.textSecondary)));
          }
          return Column(children: [
            for (final m in list)
              ListTile(
                title: Text(_snippet(m), maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  tgHhmm((m['date'] as int?) ?? 0),
                  style: TextStyle(color: Tg.textSecondary),
                ),
                trailing: widget.actions == null
                    ? null
                    : Wrap(children: widget.actions!(m, _reload)),
              ),
          ]);
        },
      ),
    ]);
  }
}

const _filters = <(String, String)>[
  ('Медиа', 'searchMessagesFilterPhotoAndVideo'),
  ('Файлы', 'searchMessagesFilterDocument'),
  ('Ссылки', 'searchMessagesFilterUrl'),
  ('Голосовые', 'searchMessagesFilterVoiceNote'),
];

Future<void> showChatMedia(BuildContext context, int chatId, String title) {
  return tgPush(context, Scaffold(
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Tg.panel,
    ),
    body: _Tabs(chatId: chatId),
  ));
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.chatId});
  final int chatId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _filters.length,
      child: Column(children: [
        TabBar(isScrollable: true, tabs: [for (final f in _filters) Tab(text: f.$1)]),
        Expanded(
          child: TabBarView(children: [
            for (final f in _filters)
              MediaList(filter: f.$2, chatId: chatId),
          ]),
        ),
      ]),
    );
  }
}

class MediaList extends StatefulWidget {
  const MediaList({super.key, required this.filter, this.chatId, this.query = ''});

  final String filter;
  final int? chatId;
  final String query;

  @override
  State<MediaList> createState() => _MediaListState();
}

class _MediaListState extends State<MediaList>
    with AutomaticKeepAliveClientMixin {
  final List<Map> _items = [];
  final _scroll = ScrollController();
  bool _loading = false;
  bool _done = false;
  String _next = '';
  int _fromId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _more();
      }
    });
    _more();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    _loading = true;
    final filter = {'@type': widget.filter};
    final Map<String, dynamic> r;
    if (widget.chatId != null) {
      r = await td.request({
        '@type': 'searchChatMessages',
        'chat_id': widget.chatId,
        'query': widget.query,
        'from_message_id': _fromId,
        'limit': 50,
        'filter': filter,
      });
    } else {
      r = await td.request({
        '@type': 'searchMessages',
        'chat_list': {'@type': 'chatListMain'},
        'query': widget.query,
        'offset': _next,
        'limit': 50,
        'filter': filter,
      });
    }
    final list = ((r['messages'] as List?) ?? const []).cast<Map>();
    if (!mounted) return;
    setState(() {
      _items.addAll(list);
      if (list.isEmpty) _done = true;
      if (widget.chatId != null && list.isNotEmpty) {
        _fromId = list.last['id'] as int;
      } else {
        _next = (r['next_offset'] as String?) ?? '';
        if (_next.isEmpty) _done = true;
      }
    });
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty) {
      return Center(
          child: _done
              ? Text('Ничего нет',
                  style: TextStyle(color: Tg.textSecondary))
              : const CircularProgressIndicator());
    }
    if (widget.filter == 'searchMessagesFilterPhotoAndVideo') return _grid();
    return ListView.builder(
      controller: _scroll,
      itemCount: _items.length,
      itemBuilder: (context, i) => _tile(_items[i]),
    );
  }

  Widget _grid() {
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130, mainAxisSpacing: 3, crossAxisSpacing: 3),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final m = _items[i];
        final c = m['content'] as Map;
        Map? thumb;
        Map? mini;
        Map? file;
        var video = false;
        if (c['@type'] == 'messagePhoto') {
          final sizes = (c['photo']?['sizes'] as List?) ?? const [];
          if (sizes.isEmpty) return const SizedBox.shrink();
          thumb = (sizes.length > 1 ? sizes[1] : sizes.first)['photo'] as Map?;
          file = sizes.last['photo'] as Map?;
          mini = c['photo']?['minithumbnail'] as Map?;
        } else {
          video = true;
          final v = c['video'] as Map?;
          thumb = v?['thumbnail']?['file'] as Map?;
          file = v?['video'] as Map?;
          mini = v?['minithumbnail'] as Map?;
        }
        return GestureDetector(
          onTap: () => video ? openFileMap(file) : showPhotoViewer(context, file, mini),
          child: Stack(fit: StackFit.expand, children: [
            TgImage(file: thumb, mini: mini, width: 130, height: 130),
            if (video)
              const Center(
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white70, size: 32)),
          ]),
        );
      },
    );
  }

  Widget _tile(Map m) {
    final c = m['content'] as Map;
    switch (c['@type']) {
      case 'messageDocument':
        final d = c['document'] as Map;
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text('${d['file_name'] ?? 'Файл'}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_size((d['document']?['size'] as int?) ?? 0)),
          onTap: () => openFileMap(d['document'] as Map?),
        );
      case 'messageVoiceNote':
        final v = c['voice_note'] as Map;
        return ListTile(
          leading: const Icon(Icons.mic_none),
          title: Text('Голосовое · ${v['duration']} с'),
          subtitle: Text(tgHhmm((m['date'] as int?) ?? 0)),
          onTap: () => openFileMap(v['voice'] as Map?),
        );
      default:
        final text = (c['text']?['text'] as String?) ?? messageText(c);
        final links = _links(c);
        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(links.isEmpty ? text : links.first,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Tg.link)),
          subtitle: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            final chat = m['chat_id'] as int;
            notifier.requestOpen.value = chat;
          },
        );
    }
  }

  List<String> _links(Map c) {
    final t = c['text'] as Map?;
    final text = (t?['text'] as String?) ?? '';
    final result = <String>[];
    for (final e in (t?['entities'] as List? ?? const []).cast<Map>()) {
      final type = e['type']?['@type'];
      if (type == 'textEntityTypeUrl') {
        result.add(text.substring(e['offset'] as int, (e['offset'] as int) + (e['length'] as int)));
      } else if (type == 'textEntityTypeTextUrl') {
        result.add('${e['type']['url']}');
      }
    }
    return result;
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }
}

class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _ctl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<Map> _chats = [];
  int _gen = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    final gen = ++_gen;
    if (q.isEmpty) {
      setState(() {
        _q = '';
        _chats = [];
      });
      return;
    }
    final r = await td.request(
        {'@type': 'searchChats', 'query': q, 'limit': 20});
    final ids = (r['chat_ids'] as List?) ?? const [];
    final chats = await Future.wait([
      for (final id in ids) td.request({'@type': 'getChat', 'chat_id': id}),
    ]);
    if (!mounted || gen != _gen) return;
    setState(() {
      _q = q;
      _chats = chats.where((c) => c['@type'] == 'chat').cast<Map>().toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Сообщения', ''),
      ('Медиа', 'searchMessagesFilterPhotoAndVideo'),
      ('Файлы', 'searchMessagesFilterDocument'),
      ('Ссылки', 'searchMessagesFilterUrl'),
    ];
    return DefaultTabController(
      length: tabs.length + 1,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Tg.panel,
          title: TextField(
            controller: _ctl,
            autofocus: true,
            onChanged: _changed,
            decoration: const InputDecoration(
                hintText: 'Поиск по всем чатам', border: InputBorder.none),
          ),
          bottom: TabBar(isScrollable: true, tabs: [
            const Tab(text: 'Чаты'),
            for (final t in tabs) Tab(text: t.$1),
          ]),
        ),
        body: _q.isEmpty
            ? Center(
                child: Text('Введите запрос',
                    style: TextStyle(color: Tg.textSecondary)))
            : TabBarView(children: [
                ListView(children: [
                  for (final c in _chats)
                    ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text('${c['title']}'),
                      onTap: () {
                        Navigator.of(context).pop();
                        notifier.requestOpen.value = c['id'] as int;
                      },
                    ),
                ]),
                for (final t in tabs)
                  t.$2.isEmpty
                      ? _AllMessages(key: ValueKey(_q), query: _q)
                      : MediaList(
                          key: ValueKey('${t.$2}$_q'),
                          filter: t.$2,
                          query: _q),
              ]),
      ),
    );
  }
}

class _AllMessages extends StatefulWidget {
  const _AllMessages({super.key, required this.query});
  final String query;

  @override
  State<_AllMessages> createState() => _AllMessagesState();
}

class _AllMessagesState extends State<_AllMessages> {
  List<Map>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await td.request({
      '@type': 'searchMessages',
      'chat_list': {'@type': 'chatListMain'},
      'query': widget.query,
      'limit': 50,
    });
    if (!mounted) return;
    setState(() => _items = ((r['messages'] as List?) ?? const []).cast<Map>());
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return Center(
          child: Text('Ничего не найдено',
              style: TextStyle(color: Tg.textSecondary)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return ListTile(
          title: Text(_snippet(m), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(tgHhmm((m['date'] as int?) ?? 0),
              style: TextStyle(color: Tg.textSecondary)),
          onTap: () {
            Navigator.of(context).pop();
            notifier.requestOpen.value = m['chat_id'] as int;
          },
        );
      },
    );
  }
}
