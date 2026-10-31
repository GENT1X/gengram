import 'package:flutter/material.dart';

import 'app_state.dart';
import 'hidden_chats.dart';
import 'tg_style.dart';

Future<Map<String, dynamic>?> pickChat(BuildContext context,
    {String title = 'Выберите чат'}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => Theme(data: Tg.theme, child: _ChatPicker(title: title)),
  );
}

class _ChatPicker extends StatefulWidget {
  const _ChatPicker({required this.title});
  final String title;

  @override
  State<_ChatPicker> createState() => _ChatPickerState();
}

class _ChatPickerState extends State<_ChatPicker> {
  List<Map<String, dynamic>>? _chats;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await td.request({
      '@type': 'loadChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 100,
    });
    final ids = await td.request({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': 100,
    });
    final list = await Future.wait([
      for (final id in (ids['chat_ids'] as List? ?? const []))
        td.request({'@type': 'getChat', 'chat_id': id}),
    ]);
    if (!mounted) return;
    setState(() => _chats = [
          for (final c in list)
            if (c['@type'] == 'chat' && hidden.isVisible(c['id'] as int)) c,
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final chats = [
      for (final c in _chats ?? const <Map<String, dynamic>>[])
        if (q.isEmpty || (c['title'] as String).toLowerCase().contains(q)) c,
    ];
    return Dialog(
      backgroundColor: Tg.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Поиск'),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: _chats == null
                  ? Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Tg.link),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: chats.length,
                      itemBuilder: (_, i) {
                        final c = chats[i];
                        return ListTile(
                          leading: TgAvatar(
                              id: c['id'] as int,
                              title: c['title'] as String,
                              photo: c['photo']?['small'] as Map?,
                              size: 42),
                          title: Text(c['title'] as String,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}
