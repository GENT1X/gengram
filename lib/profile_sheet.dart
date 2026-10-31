import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'banner.dart';
import 'chat_tools.dart';
import 'gengram_icons.dart';
import 'hidden_chats.dart';
import 'profile_page.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

Future<void> showProfile(BuildContext context, int chatId,
    {bool canWrite = true}) async {
  final chat = await td.request({'@type': 'getChat', 'chat_id': chatId});
  if (!context.mounted) return;
  final t = (chat['type'] as Map?)?['@type'];
  if (chat['@type'] == 'chat' &&
      (t == 'chatTypePrivate' || t == 'chatTypeSecret')) {
    await tgPush(context, ProfilePage(chatId: chatId, canWrite: canWrite));
    return;
  }
  await showProfileSheet(context, chatId);
}

Future<void> showProfileSheet(BuildContext context, int chatId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => _ProfileSheet(chatId: chatId),
  );
}

Future<void> showUserProfile(BuildContext context, int userId) async {
  final chat = await td
      .request({'@type': 'createPrivateChat', 'user_id': userId, 'force': false});
  if (!context.mounted) return;
  if (chat['@type'] != 'chat') {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть профиль')));
    return;
  }
  await showProfile(context, chat['id'] as int);
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _Entry {
  const _Entry({
    required this.title,
    this.subtitle,
    this.chatId,
    this.userId,
  });
  final String title;
  final String? subtitle;
  final int? chatId;
  final int? userId;
}

class _Section {
  const _Section(this.title, this.entries);
  final String title;
  final List<_Entry> entries;
}

class _Profile {
  const _Profile({
    required this.title,
    required this.kind,
    required this.tags,
    required this.rows,
    required this.sections,
    this.photo,
  });
  final Map? photo;
  final String title;
  final String kind;
  final List<String> tags;
  final List<_Row> rows;
  final List<_Section> sections;
}

List<String> _usernames(Map<String, dynamic> m) {
  final un = m['usernames'];
  if (un is Map && un['active_usernames'] is List) {
    return (un['active_usernames'] as List).cast<String>();
  }
  final old = m['username'];
  return (old is String && old.isNotEmpty) ? [old] : [];
}

String? _text(dynamic v) {
  if (v is Map) return v['text'] as String?;
  if (v is String) return v;
  return null;
}

String _userName(Map<String, dynamic> u) {
  final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
  return name.isEmpty ? 'Без имени' : name;
}

String _chatKind(Map<String, dynamic> chat) {
  final t = (chat['type'] as Map?) ?? const {};
  switch (t['@type']) {
    case 'chatTypeSupergroup':
      return t['is_channel'] == true ? 'Канал' : 'Супергруппа';
    case 'chatTypeBasicGroup':
      return 'Группа';
    case 'chatTypePrivate':
    case 'chatTypeSecret':
      return 'Личный чат';
    default:
      return 'Чат';
  }
}

Future<List<_Entry>> _chatEntries(List ids) async {
  final chats = await Future.wait(
      ids.map((id) => td.request({'@type': 'getChat', 'chat_id': id})));
  return [
    for (final c in chats)
      if (c['@type'] == 'chat' && hidden.isVisible(c['id'] as int))
        _Entry(
            title: (c['title'] as String?) ?? 'Без названия',
            subtitle: _chatKind(c),
            chatId: c['id'] as int),
  ];
}

Future<List<_Entry>> _memberEntries(List members) async {
  final ids = <int>[];
  final roles = <int, String>{};
  for (final m in members) {
    final id = (m['member_id'] as Map?)?['user_id'];
    if (id is! int) continue;
    ids.add(id);
    final status = (m['status'] as Map?)?['@type'];
    if (status == 'chatMemberStatusCreator') roles[id] = 'Создатель';
    if (status == 'chatMemberStatusAdministrator') roles[id] = 'Администратор';
  }
  final users = await Future.wait(
      ids.map((id) => td.request({'@type': 'getUser', 'user_id': id})));
  return [
    for (final u in users)
      if (u['@type'] == 'user')
        _Entry(
          title: _userName(u),
          subtitle: roles[u['id']] ??
              (_usernames(u).isEmpty ? null : '@${_usernames(u).first}'),
          userId: u['id'] as int,
        ),
  ];
}

String _countTitle(String name, int shown, dynamic total) =>
    (total is int && total > shown)
        ? '$name (показаны $shown из $total)'
        : '$name ($shown)';

Future<_Profile> _loadProfile(int chatId) async {
  final chat = await td.request({'@type': 'getChat', 'chat_id': chatId});
  final title = (chat['title'] as String?) ?? 'Без названия';
  final type = (chat['type'] as Map?)?.cast<String, dynamic>() ?? const {};
  final rows = <_Row>[];
  final tags = <String>[];
  final sections = <_Section>[];
  var kind = 'Чат';

  void add(String label, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      rows.add(_Row(label, value.trim()));
    }
  }

  void addCount(String label, dynamic n) {
    if (n is int && n > 0) add(label, '$n');
  }

  void addUsernames(Map<String, dynamic> m) {
    final names = _usernames(m);
    if (names.isEmpty) return;
    add(names.length > 1 ? 'Юзернеймы' : 'Юзернейм',
        names.map((n) => '@$n').join(', '));
    add('Ссылка', 'https://t.me/${names.first}');
  }

  switch (type['@type']) {
    case 'chatTypePrivate':
    case 'chatTypeSecret':
      {
        final userId = type['user_id'] as int;
        final res = await Future.wait([
          td.request({'@type': 'getUser', 'user_id': userId}),
          td.request({'@type': 'getUserFullInfo', 'user_id': userId}),
          td.request({
            '@type': 'getGroupsInCommon',
            'user_id': userId,
            'offset_chat_id': 0,
            'limit': 20,
          }),
        ]);
        final user = res[0];
        final full = res[1];
        final common = res[2];

        final ut = (user['type'] as Map?)?['@type'];
        kind = ut == 'userTypeBot'
            ? 'Бот'
            : ut == 'userTypeDeleted'
                ? 'Удалённый аккаунт'
                : 'Пользователь';
        add('ID', '$userId');
        if (type['@type'] == 'chatTypeSecret') add('ID секретного чата', '$chatId');
        addUsernames(user);
        final phone = user['phone_number'] as String?;
        if (phone != null && phone.isNotEmpty) add('Телефон', '+$phone');
        add('О себе', _text(full['bio']));

        final status = user['verification_status'] as Map?;
        if (user['is_contact'] == true) tags.add('В контактах');
        if (user['is_premium'] == true) tags.add('Premium');
        if (user['is_verified'] == true || status?['is_verified'] == true) {
          tags.add('Подтверждён');
        }
        if (user['is_scam'] == true || status?['is_scam'] == true) {
          tags.add('Помечен как мошенник');
        }
        if (user['is_fake'] == true || status?['is_fake'] == true) {
          tags.add('Помечен как фейк');
        }

        final personal = full['personal_chat_id'];
        if (personal is int && personal != 0) {
          final e = await _chatEntries([personal]);
          if (e.isNotEmpty) sections.add(_Section('Личный канал', e));
        }

        final commonIds = common['chat_ids'];
        if (commonIds is List && commonIds.isNotEmpty) {
          final e = await _chatEntries(commonIds);
          if (e.isNotEmpty) {
            sections.add(_Section(
                _countTitle('Общие группы', e.length, common['total_count']), e));
          }
        }
      }
    case 'chatTypeBasicGroup':
      {
        final gid = type['basic_group_id'] as int;
        final res = await Future.wait([
          td.request({'@type': 'getBasicGroup', 'basic_group_id': gid}),
          td.request({'@type': 'getBasicGroupFullInfo', 'basic_group_id': gid}),
        ]);
        final g = res[0];
        final f = res[1];
        kind = 'Группа';
        add('ID', '$chatId');
        addCount('Участников', g['member_count']);
        add('Описание', f['description'] as String?);
        final creator = f['creator_user_id'];
        if (creator is int && creator != 0) add('ID создателя', '$creator');
        add('Ссылка-приглашение',
            (f['invite_link'] as Map?)?['invite_link'] as String?);

        final members = (f['members'] as List?) ?? const [];
        if (members.isNotEmpty) {
          final e = await _memberEntries(members.take(30).toList());
          if (e.isNotEmpty) {
            sections.add(_Section(
                _countTitle('Участники', e.length, g['member_count']), e));
          }
        }
      }
    case 'chatTypeSupergroup':
      {
        final sid = type['supergroup_id'] as int;
        final isChannel = type['is_channel'] == true;
        final res = await Future.wait([
          td.request({'@type': 'getSupergroup', 'supergroup_id': sid}),
          td.request({'@type': 'getSupergroupFullInfo', 'supergroup_id': sid}),
        ]);
        final sg = res[0];
        final f = res[1];
        kind = isChannel
            ? 'Канал'
            : (sg['is_forum'] == true ? 'Группа с темами' : 'Супергруппа');
        add('ID', '$chatId');
        addUsernames(sg);
        addCount(isChannel ? 'Подписчиков' : 'Участников',
            f['member_count'] ?? sg['member_count']);
        addCount('Администраторов', f['administrator_count']);
        add('Описание', f['description'] as String?);
        final linked = f['linked_chat_id'];
        if (linked is int && linked != 0) {
          add(isChannel ? 'ID связанной группы' : 'ID связанного канала',
              '$linked');
        }
        add('Ссылка-приглашение',
            (f['invite_link'] as Map?)?['invite_link'] as String?);

        if (linked is int && linked != 0) {
          final e = await _chatEntries([linked]);
          if (e.isNotEmpty) {
            sections.add(_Section(
                isChannel ? 'Связанная группа' : 'Связанный канал', e));
          }
        }

        if (!isChannel) {
          final r = await td.request({
            '@type': 'getSupergroupMembers',
            'supergroup_id': sid,
            'filter': {'@type': 'supergroupMembersFilterRecent'},
            'offset': 0,
            'limit': 30,
          });
          final ms = r['members'];
          if (ms is List && ms.isNotEmpty) {
            final e = await _memberEntries(ms);
            if (e.isNotEmpty) {
              sections.add(_Section(
                  _countTitle('Участники', e.length, r['total_count']), e));
            }
          }
        }
      }
    default:
      add('ID', '$chatId');
  }

  final pic = chat['photo'] as Map?;
  return _Profile(
      title: title,
      kind: kind,
      tags: tags,
      rows: rows,
      sections: sections,
      photo: (pic?['big'] ?? pic?['small']) as Map?);
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.chatId});
  final int chatId;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final Future<_Profile> _future = _loadProfile(widget.chatId);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_Profile>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
              height: 200,
              child: Center(child: Text('Не удалось загрузить профиль')));
        }
        final p = snap.data;
        if (p == null) {
          return const SizedBox(
              height: 240, child: Center(child: CircularProgressIndicator()));
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BannerView(chatId: widget.chatId),
                const SizedBox(height: 8),
                Center(
                  child: TgAvatar(
                      id: widget.chatId,
                      title: p.title,
                      photo: p.photo,
                      size: 96),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(p.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 2),
                Center(
                  child: Text(p.kind,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
                if (p.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final t in p.tags)
                          Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.perm_media_outlined),
                  title: const Text('Медиа, файлы, ссылки, голосовые'),
                  onTap: () => showChatMedia(context, widget.chatId, p.title),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: const Text('Баннер профиля'),
                  subtitle: const Text('Фото, GIF или видео, только на этом устройстве'),
                  onTap: () => banners.pick(widget.chatId),
                  trailing: IconButton(
                    tooltip: 'Убрать баннер',
                    icon: const Icon(Icons.close),
                    onPressed: () => banners.clear(widget.chatId),
                  ),
                ),
                for (final r in p.rows) _InfoTile(row: r),
                for (final s in p.sections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 4),
                    child: Text(s.title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary)),
                  ),
                  for (final e in s.entries) _EntryTile(entry: e),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatefulWidget {
  const _InfoTile({required this.row});
  final _Row row;

  @override
  State<_InfoTile> createState() => _InfoTileState();
}

class _InfoTileState extends State<_InfoTile> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.row.value));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: _copy,
      title: Text(widget.row.label,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      subtitle: Text(widget.row.value,
          style: TextStyle(fontSize: 16, color: scheme.onSurface)),
      trailing: GenIcon(_copied ? GIcon.check : GIcon.copy,
          size: 20, color: _copied ? scheme.primary : scheme.onSurfaceVariant),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final _Entry entry;

  Future<void> _open(BuildContext context) async {
    final chatId = entry.chatId;
    if (chatId != null) {
      await showProfile(context, chatId);
      return;
    }
    final userId = entry.userId;
    if (userId != null) await showUserProfile(context, userId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _open(context),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Text(entry.title.characters.firstOrNull ?? '?',
            style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
      trailing: GenIcon(GIcon.chevron, color: scheme.onSurfaceVariant),
    );
  }
}
