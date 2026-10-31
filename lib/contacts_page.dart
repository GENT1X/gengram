import 'package:flutter/material.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'chat_picker.dart';
import 'gengram_icons.dart';
import 'premium.dart';
import 'tg_settings.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

Future<void> sendGiftFlow(BuildContext context) async {
  final chat = await pickChat(context, title: 'Кому отправить подарок?');
  if (chat == null || !context.mounted) return;
  await showGiftSheet(context,
      chatId: chat['id'] as int, chatTitle: chat['title'] as String);
}

String _statusOf(Map? status) {
  switch (status?['@type']) {
    case 'userStatusOnline':
      return 'в сети';
    case 'userStatusOffline':
      final t = status?['was_online'] as int?;
      return (t == null || t == 0) ? 'был(а) давно' : tgLastSeen(t);
    case 'userStatusRecently':
      return 'был(а) недавно';
    case 'userStatusLastWeek':
      return 'был(а) на этой неделе';
    case 'userStatusLastMonth':
      return 'был(а) в этом месяце';
    default:
      return 'был(а) давно';
  }
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key, required this.onOpen});

  final void Function(Map<String, dynamic> chat) onOpen;

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>>? _users;
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
    final r = await td.request({'@type': 'getContacts'});
    final ids = (r['user_ids'] as List?) ?? const [];
    final users = await Future.wait([
      for (final id in ids) td.request({'@type': 'getUser', 'user_id': id}),
    ]);
    if (!mounted) return;
    final list = [
      for (final u in users)
        if (u['@type'] == 'user') u,
    ]..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
    setState(() => _users = list);
  }

  static String _name(Map<String, dynamic> u) =>
      '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();

  Future<void> _open(Map<String, dynamic> user) async {
    final chat = await td.request({
      '@type': 'createPrivateChat',
      'user_id': user['id'],
      'force': false,
    });
    if (chat['@type'] == 'chat') {
      widget.onOpen(chat);
    } else {
      tgToast('Не получилось открыть чат');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final users = [
      for (final u in _users ?? const <Map<String, dynamic>>[])
        if (q.isEmpty || _name(u).toLowerCase().contains(q)) u,
    ];
    return Scaffold(
      backgroundColor: Tg.panel,
      appBar: AppBar(title: const Text('Контакты')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по контактам',
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: TgIcon(GIcon.search, size: 20, color: Tg.textSecondary),
                ),
              ),
            ),
          ),
          Expanded(
            child: _users == null
                ? Center(child: CircularProgressIndicator(color: Tg.link))
                : users.isEmpty
                    ? Center(
                        child: Text('Контактов нет',
                            style: TextStyle(color: Tg.textSecondary)))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final status = _statusOf(u['status'] as Map?);
                          return ListTile(
                            leading: TgAvatar(
                                id: u['id'] as int,
                                title: _name(u),
                                photo: u['profile_photo']?['small'] as Map?,
                                size: 46),
                            title: Text(_name(u),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(status,
                                style: TextStyle(
                                    color: status == 'в сети'
                                        ? Tg.link
                                        : Tg.textSecondary)),
                            onTap: () => _open(u),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class MyProfileTab extends StatefulWidget {
  const MyProfileTab({super.key});

  @override
  State<MyProfileTab> createState() => _MyProfileTabState();
}

class _MyProfileTabState extends State<MyProfileTab> {
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final id = accounts.active.me?['id'];
    if (id is! int) return;
    final r = await td.request({'@type': 'getUserFullInfo', 'user_id': id});
    if (!mounted || r['@type'] == 'error') return;
    final b = r['bio'];
    setState(() => _bio = b is Map ? '${b['text'] ?? ''}' : '${b ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([accounts, premium]),
      builder: (context, _) {
        final a = accounts.active;
        final me = a.me;
        final themed = premium.isOn(a.id);
        return Scaffold(
          backgroundColor: Tg.bg,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                decoration: BoxDecoration(
                  color: Tg.panel,
                  gradient: themed
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: premiumThemes[premium.themeOf(a.id)])
                      : null,
                ),
                child: Column(
                  children: [
                    TgAvatar(
                      id: (me?['id'] as int?) ?? 0,
                      title: a.name,
                      photo: me?['profile_photo']?['big'] as Map? ??
                          me?['profile_photo']?['small'] as Map?,
                      size: 108,
                    ),
                    const SizedBox(height: 14),
                    AccountName(a,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Tg.text)),
                    const SizedBox(height: 4),
                    Text(
                        [a.phone, a.username]
                            .where((e) => e.isNotEmpty)
                            .join('  ·  '),
                        style: TextStyle(
                            fontSize: 15,
                            color: themed
                                ? const Color(0xCCFFFFFF)
                                : Tg.textSecondary)),
                    if (_bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Tg.text)),
                    ],
                  ],
                ),
              ),
              TgSection(children: [
                TgRow(
                  title: 'Изменить профиль',
                  icon: GIcon.edit,
                  iconColor: const Color(0xFF5288C1),
                  onTap: () => tgPush(context, const EditProfilePage()),
                ),
                TgRow(
                  title: 'Premium',
                  icon: GIcon.star,
                  iconColor: const Color(0xFF8A4FE0),
                  onTap: () => tgPush(context, const PremiumPage()),
                ),
                TgRow(
                  title: 'Звёзды и подарки',
                  icon: GIcon.coin,
                  iconColor: const Color(0xFFE0A02E),
                  value: '${premium.starsOf()}',
                  onTap: () => tgPush(context, const StarsPage()),
                ),
                TgRow(
                  title: 'Отправить подарок',
                  icon: GIcon.gift,
                  iconColor: const Color(0xFFE08A2E),
                  onTap: () => sendGiftFlow(context),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
