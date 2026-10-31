import 'package:flutter/material.dart';

import 'accounts.dart';
import 'media.dart';
import 'tg_style.dart';

const _fallback = ['❤️', '👍', '👎', '🔥', '🥰', '👏', '😁', '🤔', '😱', '😢', '🎉', '🤩'];

final Map<String, Future<Map?>> _emojiReactions = {};

Future<Map?> emojiReaction(String emoji) {
  final account = accounts.active;
  final key = '${account.id}:$emoji';
  return _emojiReactions[key] ??= () async {
    final r = await account.td.request({'@type': 'getEmojiReaction', 'emoji': emoji});
    if (r['@type'] == 'emojiReaction') return r;
    _emojiReactions.remove(key);
    return null;
  }();
}

String reactionKey(Map type) => type['@type'] == 'reactionTypeCustomEmoji'
    ? 'c:${type['custom_emoji_id']}'
    : 'e:${type['emoji']}';

class ReactionIcon extends StatelessWidget {
  const ReactionIcon(this.type, {super.key, this.size = 22, this.animated = false});

  final Map type;
  final double size;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    switch (type['@type']) {
      case 'reactionTypeCustomEmoji':
        return CustomEmojiView('${type['custom_emoji_id']}', size: size);
      case 'reactionTypePaid':
        return Icon(Icons.star_rounded, size: size, color: const Color(0xFFFFC857));
    }
    final emoji = '${type['emoji']}';
    return FutureBuilder<Map?>(
      future: emojiReaction(emoji),
      builder: (context, snap) {
        final r = snap.data;
        final sticker = r == null
            ? null
            : ((animated ? r['select_animation'] : null) ?? r['static_icon']) as Map?;
        if (sticker == null) {
          return SizedBox(
              width: size,
              height: size,
              child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.8))));
        }
        return StickerView(sticker, size: size);
      },
    );
  }
}

class ReactionBar extends StatefulWidget {
  const ReactionBar({super.key, required this.chatId, required this.messageId});

  final int chatId;
  final int messageId;

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  List<Map>? _types;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await accounts.active.td.request({
      '@type': 'getMessageAvailableReactions',
      'chat_id': widget.chatId,
      'message_id': widget.messageId,
      'row_size': 8,
    });
    final seen = <String>{};
    final out = <Map>[];
    void add(dynamic list) {
      for (final raw in ((list as List?) ?? const [])) {
        final item = raw as Map;
        if (item['needs_premium'] == true && !accounts.active.isPremium) continue;
        final type = item['type'] as Map?;
        if (type != null && seen.add(reactionKey(type))) out.add(type);
      }
    }

    add(r['top_reactions']);
    add(r['recent_reactions']);
    add(r['popular_reactions']);
    if (out.isEmpty) {
      for (final e in _fallback) {
        out.add({'@type': 'reactionTypeEmoji', 'emoji': e});
      }
    }
    if (mounted) setState(() => _types = out);
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    if (types == null) {
      return Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: Tg.panelOver, borderRadius: BorderRadius.circular(26)),
        child: const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final toggle = IconButton(
      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
      onPressed: () => setState(() => _expanded = !_expanded),
    );
    Widget item(Map t, double size) => GestureDetector(
          onTap: () => Navigator.pop(context, t),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: ReactionIcon(t, size: size, animated: !_expanded),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Tg.panelOver,
        borderRadius: BorderRadius.circular(_expanded ? 20 : 26),
      ),
      child: _expanded
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.centerRight, child: toggle),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260, maxWidth: 340),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 7,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [for (final t in types) item(t, 28)],
                  ),
                ),
              ],
            )
          : SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 8),
                      itemCount: types.length,
                      itemBuilder: (_, i) => item(types[i], 34),
                    ),
                  ),
                  toggle,
                ],
              ),
            ),
    );
  }
}

Future<String> _senderName(Map sender) async {
  final td = accounts.active.td;
  if (sender['@type'] == 'messageSenderUser') {
    final u = await td.request({'@type': 'getUser', 'user_id': sender['user_id']});
    return '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
  }
  final c = await td.request({'@type': 'getChat', 'chat_id': sender['chat_id']});
  return '${c['title'] ?? ''}';
}

Future<void> showReactionUsers(
    BuildContext context, int chatId, int messageId, Map type) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Tg.panel,
    builder: (_) => SafeArea(
      child: FutureBuilder<List<MapEntry<String, Map>>>(
        future: () async {
          final r = await accounts.active.td.request({
            '@type': 'getMessageAddedReactions',
            'chat_id': chatId,
            'message_id': messageId,
            'reaction_type': type,
            'offset': '',
            'limit': 100,
          });
          final out = <MapEntry<String, Map>>[];
          for (final raw in ((r['reactions'] as List?) ?? const [])) {
            final a = raw as Map;
            out.add(MapEntry(await _senderName(a['sender_id'] as Map), a));
          }
          return out;
        }(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()));
          }
          final list = snap.data ?? const <MapEntry<String, Map>>[];
          if (list.isEmpty) {
            return SizedBox(
                height: 120,
                child: Center(
                    child: Text('Нет данных',
                        style: TextStyle(color: Tg.textSecondary))));
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in list)
                  ListTile(
                    title: Text(e.key.isEmpty ? 'Пользователь' : e.key),
                    trailing: ReactionIcon(e.value['type'] as Map, size: 22),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
