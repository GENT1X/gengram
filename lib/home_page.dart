import 'dart:async';

import 'package:flutter/material.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'chat_lock.dart';
import 'chat_page.dart';
import 'chat_tools.dart';
import 'notifier.dart';
import 'contacts_page.dart';
import 'extras.dart';
import 'gengram_icons.dart';
import 'hidden_chats.dart';
import 'premium.dart';
import 'profile_sheet.dart';
import 'settings_page.dart';
import 'tg_settings.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';
import 'topics_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _openId;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    notifier.requestOpen.addListener(_openRequested);
  }

  @override
  void dispose() {
    notifier.requestOpen.removeListener(_openRequested);
    super.dispose();
  }

  Future<void> _openRequested() async {
    final id = notifier.requestOpen.value;
    if (id == null) return;
    notifier.requestOpen.value = null;
    final chat = await td.request({'@type': 'getChat', 'chat_id': id});
    if (!mounted || chat['@type'] != 'chat') return;
    _open(chat, MediaQuery.sizeOf(context).width >= 700);
  }

  Future<void> _open(Map<String, dynamic> chat, bool wide) async {
    final id = chat['id'] as int;
    final title = chat['title'] as String;
    if (!await chatLock.ensure(context, id)) return;
    if (!mounted) return;
    if (await isForumChat(chat)) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TopicsPage(chatId: id, title: title),
      ));
      return;
    }
    if (wide) {
      setState(() => _openId = id);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Theme(
        data: Tg.theme,
        child: ChatPage(chatId: id, title: title),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 700;
      if (!wide) {
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              ChatListPane(
                  selectedId: null, onOpen: (chat) => _open(chat, false)),
              ContactsPage(onOpen: (chat) => _open(chat, false)),
              const TgSettingsPage(),
              const MyProfileTab(),
            ],
          ),
          bottomNavigationBar: ListenableBuilder(
            listenable: accounts,
            builder: (context, _) {
              final unread = accounts.active.unread;
              return NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 999 ? '999+' : '$unread'),
                      child: const TgIcon(GIcon.chat),
                    ),
                    label: 'Чаты',
                  ),
                  const NavigationDestination(
                      icon: TgIcon(GIcon.group), label: 'Контакты'),
                  const NavigationDestination(
                      icon: TgIcon(GIcon.sliders), label: 'Настройки'),
                  const NavigationDestination(
                      icon: TgIcon(GIcon.user), label: 'Профиль'),
                ],
              );
            },
          ),
        );
      }
      final listWidth = (c.maxWidth * 0.3).clamp(320.0, 420.0).toDouble();
      final open = _openId;
      return Row(
        children: [
          SizedBox(
            width: listWidth,
            child: ChatListPane(
                selectedId: open, onOpen: (chat) => _open(chat, true)),
          ),
          VerticalDivider(width: 1, thickness: 1, color: Tg.bg),
          Expanded(
            child: open == null
                ? const _EmptyChat()
                : ChatPage(
                    key: ValueKey(open),
                    chatId: open,
                    title: '',
                    onClose: () => setState(() => _openId = null),
                  ),
          ),
        ],
      );
    });
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tg.bg,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Tg.panel.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text('Выберите, кому написать',
            style: TextStyle(fontSize: 14, color: Tg.textSecondary)),
      ),
    );
  }
}

class ChatListPane extends StatefulWidget {
  const ChatListPane({super.key, required this.selectedId, required this.onOpen});

  final int? selectedId;
  final void Function(Map<String, dynamic> chat) onOpen;

  @override
  State<ChatListPane> createState() => _ChatListPaneState();
}

class _ChatListPaneState extends State<ChatListPane> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _query = TextEditingController();
  final Map<int, Map<String, dynamic>> _cache = {};
  StreamSubscription? _sub;
  bool _searching = false;
  bool _loadingMore = false;
  bool _allLoaded = false;
  bool _loaded = false;

  int _sel = -1;

  @override
  void initState() {
    super.initState();
    _sub = td.updates.listen(_onUpdate);
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rebuild?.cancel();
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  // ---------- Данные ----------

  Map<String, dynamic> get _chatList => _sel == -1
      ? {'@type': 'chatListMain'}
      : (_sel == -2
          ? {'@type': 'chatListArchive'}
          : {'@type': 'chatListFolder', 'chat_folder_id': _sel});

  void _select(int sel) {
    if (sel == _sel) return;
    setState(() {
      _sel = sel;
      _loaded = false;
      _allLoaded = false;
    });
    _load();
  }

  Future<void> _load() async {
    await td.request({
      '@type': 'loadChats',
      'chat_list': _chatList,
      'limit': 100,
    });
    await _pullIds(500);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _pullIds(int limit) async {
    final ids = await td.request({
      '@type': 'getChats',
      'chat_list': _chatList,
      'limit': limit,
    });
    final missing = [
      for (final id in (ids['chat_ids'] as List? ?? []))
        if (!_cache.containsKey(id as int)) id,
    ];
    final fetched = await Future.wait([
      for (final id in missing) td.request({'@type': 'getChat', 'chat_id': id}),
    ]);
    if (!mounted) return;
    setState(() {
      for (final c in fetched) {
        if (c['@type'] == 'chat') _cache[c['id'] as int] = c;
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _allLoaded) return;
    _loadingMore = true;
    final r = await td.request({
      '@type': 'loadChats',
      'chat_list': _chatList,
      'limit': 50,
    });
    if (r['@type'] == 'error') {
      _allLoaded = true;
    } else {
      await _pullIds(2000);
    }
    _loadingMore = false;
  }

  Timer? _rebuild;

  void _scheduleRebuild() {
    if (_rebuild?.isActive ?? false) return;
    _rebuild = Timer(const Duration(milliseconds: 80), () {
      if (mounted) setState(() {});
    });
  }

  void _patch(int chatId, void Function(Map<String, dynamic> chat) change) {
    final chat = _cache[chatId];
    if (chat == null) return;
    change(chat);
    _scheduleRebuild();
  }

  void _onUpdate(Map<String, dynamic> u) {
    if (!mounted) return;
    switch (u['@type']) {
      case 'updateNewChat':
        {
          final chat = u['chat'] as Map<String, dynamic>;
          _cache[chat['id'] as int] = chat;
          _scheduleRebuild();
        }
      case 'updateChatLastMessage':
        _patch(u['chat_id'] as int, (c) {
          c['last_message'] = u['last_message'];
          c['positions'] = u['positions'];
        });
      case 'updateChatPosition':
        _patch(u['chat_id'] as int, (c) {
          final pos = u['position'] as Map;
          final rest = ((c['positions'] as List?) ?? [])
              .where((p) => !_sameList(p['list'] as Map, pos['list'] as Map))
              .toList();
          if (_orderOf(pos) != 0) rest.add(pos);
          c['positions'] = rest;
        });
      case 'updateChatReadInbox':
        _patch(u['chat_id'] as int, (c) {
          c['unread_count'] = u['unread_count'];
          c['last_read_inbox_message_id'] = u['last_read_inbox_message_id'];
        });
      case 'updateChatReadOutbox':
        _patch(u['chat_id'] as int,
            (c) => c['last_read_outbox_message_id'] = u['last_read_outbox_message_id']);
      case 'updateChatIsMarkedAsUnread':
        _patch(u['chat_id'] as int,
            (c) => c['is_marked_as_unread'] = u['is_marked_as_unread']);
      case 'updateChatTitle':
        _patch(u['chat_id'] as int, (c) => c['title'] = u['title']);
      case 'updateChatPhoto':
        _patch(u['chat_id'] as int, (c) => c['photo'] = u['photo']);
      case 'updateChatNotificationSettings':
        _patch(u['chat_id'] as int,
            (c) => c['notification_settings'] = u['notification_settings']);
    }
  }

  static bool _sameList(Map a, Map b) =>
      a['@type'] == b['@type'] && a['chat_folder_id'] == b['chat_folder_id'];

  Map? _position(Map<String, dynamic> chat) {
    final want = _chatList;
    for (final p in (chat['positions'] as List? ?? [])) {
      if (_sameList(p['list'] as Map, want)) return p as Map;
    }
    return null;
  }

  static int _orderOf(Map pos) => int.tryParse('${pos['order']}') ?? 0;

  List<Map<String, dynamic>> _sorted() {
    final q = _query.text.trim().toLowerCase();
    final withOrder = <(int, Map<String, dynamic>)>[];
    for (final chat in _cache.values) {
      final pos = _position(chat);
      if (pos == null) continue;
      final order = _orderOf(pos);
      if (order == 0) continue;
      if (!hidden.isVisible(chat['id'] as int)) continue;
      if (q.isNotEmpty &&
          !(chat['title'] as String).toLowerCase().contains(q)) {
        continue;
      }
      withOrder.add((order, chat));
    }
    withOrder.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in withOrder) e.$2];
  }

  bool _isPinned(Map<String, dynamic> chat) {
    for (final p in ((chat['positions'] as List?) ?? const [])) {
      if (p is Map && p['list']?['@type'] == 'chatListMain') {
        return p['is_pinned'] == true;
      }
    }
    return false;
  }

  bool _isArchived(Map<String, dynamic> chat) {
    for (final p in ((chat['positions'] as List?) ?? const [])) {
      if (p is Map && p['list']?['@type'] == 'chatListArchive') return true;
    }
    return false;
  }

  Future<void> _chatAction(Map<String, dynamic> chat, String action) async {
    final id = chat['id'];
    final ns = Map<String, dynamic>.from(
        (chat['notification_settings'] as Map?)?.cast<String, dynamic>() ?? {});
    final muted = ((ns['mute_for'] as int?) ?? 0) > 0;
    Map<String, dynamic> r = {};
    switch (action) {
      case 'pin':
        r = await td.request({
          '@type': 'toggleChatIsPinned',
          'chat_list': {'@type': _isArchived(chat) ? 'chatListArchive' : 'chatListMain'},
          'chat_id': id,
          'is_pinned': !_isPinned(chat),
        });
      case 'mute':
        ns['@type'] = 'chatNotificationSettings';
        ns['use_default_mute_for'] = false;
        ns['mute_for'] = muted ? 0 : 2147483647;
        r = await td.request({
          '@type': 'setChatNotificationSettings',
          'chat_id': id,
          'notification_settings': ns,
        });
      case 'archive':
        r = await td.request({
          '@type': 'addChatToList',
          'chat_id': id,
          'chat_list': {
            '@type': _isArchived(chat) ? 'chatListMain' : 'chatListArchive'
          },
        });
      case 'unread':
        r = await td.request({
          '@type': 'toggleChatIsMarkedAsUnread',
          'chat_id': id,
          'is_marked_as_unread': chat['is_marked_as_unread'] != true,
        });
      case 'read':
        {
          final last = chat['last_message']?['id'];
          if (last != null) {
            r = await td.request({
              '@type': 'viewMessages',
              'chat_id': id,
              'message_ids': [last],
              'force_read': true,
            });
          }
          if (chat['is_marked_as_unread'] == true) {
            r = await td.request({
              '@type': 'toggleChatIsMarkedAsUnread',
              'chat_id': id,
              'is_marked_as_unread': false,
            });
          }
        }
      case 'clear':
      case 'delete':
        {
          final ok = await tgConfirm(context,
              title: action == 'clear' ? 'Очистить историю?' : 'Удалить чат?',
              text: action == 'clear'
                  ? 'Сообщения исчезнут только у вас.'
                  : 'Чат исчезнет из списка, переписка удалится только у вас.',
              yes: action == 'clear' ? 'Очистить' : 'Удалить',
              danger: true);
          if (!ok) return;
          r = await td.request({
            '@type': 'deleteChatHistory',
            'chat_id': id,
            'remove_from_chat_list': action == 'delete',
            'revoke': false,
          });
        }
    }
    if (r['@type'] == 'error') tgToast('Не получилось: ${r['message']}');
  }

  Future<void> _chatMenu(Map<String, dynamic> chat) async {
    final id = chat['id'] as int;
    final isHidden = settings.hiddenIds.contains(id);
    final muted = (((chat['notification_settings'] as Map?)?['mute_for']) as int? ?? 0) > 0;
    final unreadMark = chat['is_marked_as_unread'] == true ||
        ((chat['unread_count'] as int?) ?? 0) > 0;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
         child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(_isPinned(chat) ? 'Открепить' : 'Закрепить'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            ListTile(
              leading: Icon(muted ? Icons.notifications_none : Icons.notifications_off_outlined),
              title: Text(muted ? 'Включить уведомления' : 'Отключить уведомления'),
              onTap: () => Navigator.pop(ctx, 'mute'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(_isArchived(chat) ? 'Вернуть из архива' : 'В архив'),
              onTap: () => Navigator.pop(ctx, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_outlined),
              title: Text(unreadMark ? 'Прочитать' : 'Отметить непрочитанным'),
              onTap: () => Navigator.pop(ctx, unreadMark ? 'read' : 'unread'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Очистить историю'),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Tg.danger),
              title: const Text('Удалить чат', style: TextStyle(color: Tg.danger)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: GenIcon(isHidden ? GIcon.eye : GIcon.eyeOff),
              title: Text(isHidden ? 'Убрать из скрытых' : 'Скрыть чат'),
              subtitle: Text(isHidden
                  ? 'Чат снова будет виден в списке.'
                  : 'Чат пропадёт из списка. Вернуть его можно жестом, который выбран в настройках.'),
              onTap: () => Navigator.pop(ctx, isHidden ? 'unhide' : 'hide'),
            ),
            ListTile(
              leading: const TgIcon(GIcon.info),
              title: const Text('Профиль'),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
          ],
         ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') {
      showProfile(context, id);
      return;
    }
    if (!const ['hide', 'unhide'].contains(action)) {
      await _chatAction(chat, action);
      return;
    }
    await settings.setHidden(id, action == 'hide');
    if (action == 'hide') {
      hidden.conceal();
      messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Чат скрыт')));
    }
  }

  void _openSettings() => tgPush(context, const TgSettingsPage());

  PreferredSizeWidget _appBar() {
    if (_searching) {
      return AppBar(
        leading: IconButton(
          icon: const TgIcon(GIcon.back),
          onPressed: () => setState(() {
            _searching = false;
            _query.clear();
          }),
        ),
        title: TextField(
          controller: _query,
          autofocus: true,
          style: TextStyle(fontSize: 17, color: Tg.text),
          cursorColor: Tg.link,
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: TextStyle(color: Tg.textSecondary),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const TgIcon(GIcon.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
      );
    }
    return AppBar(
      leading: IconButton(
        tooltip: 'Меню',
        icon: const TgIcon(GIcon.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: () {
          if (settings.revealByTitle) hidden.toggle();
        },
        child: const Text('GenGram'),
      ),
      actions: [
        ListenableBuilder(
          listenable: hidden,
          builder: (context, _) => hidden.revealed
              ? IconButton(
                  tooltip: 'Закрыть скрытые чаты',
                  icon: GenIcon(GIcon.unlock, color: Tg.link),
                  onPressed: hidden.conceal,
                )
              : const SizedBox.shrink(),
        ),
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) => IconButton(
            tooltip: settings.ghost
                ? 'Режим призрака: вкл'
                : 'Режим призрака: выкл',
            icon: GenIcon(settings.ghost ? GIcon.ghost : GIcon.ghostVisible,
                color: settings.ghost ? Tg.link : Tg.textSecondary),
            onPressed: () => applyGhost(!settings.ghost),
          ),
        ),
        IconButton(
          tooltip: 'Поиск по чатам',
          icon: const TgIcon(GIcon.search),
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          tooltip: 'Поиск по всем сообщениям, медиа и ссылкам',
          icon: Icon(Icons.manage_search, color: Tg.textSecondary),
          onPressed: () => tgPush(context, const GlobalSearchPage()),
        ),
      ],
    );
  }

  Widget _drawer() {
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([accounts, settings, premium]),
          builder: (context, _) {
            final active = accounts.active;
            final me = active.me;
            final themed = premium.isOn(active.id);
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Tg.panelOver,
                    gradient: themed
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: premiumThemes[premium.themeOf(active.id)])
                        : null,
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TgAvatar(
                        id: (me?['id'] as int?) ?? 0,
                        title: active.name,
                        photo: me?['profile_photo']?['small'] as Map?,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      AccountName(active,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Tg.text)),
                      if (active.phone.isNotEmpty)
                        Text(active.phone,
                            style: TextStyle(
                                fontSize: 14,
                                color: themed
                                    ? const Color(0xCCFFFFFF)
                                    : Tg.textSecondary)),
                    ],
                  ),
                ),
                for (final a in accounts.list)
                  if (a.id != active.id)
                    ListTile(
                      leading: TgAvatar(id: a.id + 1, title: a.name, size: 40),
                      title: AccountName(a,
                          style: TextStyle(fontSize: 15, color: Tg.text)),
                      subtitle: Text(
                          a.ready
                              ? (a.phone.isEmpty ? a.username : a.phone)
                              : 'нужно войти',
                          style: TextStyle(
                              fontSize: 13, color: Tg.textSecondary)),
                      trailing: a.unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Tg.badge,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('${a.unread}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        accounts.switchTo(a.id);
                      },
                    ),
                ListTile(
                  leading: const TgIcon(GIcon.plus),
                  title: const Text('Добавить аккаунт'),
                  onTap: () {
                    Navigator.pop(context);
                    accounts.addAccount();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.bookmark_border, color: Tg.textSecondary),
                  title: const Text('Избранное'),
                  onTap: () {
                    Navigator.pop(context);
                    openFavorites(widget.onOpen);
                  },
                ),
                ListTile(
                  leading: const TgIcon(GIcon.plus),
                  title: const Text('Новая группа или канал'),
                  onTap: () {
                    Navigator.pop(context);
                    showNewChatDialog(this.context, widget.onOpen);
                  },
                ),
                ListTile(
                  leading: const TgIcon(GIcon.group),
                  title: const Text('Контакты'),
                  onTap: () {
                    Navigator.pop(context);
                    tgPush(
                        this.context,
                        ContactsPage(onOpen: (chat) {
                          Navigator.of(this.context).pop();
                          widget.onOpen(chat);
                        }));
                  },
                ),
                ListTile(
                  leading: const TgIcon(GIcon.user),
                  title: const Text('Настройки'),
                  onTap: () {
                    Navigator.pop(context);
                    _openSettings();
                  },
                ),
                ListTile(
                  leading: const PremiumStar(size: 22),
                  title: const Text('Premium'),
                  onTap: () {
                    Navigator.pop(context);
                    tgPush(this.context, const PremiumPage());
                  },
                ),
                ListTile(
                  leading: const StarCoin(size: 22),
                  title: const Text('Звёзды и подарки'),
                  trailing: Text('${premium.starsOf()}',
                      style: TextStyle(color: Tg.textSecondary)),
                  onTap: () {
                    Navigator.pop(context);
                    tgPush(this.context, const StarsPage());
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: GenIcon(
                      settings.ghost ? GIcon.ghost : GIcon.ghostVisible,
                      color: settings.ghost ? Tg.link : Tg.textSecondary),
                  title: const Text('Режим призрака'),
                  value: settings.ghost,
                  onChanged: (v) => applyGhost(v),
                ),
                ListTile(
                  leading: const GenIcon(GIcon.sliders),
                  title: const Text('Настройки GenGram'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(this.context).push(MaterialPageRoute(
                        builder: (_) => const SettingsPage()));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Tg.panel,
      appBar: _appBar(),
      drawer: _drawer(),
      body: Column(
        children: [
          _folderBar(),
          const StoriesBar(),
          Expanded(child: _chatsBody()),
        ],
      ),
    );
  }

  Widget _folderBar() {
    return ListenableBuilder(
      listenable: accounts,
      builder: (context, _) {
        final folders = accounts.active.folders;
        Widget chip(String label, int sel) => GestureDetector(
              onTap: () => _select(sel),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _sel == sel ? Tg.selected : Tg.panelOver,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _sel == sel ? Colors.white : Tg.textSecondary)),
              ),
            );
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
            children: [
              chip('Все', -1),
              for (final f in folders)
                chip(folderTitle(f), (f['id'] as int?) ?? 0),
              chip('Архив', -2),
            ],
          ),
        );
      },
    );
  }

  Widget _chatsBody() {
    return ListenableBuilder(
        listenable: Listenable.merge([hidden, settings]),
        builder: (context, _) {
          final chats = _sorted();
          if (chats.isEmpty) {
            return Center(
              child: _loaded
                  ? Text(_query.text.isEmpty ? 'Чатов пока нет' : 'Ничего не найдено',
                      style: TextStyle(color: Tg.textSecondary))
                  : CircularProgressIndicator(color: Tg.link),
            );
          }
          return ListView.builder(
            controller: _scroll,
            itemCount: chats.length,
            itemBuilder: (context, i) {
              final chat = chats[i];
              final id = chat['id'] as int;
              return _ChatTile(
                chat: chat,
                selected: id == widget.selectedId,
                isHidden: settings.hiddenIds.contains(id),
                pinned: _position(chat)?['is_pinned'] == true,
                onTap: () => widget.onOpen(chat),
                onMenu: () => _chatMenu(chat),
              );
            },
          );
        },
    );
  }
}

String folderTitle(Map f) {
  final n = f['name'] ?? f['title'];
  if (n is Map) {
    final t = n['text'];
    return t is Map ? '${t['text'] ?? ''}' : '${t ?? ''}';
  }
  return '${n ?? 'Папка'}';
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.selected,
    required this.isHidden,
    required this.pinned,
    required this.onTap,
    required this.onMenu,
  });

  final Map<String, dynamic> chat;
  final bool selected;
  final bool isHidden;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final id = chat['id'] as int;
    final title = chat['title'] as String;
    final last = chat['last_message'] as Map?;
    final unread = (chat['unread_count'] as int?) ?? 0;
    final marked = chat['is_marked_as_unread'] == true;
    final muted =
        ((chat['notification_settings']?['mute_for'] as int?) ?? 0) > 0;
    final mine = last?['is_outgoing'] == true;
    final read = mine &&
        ((last?['id'] as int?) ?? 0) <=
            ((chat['last_read_outbox_message_id'] as int?) ?? 0);
    final sending = last?['sending_state'] != null;

    final fg = selected ? Colors.white : Tg.text;
    final dim = selected ? Colors.white70 : Tg.textSecondary;

    String preview = '';
    if (last != null) {
      preview = messageText(last['content'] as Map).replaceAll('\n', ' ');
      if (mine) preview = 'Вы: $preview';
    }

    final Widget? badge = unread > 0 || marked
        ? Container(
            constraints: const BoxConstraints(minWidth: 22),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: muted && !selected ? Tg.badgeMuted : (selected ? Colors.white : Tg.badge),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(unread > 0 ? (unread > 999 ? '999+' : '$unread') : '',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Tg.selected : Colors.white)),
          )
        : (pinned ? TgIcon(GIcon.pin, size: 18, color: dim) : null);

    return Material(
      color: selected ? Tg.selected : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        onSecondaryTap: onMenu,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              TgAvatar(
                  id: id,
                  title: title,
                  photo: chat['photo']?['small'] as Map?,
                  size: 54),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: fg)),
                          ),
                          if (muted) ...[
                            const SizedBox(width: 4),
                            TgIcon(GIcon.muted, size: 15, color: dim),
                          ],
                          if (isHidden) ...[
                            const SizedBox(width: 4),
                            GenIcon(GIcon.eyeOff, size: 15, color: dim),
                          ],
                          const Spacer(),
                          if (mine) ...[
                            TgIcon(
                                sending
                                    ? GIcon.clock
                                    : (read ? GIcon.doubleCheck : GIcon.check),
                                size: 16,
                                color: selected ? Colors.white : Tg.link),
                            const SizedBox(width: 3),
                          ],
                          if (last != null)
                            Text(tgListTime(last['date'] as int),
                                style: TextStyle(fontSize: 13, color: dim)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, color: dim)),
                          ),
                          if (badge != null) ...[const SizedBox(width: 8), badge],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
