import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/services.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'chat_lock.dart';
import 'chat_picker.dart';
import 'chat_tools.dart';
import 'notifier.dart';
import 'doodle.dart';
import 'extras.dart';
import 'gengram_icons.dart';
import 'hidden_chats.dart';
import 'local_emoji.dart';
import 'message_filters.dart';
import 'input_panel.dart';
import 'media.dart';
import 'message_store.dart';
import 'message_view.dart';
import 'premium.dart';
import 'profile_sheet.dart';
import 'polls.dart';
import 'reactions.dart';
import 'topics_page.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';
import 'trash_icon.dart';

class _Item {
  _Item({
    required this.id,
    required this.date,
    required this.text,
    required this.mine,
    required this.senderKey,
    this.senderId,
    this.sending = false,
    this.deletedAt,
    this.gift,
    this.msg,
  });

  final LocalGift? gift;
  final Map<String, dynamic>? msg;
  final int id;
  final int date;
  final String text;
  final bool mine;
  final String senderKey;
  final int? senderId;
  final bool sending;
  final int? deletedAt;
}

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    required this.title,
    this.onClose,
    this.topicId,
    this.topicName,
  });

  final int chatId;
  final String title;
  final int? topicId;
  final String? topicName;
  final VoidCallback? onClose;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _messages = []; // новые сверху
  Map<String, dynamic>? _chat;
  String _title = '';
  String _status = '';
  bool _isGroup = false;
  bool _isChannel = false;
  int? _peerUserId;
  int _lastReadOutbox = 0;
  bool _loadingOlder = false;
  bool _noMoreOlder = false;
  bool _hasText = false;
  bool _panelOpen = false;
  Map<String, dynamic>? _replyTo;
  String? _quote;
  int? _topicId;
  String? _topicName;
  bool _isForum = false;
  final Map<int, Map<String, dynamic>> _users = {};
  final Set<int> _loadingUsers = {};
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _topicId = widget.topicId;
    _topicName = widget.topicName;
    hidden.addListener(_guardHidden);
    premium.addListener(_onPremium);
    settings.addListener(_onPremium);
    messageFilters.addListener(_onPremium);
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() {
      if (_focus.hasFocus && _panelOpen) setState(() => _panelOpen = false);
    });
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadOlder();
      }
    });
    notifier.openChatId = widget.chatId;
    _loadChat();
    _loadInitial();
    _sub = td.updates.listen(_onUpdate);
  }

  @override
  void dispose() {
    if (notifier.openChatId == widget.chatId) notifier.openChatId = null;
    hidden.removeListener(_guardHidden);
    premium.removeListener(_onPremium);
    settings.removeListener(_onPremium);
    messageFilters.removeListener(_onPremium);
    _sub?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onPremium() {
    if (mounted) setState(() {});
  }

  void _onUpdate(Map<String, dynamic> u) {
    if (!mounted) return;
    switch (u['@type']) {
      case 'updateNewMessage':
        {
          final m = u['message'] as Map<String, dynamic>;
          if (m['chat_id'] == widget.chatId &&
              _inTopic(m) &&
              !_messages.any((x) => x['id'] == m['id'])) {
            setState(() => _messages.insert(0, m));
            _markRead([m['id']]);
          }
        }
      case 'updateMessageSendSucceeded':
        final sent = u['message'] as Map<String, dynamic>;
        if (sent['chat_id'] == widget.chatId) {
          localEmoji.settle(
              widget.chatId, u['old_message_id'] as int, sent['id'] as int);
          setState(() {
            final i = _messages.indexWhere((x) => x['id'] == u['old_message_id']);
            if (i >= 0) {
              _messages[i] = sent;
            } else if (_inTopic(sent) &&
                !_messages.any((x) => x['id'] == sent['id'])) {
              _messages.insert(0, sent);
            }
          });
        }
      case 'updateMessageContent':
        if (u['chat_id'] == widget.chatId) {
          setState(() {
            for (final m in _messages) {
              if (m['id'] == u['message_id']) m['content'] = u['new_content'];
            }
          });
        }
      case 'updateMessageInteractionInfo':
        if (u['chat_id'] == widget.chatId) {
          setState(() {
            for (final m in _messages) {
              if (m['id'] == u['message_id']) {
                m['interaction_info'] = u['interaction_info'];
              }
            }
          });
        }
      case 'updateDeleteMessages':
        if (u['chat_id'] == widget.chatId &&
            u['is_permanent'] == true &&
            u['from_cache'] != true) {
          setState(() {
            if (!settings.saveDeleted) {
              final ids = (u['message_ids'] as List).toSet();
              _messages.removeWhere((m) => ids.contains(m['id']));
            }
          });
        }
      case 'updateChatReadOutbox':
        if (u['chat_id'] == widget.chatId) {
          setState(() => _lastReadOutbox = u['last_read_outbox_message_id'] as int);
        }
      case 'updateChatTitle':
        if (u['chat_id'] == widget.chatId) setState(() => _title = u['title'] as String);
      case 'updateUserStatus':
        if (u['user_id'] == _peerUserId) {
          setState(() => _status = _statusText(u['status'] as Map));
        }
    }
  }

  bool _inTopic(Map m) =>
      _topicId == null ||
      (m['topic_id'] as Map?)?['forum_topic_id'] == _topicId;

  Future<void> _pickTopic() async {
    final c = await showTopicPicker(context, widget.chatId);
    if (c == null || !mounted || c.id == _topicId) return;
    setState(() {
      _topicId = c.id;
      _topicName = c.name;
      _messages = [];
      _noMoreOlder = false;
    });
    _loadInitial();
  }

  void _guardHidden() {
    if (!mounted || hidden.isVisible(widget.chatId)) return;
    final close = widget.onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ---------- Данные ----------

  Future<void> _loadChat() async {
    final chat = await td.request({'@type': 'getChat', 'chat_id': widget.chatId});
    if (!mounted || chat['@type'] != 'chat') return;
    final type = chat['type'] as Map;
    String status = '';
    bool group = false, channel = false, forum = false;
    int? peer;
    switch (type['@type']) {
      case 'chatTypePrivate':
      case 'chatTypeSecret':
        {
          peer = type['user_id'] as int;
          final user = await td.request({'@type': 'getUser', 'user_id': peer});
          if (user['@type'] == 'user') {
            status = user['type']?['@type'] == 'userTypeBot'
                ? 'бот'
                : _statusText(user['status'] as Map? ?? const {});
          }
        }
      case 'chatTypeBasicGroup':
        {
          group = true;
          final g = await td.request({
            '@type': 'getBasicGroup',
            'basic_group_id': type['basic_group_id']
          });
          final n = g['member_count'] as int?;
          if (n != null) {
            status = '$n ${tgPlural(n, 'участник', 'участника', 'участников')}';
          }
        }
      case 'chatTypeSupergroup':
        {
          final g = await td.request({
            '@type': 'getSupergroup',
            'supergroup_id': type['supergroup_id']
          });
          channel = g['is_channel'] == true;
          group = !channel;
          forum = g['is_forum'] == true;
          final n = g['member_count'] as int?;
          if (n != null && n > 0) {
            status = channel
                ? '$n ${tgPlural(n, 'подписчик', 'подписчика', 'подписчиков')}'
                : '$n ${tgPlural(n, 'участник', 'участника', 'участников')}';
          } else {
            status = channel ? 'канал' : 'группа';
          }
        }
    }
    if (!mounted) return;
    setState(() {
      _chat = chat;
      _title = chat['title'] as String;
      _status = status;
      _isGroup = group;
      _isChannel = channel;
      _isForum = forum;
      _peerUserId = peer;
      _lastReadOutbox = (chat['last_read_outbox_message_id'] as int?) ?? 0;
    });
  }

  String _statusText(Map status) {
    switch (status['@type']) {
      case 'userStatusOnline':
        return 'в сети';
      case 'userStatusOffline':
        final t = status['was_online'] as int?;
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

  Future<void> _loadInitial() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await _fetchOlder();
      if (!mounted || _messages.length >= 30 || _noMoreOlder) break;
    }
    if (!mounted) return;
    _markRead(_messages.map((m) => m['id']).toList());
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _noMoreOlder) return;
    await _fetchOlder();
  }

  Future<void> _fetchOlder() async {
    if (_loadingOlder) return;
    _loadingOlder = true;
    final from = _messages.isEmpty ? 0 : _messages.last['id'] as int;
    final topic = _topicId;
    final r = await td.request(topic == null
        ? {
            '@type': 'getChatHistory',
            'chat_id': widget.chatId,
            'from_message_id': from,
            'offset': 0,
            'limit': 50,
            'only_local': false,
          }
        : {
            '@type': 'getForumTopicHistory',
            'chat_id': widget.chatId,
            'forum_topic_id': topic,
            'from_message_id': from,
            'offset': 0,
            'limit': 50,
          });
    _loadingOlder = false;
    if (!mounted) return;
    final list = ((r['messages'] as List?) ?? []).cast<Map<String, dynamic>>();
    final known = _messages.map((m) => m['id'] as int).toSet();
    final fresh = [for (final m in list) if (!known.contains(m['id'] as int)) m];
    for (final m in fresh) {
      store.remember(m);
    }
    setState(() {
      _messages.addAll(fresh);
      if (fresh.isEmpty) _noMoreOlder = true;
    });
  }

  void _markRead(List ids) {
    if (settings.noReadIn(widget.chatId) || ids.isEmpty) return;
    _viewNow(ids);
  }

  void _viewNow(List ids) {
    td.request({
      '@type': 'viewMessages',
      'chat_id': widget.chatId,
      'message_ids': ids,
      'force_read': true,
    });
  }

  void _readNow() {
    final ids = [
      for (final m in _messages)
        if (m['is_outgoing'] != true) m['id']
    ];
    if (ids.isEmpty) {
      tgToast('Нет входящих сообщений');
      return;
    }
    _viewNow(ids.take(100).toList());
    tgToast('Отмечено прочитанным');
  }

  Future<void> _sendContent(Map<String, dynamic> content,
      {Map<String, dynamic>? options}) async {
    final reply = _replyTo;
    final quote = _quote;
    if (reply != null) {
      setState(() {
        _replyTo = null;
        _quote = null;
      });
    }
    final r = await td.request({
      '@type': 'sendMessage',
      'chat_id': widget.chatId,
      if (_topicId != null)
        'topic_id': {
          '@type': 'messageTopicForum',
          'forum_topic_id': _topicId,
        },
      if (reply != null)
        'reply_to': {
          '@type': 'inputMessageReplyToMessage',
          'message_id': reply['id'],
          if (quote != null && quote.isNotEmpty)
            'quote': {
              '@type': 'inputTextQuote',
              'text': {'@type': 'formattedText', 'text': quote},
              'position': 0,
            },
        },
      if (options != null || settings.silentSend)
        'options': options ??
            {'@type': 'messageSendOptions', 'disable_notification': true},
      'input_message_content': content,
    });
    final sentText = content['text'];
    if (r['@type'] == 'message' &&
        sentText is Map<String, dynamic> &&
        hasCustomEmoji(sentText)) {
      localEmoji.pend(widget.chatId, r['id'] as int, sentText);
    }
    if (r['@type'] == 'error') {
      tgToast('Не отправилось: ${r['message']}');
    } else if (options?['scheduling_state'] != null) {
      tgToast('Сообщение будет отправлено позже');
    }
  }

  Future<void> _send({Map<String, dynamic>? options}) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _sendContent({
      '@type': 'inputMessageText',
      'text': {'@type': 'formattedText', 'text': text},
    }, options: options);
  }

  Future<void> _sendWithOptions() async {
    if (!_hasText) return;
    final options = await pickSendOptions(context);
    if (options == null) return;
    await _send(options: options);
  }

  Future<void> _headerMenu(String v) async {
    switch (v) {
      case 'profile':
        await showProfile(context, widget.chatId, canWrite: false);
      case 'pinned':
        await showPinnedList(context, widget.chatId);
      case 'scheduled':
        await showScheduledList(context, widget.chatId);
      case 'media':
        await showChatMedia(context, widget.chatId, _title);
      case 'lock':
        await chatLock.setup(context, widget.chatId);
      case 'secret':
        {
          final uid = _peerUserId;
          if (uid == null) return;
          final r = await td
              .request({'@type': 'createNewSecretChat', 'user_id': uid});
          if (r['@type'] == 'error') {
            tgToast('Не получилось: ${r['message']}');
          } else {
            notifier.requestOpen.value = r['id'] as int?;
          }
        }
    }
  }

  Future<void> _attach() async {
    final what = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Tg.panel,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Файл или фото'),
              onTap: () => Navigator.pop(c, 'file')),
          ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: const Text('Опрос'),
              onTap: () => Navigator.pop(c, 'poll')),
        ]),
      ),
    );
    if (!mounted || what == null) return;
    if (what == 'poll') {
      final poll = await showCreatePoll(context);
      if (poll != null) await _sendContent(poll);
      return;
    }
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    final caption = _input.text.trim();
    _input.clear();
    final ext = path.split('.').last.toLowerCase();
    final isPhoto = const ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    final file = {'@type': 'inputFileLocal', 'path': path};
    final cap = {'@type': 'formattedText', 'text': caption};
    await _sendContent(isPhoto
        ? {'@type': 'inputMessagePhoto', 'photo': file, 'caption': cap}
        : {'@type': 'inputMessageDocument', 'document': file, 'caption': cap});
  }

  void _insertEmoji(String e) {
    final t = _input.text;
    final sel = _input.selection;
    final start = sel.isValid ? sel.start : t.length;
    final end = sel.isValid ? sel.end : t.length;
    _input.value = TextEditingValue(
      text: t.replaceRange(start, end, e),
      selection: TextSelection.collapsed(offset: start + e.length),
    );
  }

  void _sendCustomEmoji(Map sticker) {
    final id = (sticker['full_type'] as Map?)?['custom_emoji_id'] ??
        sticker['custom_emoji_id'];
    final emoji = '${sticker['emoji'] ?? '🙂'}';
    if (id == null) return;
    _sendContent({
      '@type': 'inputMessageText',
      'text': {
        '@type': 'formattedText',
        'text': emoji,
        'entities': [
          {
            '@type': 'textEntity',
            'offset': 0,
            'length': emoji.length,
            'type': {'@type': 'textEntityTypeCustomEmoji', 'custom_emoji_id': '$id'},
          }
        ],
      },
    });
  }

  void _sendSticker(Map sticker) {
    _sendContent({
      '@type': 'inputMessageSticker',
      'sticker': {
        '@type': 'inputFileId',
        'id': (sticker['sticker'] as Map)['id'],
      },
      'width': sticker['width'] ?? 0,
      'height': sticker['height'] ?? 0,
      'emoji': sticker['emoji'] ?? '',
    });
  }

  void _sendGif(Map animation) {
    _sendContent({
      '@type': 'inputMessageAnimation',
      'animation': {
        '@type': 'inputFileId',
        'id': (animation['animation'] as Map)['id'],
      },
      'duration': animation['duration'] ?? 0,
      'width': animation['width'] ?? 0,
      'height': animation['height'] ?? 0,
    });
  }

  void _togglePanel() {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _panelOpen = true);
    }
  }

  // ---------- Люди ----------

  Map<String, dynamic>? _user(int? id) {
    if (id == null) return null;
    final known = _users[id];
    if (known != null) return known;
    if (_loadingUsers.add(id)) {
      td.request({'@type': 'getUser', 'user_id': id}).then((u) {
        if (!mounted || u['@type'] != 'user') return;
        setState(() => _users[id] = u);
      });
    }
    return null;
  }

  static String _userName(Map<String, dynamic>? u) =>
      '${u?['first_name'] ?? ''} ${u?['last_name'] ?? ''}'.trim();

  String _authorOf(Map<String, dynamic> m) {
    if (m['is_outgoing'] == true) return 'Вы';
    final sender = m['sender_id'] as Map?;
    if (sender?['@type'] == 'messageSenderUser') {
      final n = _userName(_user(sender!['user_id'] as int));
      if (n.isNotEmpty) return n;
    }
    return _title.isEmpty ? 'Собеседник' : _title;
  }

  (String, String)? _replyInfo(Map<String, dynamic> msg) {
    final r = msg['reply_to'] as Map?;
    if (r == null || r['@type'] != 'messageReplyToMessage') return null;
    final id = r['message_id'];
    for (final m in _messages) {
      if (m['id'] == id) {
        return (_authorOf(m), messageText(m['content'] as Map));
      }
    }
    final c = r['content'];
    if (c is Map) return ('Ответ', messageText(c));
    return ('Ответ', 'Сообщение');
  }

  String? _forwardFrom(Map<String, dynamic> msg) {
    final f = msg['forward_info'] as Map?;
    final o = f?['origin'] as Map?;
    if (o == null) return null;
    switch (o['@type']) {
      case 'messageOriginUser':
        {
          final n = _userName(_user(o['sender_user_id'] as int?));
          return n.isEmpty ? 'Переслано' : 'Переслано от $n';
        }
      case 'messageOriginHiddenUser':
        return 'Переслано от ${o['sender_name'] ?? ''}'.trim();
      default:
        return 'Переслано из чата';
    }
  }

  List<_Item> _items() {
    final showDeleted = settings.saveDeleted;
    final tdIds = _messages.map((m) => m['id'] as int).toSet();
    _Item fromTd(Map<String, dynamic> m) {
      final sender = m['sender_id'] as Map?;
      final userId =
          sender?['@type'] == 'messageSenderUser' ? sender!['user_id'] as int : null;
      final mine = m['is_outgoing'] == true;
      return _Item(
        id: m['id'] as int,
        date: m['date'] as int,
        text: messageText(m['content'] as Map),
        mine: mine,
        senderKey: mine ? 'me' : '${userId ?? sender?['chat_id'] ?? 'x'}',
        senderId: userId,
        sending: m['sending_state'] != null,
        deletedAt: showDeleted
            ? store.find(widget.chatId, m['id'] as int)?.deletedAt
            : null,
        msg: m,
      );
    }

    final items = <_Item>[
      for (final m in _messages)
        if (m['is_outgoing'] == true ||
            !messageFilters.hides(
                widget.chatId, messageText(m['content'] as Map)))
          fromTd(m),
      if (showDeleted)
        for (final d in store.deletedFor(widget.chatId))
          if (!tdIds.contains(d.id))
            _Item(
              id: d.id,
              date: d.date,
              text: d.text,
              mine: d.outgoing,
              senderKey: d.outgoing ? 'me' : 'deleted',
              deletedAt: d.deletedAt,
            ),
      for (final g in premium.giftsFor(widget.chatId))
        _Item(
          id: 0,
          date: g.date,
          text: '',
          mine: true,
          senderKey: 'gift',
          gift: g,
        ),
    ]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return items;
  }

  Future<void> _menu(Offset pos, _Item m) async {
    if (m.gift != null) return;
    final live = m.msg != null && m.deletedAt == null;
    final action = await showDialog<Object>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (_) => _MenuDialog(
        pos: pos,
        live: live,
        chatId: widget.chatId,
        messageId: (m.msg?['id'] as int?) ?? 0,
        canCopy: m.text.isNotEmpty,
        canEdit: live && m.mine && m.msg?['content']?['@type'] == 'messageText',
        hasEdits: store.find(widget.chatId, m.id)?.edits.isNotEmpty ?? false,
        canQuote: live && m.text.isNotEmpty,
      ),
    );
    if (action == null || !mounted) return;
    if (action is Map) {
      final msg = m.msg;
      if (msg != null) {
        final key = reactionKey(action);
        final chosen = ReactionsRow.reactionsOf(msg).any(
            (r) => r['is_chosen'] == true && reactionKey(r['type'] as Map) == key);
        await _react(msg, action, chosen);
      }
      return;
    }
    await _onMenu('$action', m);
  }

  Future<void> _onMenu(String action, _Item m) async {
    final msg = m.msg;
    switch (action) {
      case 'reply':
        if (msg != null) {
          setState(() => _replyTo = msg);
          _focus.requestFocus();
        }
      case 'quote':
        if (msg != null) {
          final part = await pickQuote(context, m.text);
          if (part == null || !mounted) return;
          setState(() {
            _replyTo = msg;
            _quote = part;
          });
          _focus.requestFocus();
        }
      case 'edits':
        {
          final saved = store.find(widget.chatId, m.id);
          if (saved != null) await showEditHistory(context, saved);
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.text));
        tgToast('Скопировано');
      case 'forward':
        {
          if (msg == null) return;
          final chat = await pickChat(context, title: 'Переслать в…');
          if (chat == null) return;
          final r = await td.request({
            '@type': 'forwardMessages',
            'chat_id': chat['id'],
            'from_chat_id': widget.chatId,
            'message_ids': [msg['id']],
            'send_copy': false,
            'remove_caption': false,
          });
          tgToast(r['@type'] == 'error'
              ? 'Не получилось: ${r['message']}'
              : 'Переслано: ${chat['title']}');
        }
      case 'edit':
        {
          if (msg == null) return;
          final ctl = TextEditingController(text: m.text);
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => Theme(
              data: Tg.theme,
              child: AlertDialog(
                title: const Text('Редактировать сообщение'),
                content: TextField(controller: ctl, autofocus: true, maxLines: 6, minLines: 1),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
                ],
              ),
            ),
          );
          final text = ctl.text.trim();
          ctl.dispose();
          if (ok != true || text.isEmpty || text == m.text) return;
          final r = await td.request({
            '@type': 'editMessageText',
            'chat_id': widget.chatId,
            'message_id': msg['id'],
            'input_message_content': {
              '@type': 'inputMessageText',
              'text': {'@type': 'formattedText', 'text': text},
            },
          });
          if (r['@type'] == 'error') tgToast('Не получилось: ${r['message']}');
        }
      case 'pin':
        {
          if (msg == null) return;
          final r = await td.request({
            '@type': 'pinChatMessage',
            'chat_id': widget.chatId,
            'message_id': msg['id'],
            'disable_notification': false,
            'only_for_self': false,
          });
          tgToast(r['@type'] == 'error'
              ? 'Не получилось: ${r['message']}'
              : 'Сообщение закреплено');
        }
      case 'delete':
        {
          if (msg == null) return;
          final ok = await tgConfirm(context,
              title: 'Удалить сообщение?',
              text: 'Оно исчезнет у всех в этом чате, если Telegram позволяет.',
              yes: 'Удалить',
              danger: true);
          if (!ok) return;
          final r = await td.request({
            '@type': 'deleteMessages',
            'chat_id': widget.chatId,
            'message_ids': [msg['id']],
            'revoke': true,
          });
          if (r['@type'] == 'error') tgToast('Не получилось: ${r['message']}');
        }
    }
  }

  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  final Stopwatch _recTime = Stopwatch();

  Future<void> _toggleVoice() async {
    if (_recording) {
      final path = await _recorder.stop();
      _recTime.stop();
      setState(() => _recording = false);
      if (path == null || _recTime.elapsed.inMilliseconds < 700) {
        tgToast('Слишком коротко');
        return;
      }
      await _sendContent({
        '@type': 'inputMessageVoiceNote',
        'voice_note': {'@type': 'inputFileLocal', 'path': path},
        'duration': _recTime.elapsed.inSeconds,
        'waveform': '',
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      tgToast('Нет доступа к микрофону');
      return;
    }
    if (!await _recorder.isEncoderSupported(AudioEncoder.opus)) {
      tgToast('Запись голоса (Opus) здесь не поддерживается');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/gengram_voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
    await _recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.opus, bitRate: 32000, sampleRate: 48000, numChannels: 1),
        path: path);
    _recTime
      ..reset()
      ..start();
    setState(() => _recording = true);
  }

  Future<void> _cancelVoice() async {
    final path = await _recorder.stop();
    _recTime.stop();
    setState(() => _recording = false);
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  Future<void> _searchInChat() async {
    final ctl = TextEditingController();
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: Tg.theme,
        child: AlertDialog(
          title: const Text('Поиск в чате'),
          content: TextField(
              controller: ctl,
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Найти')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (q == null || q.trim().isEmpty || !mounted) return;
    final r = await td.request({
      '@type': 'searchChatMessages',
      'chat_id': widget.chatId,
      'query': q.trim(),
      'limit': 50,
    });
    if (!mounted) return;
    final list = ((r['messages'] as List?) ?? const []).cast<Map>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: Tg.theme,
        child: AlertDialog(
          title: Text(list.isEmpty ? 'Ничего не найдено' : 'Найдено: ${list.length}'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in list)
                  ListTile(
                    dense: true,
                    title: Text(messageText(m['content'] as Map),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(DateTime.fromMillisecondsSinceEpoch(
                            (m['date'] as int) * 1000)
                        .toString()
                        .substring(0, 16)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }

  Future<void> _quickReact(Map<String, dynamic> msg) {
    const type = {'@type': 'reactionTypeEmoji', 'emoji': '❤️'};
    final chosen = ReactionsRow.reactionsOf(msg).any((r) =>
        r['is_chosen'] == true && reactionKey(r['type'] as Map) == reactionKey(type));
    return _react(msg, type, chosen);
  }

  Future<void> _react(Map<String, dynamic> msg, Map type, bool chosen) async {
    final r = await td.request({
      '@type': chosen ? 'removeMessageReaction' : 'addMessageReaction',
      'chat_id': widget.chatId,
      'message_id': msg['id'],
      'reaction_type': type,
      if (!chosen) 'is_big': false,
      if (!chosen) 'update_recent_reactions': true,
    });
    if (r['@type'] == 'error') tgToast('Реакция не поставилась: ${r['message']}');
  }

  Widget _titleBlock() {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => showProfile(context, widget.chatId, canWrite: false),
      child: Row(
        children: [
          TgAvatar(
              id: widget.chatId,
              title: _title,
              photo: _chat?['photo']?['small'] as Map?,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w600)),
                if (_isForum && _topicName != null)
                  Text(_topicName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Tg.link))
                else if (_status.isNotEmpty)
                  Text(_status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          color: _status == 'в сети' ? Tg.link : Tg.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _headerActions() => [
        if (_isForum)
          IconButton(
            tooltip: 'Темы',
            icon: Icon(Icons.forum_outlined, color: Tg.textSecondary),
            onPressed: _pickTopic,
          ),
        PopupMenuButton<String>(
          tooltip: 'Ещё',
          color: Tg.panelOver,
          onSelected: _headerMenu,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'profile', child: Text('Профиль')),
            const PopupMenuItem(value: 'media', child: Text('Медиа, файлы, ссылки')),
            const PopupMenuItem(value: 'pinned', child: Text('Закреплённые сообщения')),
            const PopupMenuItem(value: 'scheduled', child: Text('Отложенные сообщения')),
            const PopupMenuItem(value: 'lock', child: Text('Код на этот чат')),
            if (_peerUserId != null && _chat?['type']?['@type'] == 'chatTypePrivate')
              const PopupMenuItem(value: 'secret', child: Text('Начать секретный чат')),
          ],
        ),
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) => settings.ghost
              ? PopupMenuButton<String>(
                  tooltip: 'Режим призрака',
                  icon: GenIcon(GIcon.ghost,
                      color: settings.noReadIn(widget.chatId)
                          ? Tg.link
                          : Tg.textSecondary),
                  color: Tg.panelOver,
                  onSelected: (v) {
                    if (v == 'read') {
                      _readNow();
                    } else {
                      final on = settings.ghostReadIds.contains(widget.chatId);
                      settings.change(() {
                        settings.ghostReadIds = on
                            ? (settings.ghostReadIds.toSet()..remove(widget.chatId))
                            : {...settings.ghostReadIds, widget.chatId};
                      });
                      tgToast(on
                          ? 'В этом чате снова не читаю'
                          : 'В этом чате читаю как обычно');
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'read', child: Text('Прочитать сейчас')),
                    PopupMenuItem(
                        value: 'toggle',
                        child: Text(settings.ghostReadIds.contains(widget.chatId)
                            ? 'Не читать в этом чате'
                            : 'Всегда читать в этом чате')),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        IconButton(
          tooltip: 'Поиск в чате',
          icon: const TgIcon(GIcon.search),
          onPressed: _searchInChat,
        ),
        IconButton(
          tooltip: 'Отправить подарок',
          icon: const TgIcon(GIcon.gift),
          onPressed: () =>
              showGiftSheet(context, chatId: widget.chatId, chatTitle: _title),
        ),
        IconButton(
          tooltip: 'Профиль',
          icon: const TgIcon(GIcon.info),
          onPressed: () => showProfile(context, widget.chatId, canWrite: false),
        ),
        if (widget.onClose != null)
          IconButton(
            tooltip: 'Закрыть чат',
            icon: const TgIcon(GIcon.close),
            onPressed: widget.onClose,
          ),
      ];

  Widget _header() {
    if (widget.onClose != null) {
      return Material(
        color: Tg.panel,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(child: _titleBlock()),
                ..._headerActions(),
              ],
            ),
          ),
        ),
      );
    }
    Widget pill(Widget child) => Container(
          height: 52,
          decoration: BoxDecoration(
            color: Tg.panel.withOpacity(0.9),
            borderRadius: BorderRadius.circular(26),
          ),
          child: child,
        );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(
          children: [
            pill(IconButton(
              icon: const TgIcon(GIcon.back),
              onPressed: () => Navigator.of(context).maybePop(),
            )),
            const SizedBox(width: 8),
            Expanded(
              child: pill(Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _titleBlock(),
              )),
            ),
            const SizedBox(width: 8),
            pill(Row(children: _headerActions())),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return CallbackShortcuts(
      bindings: {
        if (widget.onClose != null)
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose!,
      },
      child: Scaffold(
        backgroundColor: Tg.bg,
        body: ChatBackground(
          child: Column(
            children: [
              _header(),
              PinnedBar(chatId: widget.chatId),
              Expanded(child: _list(items)),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<_Item> items) {
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        final older = i + 1 < items.length ? items[i + 1] : null;
        final newer = i > 0 ? items[i - 1] : null;
        final newDay = older == null || !tgSameDay(older.date, m.date);
        final firstOfGroup =
            older == null || newDay || older.senderKey != m.senderKey;
        final lastOfGroup = newer == null ||
            newer.senderKey != m.senderKey ||
            !tgSameDay(newer.date, m.date);
        return Column(
          children: [
            if (newDay) _DayChip(tgDayLabel(m.date)),
            Padding(
              padding: EdgeInsets.only(top: firstOfGroup ? 6 : 1.5),
              child: _row(m, firstOfGroup, lastOfGroup),
            ),
          ],
        );
      },
    );
  }

  Widget _row(_Item m, bool firstOfGroup, bool lastOfGroup) {
    if (m.gift != null) {
      return Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(m.gift!.id),
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, child) =>
              Transform.scale(scale: v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
          child: GiftBubble(m.gift!),
        ),
      );
    }
    final msg = m.msg;
    final content = msg?['content'] as Map?;
    final kind = content == null ? MsgKind.text : kindOf(content);

    if (kind == MsgKind.service) {
      return Center(child: _ServiceChip(m.text));
    }
    if (kind == MsgKind.gift && msg != null) {
      return Center(
        child: GestureDetector(
          onLongPressStart: (d) => _menu(d.globalPosition, m),
          onSecondaryTapUp: (d) => _menu(d.globalPosition, m),
          child: MessageContent(msg: msg, mine: m.mine, gap: 0),
        ),
      );
    }

    final avatarOn = _isGroup && !_isChannel && !m.mine && m.senderId != null;
    final user = avatarOn ? _user(m.senderId) : null;
    final name = (_isGroup && !_isChannel && !m.mine && firstOfGroup && m.senderId != null)
        ? _userName(_user(m.senderId))
        : '';
    final bubble = GestureDetector(
      onDoubleTap: (settings.doubleTapReact && msg != null)
          ? () => _quickReact(msg)
          : null,
      onLongPressStart: (d) => _menu(d.globalPosition, m),
      onSecondaryTapUp: (d) => _menu(d.globalPosition, m),
      child: _Bubble(
        item: m,
        senderName: name.isEmpty ? null : name,
        tail: lastOfGroup,
        read: m.id <= _lastReadOutbox,
        reply: msg == null ? null : _replyInfo(msg),
        forwardFrom: msg == null ? null : _forwardFrom(msg),
        onReact: (type, chosen) {
          if (msg != null) _react(msg, type, chosen);
        },
      ),
    );

    return Row(
      mainAxisAlignment:
          m.mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (avatarOn)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: lastOfGroup
                ? GestureDetector(
                    onTap: () => showUserProfile(context, m.senderId!),
                    child: TgAvatar(
                        id: m.senderId!,
                        title: _userName(user),
                        photo: user?['profile_photo']?['small'] as Map?,
                        size: 34),
                  )
                : const SizedBox(width: 34),
          ),
        Flexible(child: bubble),
      ],
    );
  }

  Widget _composer() {
    final reply = _replyTo;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isForum)
            InkWell(
              onTap: _pickTopic,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 16, color: Tg.link),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('Писать в тему: ${_topicName ?? 'General'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Tg.link)),
                    ),
                    Icon(Icons.arrow_drop_down, color: Tg.link),
                  ],
                ),
              ),
            ),
          if (reply != null)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: Tg.panel.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 20, color: Tg.link),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ReplyQuote(
                        name: _authorOf(reply),
                        text: messageText(reply['content'] as Map)),
                  ),
                  IconButton(
                    icon: const TgIcon(GIcon.close, size: 20),
                    onPressed: () => setState(() {
                      _replyTo = null;
                      _quote = null;
                    }),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Tg.panel.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Эмодзи, GIF, стикеры',
                          icon: Icon(
                              _panelOpen
                                  ? Icons.keyboard_outlined
                                  : Icons.emoji_emotions_outlined,
                              color: Tg.textSecondary),
                          onPressed: _togglePanel,
                        ),
                        Expanded(
                          child: Focus(
                            onKeyEvent: (node, event) {
                              if (_isDesktop &&
                                  settings.sendByEnter &&
                                  event is KeyDownEvent &&
                                  event.logicalKey == LogicalKeyboardKey.enter &&
                                  !HardwareKeyboard.instance.isShiftPressed) {
                                _send();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: TextField(
                              controller: _input,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(fontSize: 16, color: Tg.text),
                              cursorColor: Tg.link,
                              decoration: InputDecoration(
                                hintText: 'Сообщение',
                                hintStyle: TextStyle(color: Tg.textSecondary),
                                isDense: true,
                                filled: false,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 14),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        if (_recording)
                          IconButton(
                            tooltip: 'Отмена',
                            icon: const Icon(Icons.delete_outline, color: Tg.danger),
                            onPressed: _cancelVoice,
                          ),
                        if (!_hasText)
                          IconButton(
                            tooltip: _recording ? 'Остановить и отправить' : 'Записать голосовое',
                            icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none,
                                color: _recording ? Tg.danger : Tg.textSecondary),
                            onPressed: _toggleVoice,
                          ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Material(
                    key: ValueKey(_hasText),
                    color: Tg.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _hasText ? _send : _attach,
                      onLongPress: _hasText ? _sendWithOptions : null,
                      onSecondaryTap: _hasText ? _sendWithOptions : null,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: _hasText
                              ? const TgIcon(GIcon.send,
                                  size: 22, color: Colors.white)
                              : const Icon(Icons.attach_file,
                                  size: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_panelOpen)
            InputPanel(
              onEmoji: _insertEmoji,
              onSticker: _sendSticker,
              onGif: _sendGif,
              onCustomEmoji: _sendCustomEmoji,
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Tg.panel.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Tg.text)),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Tg.panel.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Tg.text)),
    );
  }
}

class _MenuDialog extends StatelessWidget {
  const _MenuDialog(
      {required this.pos,
      required this.live,
      required this.chatId,
      required this.messageId,
      required this.canCopy,
      this.canEdit = false,
      this.hasEdits = false,
      this.canQuote = false});

  final bool canEdit;
  final bool hasEdits;
  final bool canQuote;

  final Offset pos;
  final bool live;
  final int chatId;
  final int messageId;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final actions = <(String, String, IconData, bool)>[
      if (live) ('reply', 'Ответить', Icons.reply, false),
      if (canQuote) ('quote', 'Ответить с цитатой', Icons.format_quote, false),
      if (hasEdits) ('edits', 'История правок', Icons.history, false),
      if (canCopy) ('copy', 'Копировать', Icons.copy, false),
      if (live) ('forward', 'Переслать', Icons.shortcut, false),
      if (live && canEdit) ('edit', 'Редактировать', Icons.edit_outlined, false),
      if (live) ('pin', 'Закрепить', Icons.push_pin_outlined, false),
      if (live) ('delete', 'Удалить', Icons.delete_outline, true),
    ];
    const width = 300.0;
    final height = (live ? 60.0 : 0.0) + 8 + actions.length * 50.0;
    var left = pos.dx - width / 2;
    if (left > size.width - width - 8) left = size.width - width - 8;
    if (left < 8) left = 8;
    var top = pos.dy - 40;
    if (top > size.height - height - 8) top = size.height - height - 8;
    if (top < 8) top = 8;

    return Theme(
      data: Tg.theme,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (live) ReactionBar(chatId: chatId, messageId: messageId),
                  Container(
                    width: 250,
                    decoration: BoxDecoration(
                      color: Tg.panelOver,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        for (final a in actions)
                          InkWell(
                            onTap: () => Navigator.pop(context, a.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              child: Row(
                                children: [
                                  Icon(a.$3,
                                      size: 22,
                                      color: a.$4 ? Tg.danger : Tg.text),
                                  const SizedBox(width: 16),
                                  Text(a.$2,
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: a.$4 ? Tg.danger : Tg.text)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.item,
    required this.senderName,
    required this.tail,
    required this.read,
    required this.reply,
    required this.forwardFrom,
    required this.onReact,
  });

  final _Item item;
  final String? senderName;
  final bool tail;
  final bool read;
  final (String, String)? reply;
  final String? forwardFrom;
  final void Function(Map type, bool chosen) onReact;

  Widget _meta(_Item m, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(settings.showSeconds ? tgHhmmss(m.date) : tgHhmm(m.date),
              style: TextStyle(fontSize: 11.5, color: color)),
          if (m.mine) ...[
            const SizedBox(width: 3),
            TgIcon(
                m.sending
                    ? GIcon.clock
                    : (read ? GIcon.doubleCheck : GIcon.check),
                size: 15,
                color: color),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final m = item;
    final msg = m.msg;
    final deleted = m.deletedAt != null;
    final content = msg?['content'] as Map?;
    final kind = content == null ? MsgKind.text : kindOf(content);
    final onImage = content != null && metaOnImage(content);
    final isMedia = kind == MsgKind.media;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _meta(m, Colors.white),
    );

    if (kind == MsgKind.sticker && msg != null) {
      return Stack(
        children: [
          MessageContent(msg: msg, mine: m.mine, gap: 0),
          Positioned(right: 6, bottom: 6, child: pill),
        ],
      );
    }

    final big = Radius.circular(settings.bubbleRadius);
    final small = Radius.circular(settings.bubbleRadius < 4 ? settings.bubbleRadius : 4);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: (!m.mine && tail) ? small : big,
      bottomRight: (m.mine && tail) ? small : big,
    );
    final metaColor = m.mine ? Tg.metaOut : Tg.textSecondary;
    final meta = _meta(m, metaColor);

    final gap = (deleted || onImage) ? 0.0 : (m.mine ? 62.0 : 42.0);
    final Widget body = Opacity(
      opacity: deleted ? 0.75 : 1,
      child: msg != null
          ? MessageContent(
              msg: msg,
              mine: m.mine,
              gap: gap,
              metaPill: onImage ? pill : null,
            )
          : FormattedText({'text': m.text}, gap: gap, mine: m.mine),
    );

    final pad = isMedia ? const EdgeInsets.all(3) : EdgeInsets.zero;
    Widget top(Widget w) =>
        isMedia ? Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 2), child: w) : w;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (senderName != null)
          top(Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(senderName!,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tgNameColor(m.senderId ?? 0))),
          )),
        if (forwardFrom != null)
          top(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(forwardFrom!,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Tg.link)),
          )),
        if (reply != null)
          top(ReplyQuote(name: reply!.$1, text: reply!.$2, mine: m.mine)),
        body,
        if (msg != null)
          Padding(
            padding: isMedia
                ? const EdgeInsets.fromLTRB(6, 0, 6, 4)
                : EdgeInsets.zero,
            child: ReactionsRow(msg: msg, onTap: onReact),
          ),
        if (deleted)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrashIcon(size: 14, color: Color(settings.deletedColor)),
                const SizedBox(width: 4),
                Text('${settings.deletedMark} ${tgHhmm(m.deletedAt!)}',
                    style: TextStyle(
                        fontSize: 11.5, color: Color(settings.deletedColor))),
                const SizedBox(width: 14),
                meta,
              ],
            ),
          ),
      ],
    );

    return Container(
      constraints: BoxConstraints(maxWidth: settings.bubbleWidth),
      padding: isMedia ? pad : const EdgeInsets.fromLTRB(11, 7, 11, 7),
      decoration: BoxDecoration(
        color: m.mine ? Tg.outgoing : Tg.incoming,
        borderRadius: radius,
        border: deleted
            ? Border.all(color: Color(settings.deletedColor).withOpacity(0.6))
            : null,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
            fontSize: settings.chatTextSize, height: 1.3, color: Tg.text),
        child: (deleted || onImage)
            ? column
            : Stack(
                children: [
                  column,
                  Positioned(
                      right: isMedia ? 8 : 0,
                      bottom: isMedia ? 4 : 0,
                      child: meta),
                ],
              ),
      ),
    );
  }
}
