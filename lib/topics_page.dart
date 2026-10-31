import 'package:flutter/material.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'chat_page.dart';
import 'media.dart';
import 'tg_style.dart';

class TopicChoice {
  const TopicChoice(this.id, this.name);
  final int id;
  final String name;
}

Future<List<Map>> loadTopics(int chatId) async {
  final out = <Map>[];
  var offsetDate = 0, offsetMessage = 0, offsetTopic = 0;
  for (var i = 0; i < 5; i++) {
    final r = await accounts.active.td.request({
      '@type': 'getForumTopics',
      'chat_id': chatId,
      'query': '',
      'offset_date': offsetDate,
      'offset_message_id': offsetMessage,
      'offset_forum_topic_id': offsetTopic,
      'limit': 100,
    });
    if (r['@type'] != 'forumTopics') break;
    final list = ((r['topics'] as List?) ?? const []).cast<Map>();
    if (list.isEmpty) break;
    out.addAll(list);
    if (list.length < 100) break;
    final last = list.last;
    final msg = last['last_message'] as Map?;
    offsetDate = (msg?['date'] as int?) ?? 0;
    offsetMessage = (msg?['id'] as int?) ?? 0;
    offsetTopic = (last['info']['forum_topic_id'] as int?) ?? 0;
  }
  return out;
}

Future<bool> isForumChat(Map chat) async {
  final type = chat['type'] as Map?;
  if (type?['@type'] != 'chatTypeSupergroup') return false;
  final g = await accounts.active.td
      .request({'@type': 'getSupergroup', 'supergroup_id': type!['supergroup_id']});
  return g['is_forum'] == true;
}

Future<TopicChoice?> showTopicPicker(BuildContext context, int chatId) {
  return showModalBottomSheet<TopicChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tg.panel,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Куда писать',
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w600, color: Tg.text)),
            ),
            Expanded(
              child: _TopicList(
                chatId: chatId,
                onPick: (c) => Navigator.pop(context, c),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TopicsPage extends StatelessWidget {
  const TopicsPage({super.key, required this.chatId, required this.title});

  final int chatId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Tg.theme,
      child: Scaffold(
        backgroundColor: Tg.bg,
        appBar: AppBar(backgroundColor: Tg.panel, title: Text(title)),
        body: _TopicList(
          chatId: chatId,
          onPick: (c) => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => Theme(
              data: Tg.theme,
              child: ChatPage(
                  chatId: chatId,
                  title: title,
                  topicId: c.id,
                  topicName: c.name),
            ),
          )),
        ),
      ),
    );
  }
}

class _TopicList extends StatefulWidget {
  const _TopicList({required this.chatId, required this.onPick});

  final int chatId;
  final void Function(TopicChoice choice) onPick;

  @override
  State<_TopicList> createState() => _TopicListState();
}

class _TopicListState extends State<_TopicList> {
  late Future<List<Map>> _future = loadTopics(widget.chatId);

  Future<void> _refresh() async {
    setState(() => _future = loadTopics(widget.chatId));
    await _future;
  }

  Widget _icon(Map info) {
    final emoji = '${(info['icon'] as Map?)?['custom_emoji_id'] ?? 0}';
    if (emoji != '0' && emoji.isNotEmpty) {
      return CustomEmojiView(emoji, size: 30);
    }
    final color = (info['icon'] as Map?)?['color'] as int?;
    final name = '${info['name'] ?? ''}'.trim();
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == null ? Tg.accent : Color(0xFF000000 | color),
      ),
      child: Text(info['is_general'] == true || name.isEmpty ? '#' : name[0].toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final topics = snap.data ?? const <Map>[];
        if (topics.isEmpty) {
          return Center(
              child: Text('Тем нет',
                  style: TextStyle(color: Tg.textSecondary)));
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            itemCount: topics.length,
            itemBuilder: (_, i) {
              final t = topics[i];
              final info = (t['info'] as Map?) ?? const {};
              final name = '${info['name'] ?? ''}';
              final last = t['last_message'] as Map?;
              final unread = (t['unread_count'] as int?) ?? 0;
              final preview =
                  last == null ? '' : messageText(last['content'] as Map);
              return ListTile(
                leading: _icon(info),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: Tg.text)),
                    ),
                    if (t['is_pinned'] == true) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin, size: 14, color: Tg.textSecondary),
                    ],
                    if (info['is_closed'] == true) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline, size: 14, color: Tg.textSecondary),
                    ],
                  ],
                ),
                subtitle: preview.isEmpty
                    ? null
                    : Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Tg.textSecondary)),
                trailing: unread > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Tg.badge,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('$unread',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      )
                    : null,
                onTap: () => widget.onPick(
                    TopicChoice((info['forum_topic_id'] as int?) ?? 1, name)),
              );
            },
          ),
        );
      },
    );
  }
}
