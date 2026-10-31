import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'background.dart';

final notifier = Notifier();

const _replyPort = 'gengram_reply_port';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final port = IsolateNameServer.lookupPortByName(_replyPort);
  port?.send({
    'action': response.actionId,
    'input': response.input,
    'payload': response.payload,
  });
}

class Notifier with WidgetsBindingObserver {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  AppLifecycleState _state = AppLifecycleState.resumed;

  int? openChatId;

  final requestOpen = ValueNotifier<int?>(null);

  final _recent = <int, int>{};
  final _scopeMuted = <String, bool>{};
  int _lastBadge = -1;

  Future<void> init() async {
    if (_ready) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      final windows = WindowsInitializationSettings(
        appName: 'GenGram',
        appUserModelId: 'GenGram.Client',
        guid: '8f3c9c1e-5d3a-4b7e-9a51-6a2f4e0c7d11',
      );
      await _plugin.initialize(
        InitializationSettings(android: android, windows: windows),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      final port = ReceivePort();
      IsolateNameServer.removePortNameMapping(_replyPort);
      IsolateNameServer.registerPortWithName(port.sendPort, _replyPort);
      port.listen((m) {
        final map = Map<String, dynamic>.from(m as Map);
        _handle(map['action'] as String?, map['input'] as String?,
            map['payload'] as String?);
      });
      accounts.addListener(refreshBadge);
      _ready = true;
    } catch (e) {
      debugPrint('notifications: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _state = state;

  bool get _appVisible => _state == AppLifecycleState.resumed;

  void _onResponse(NotificationResponse r) =>
      _handle(r.actionId, r.input, r.payload);

  Future<void> _handle(String? action, String? input, String? payload) async {
    if (payload == null) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final account =
        accounts.list.where((a) => a.id == data['a']).firstOrNull;
    if (account == null) return;
    final chatId = data['c'] as int;
    if (action == 'reply' && input != null && input.trim().isNotEmpty) {
      await account.td.request({
        '@type': 'sendMessage',
        'chat_id': chatId,
        'reply_to': {
          '@type': 'inputMessageReplyToMessage',
          'message_id': data['m'],
        },
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {'@type': 'formattedText', 'text': input.trim()},
        },
      });
      await _plugin.cancel(chatId & 0x7fffffff);
      return;
    }
    await accounts.switchTo(account.id);
    await background.showWindow();
    requestOpen.value = chatId;
  }

  Future<void> onUpdate(Account account, Map<String, dynamic> u) async {
    if (!_ready || !settings.notify) return;
    if (u['@type'] != 'updateNewMessage') return;
    final m = u['message'] as Map<String, dynamic>;
    if (m['is_outgoing'] == true) return;
    final chatId = m['chat_id'] as int;
    if (_appVisible && openChatId == chatId && account == accounts.active) {
      return;
    }
    if (_recent[chatId] == m['id']) return;

    final chat = await account.td.request({'@type': 'getChat', 'chat_id': chatId});
    if (chat['@type'] != 'chat') return;
    if (await _muted(account, chat)) return;
    _recent[chatId] = m['id'] as int;

    final title = chat['title'] as String? ?? 'GenGram';
    final text = settings.notifyPreview
        ? messageText(m['content'] as Map)
        : 'Новое сообщение';
    final payload = jsonEncode({'a': account.id, 'c': chatId, 'm': m['id']});
    final android = AndroidNotificationDetails(
      'gengram_messages',
      'Сообщения',
      channelDescription: 'Новые сообщения',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'gengram_${account.id}',
      actions: [
        AndroidNotificationAction(
          'reply',
          'Ответить',
          inputs: [
            const AndroidNotificationActionInput(label: 'Сообщение'),
          ],
          showsUserInterface: false,
          allowGeneratedReplies: true,
        ),
      ],
    );
    const windows = WindowsNotificationDetails();
    try {
      await _plugin.show(
        chatId & 0x7fffffff,
        title,
        text,
        NotificationDetails(android: android, windows: windows),
        payload: payload,
      );
    } catch (e) {
      debugPrint('notify: $e');
    }
  }

  Future<bool> _muted(Account account, Map chat) async {
    final s = chat['notification_settings'] as Map?;
    if (s == null) return false;
    if (s['use_default_mute_for'] != true) {
      return ((s['mute_for'] as int?) ?? 0) > 0;
    }
    final t = chat['type']?['@type'];
    final scope = t == 'chatTypePrivate' || t == 'chatTypeSecret'
        ? 'notificationSettingsScopePrivateChats'
        : (t == 'chatTypeSupergroup' && chat['type']['is_channel'] == true
            ? 'notificationSettingsScopeChannelChats'
            : 'notificationSettingsScopeGroupChats');
    final key = '${account.id}:$scope';
    final cached = _scopeMuted[key];
    if (cached != null) return cached;
    final r = await account.td.request({
      '@type': 'getScopeNotificationSettings',
      'scope': {'@type': scope},
    });
    final muted = ((r['mute_for'] as int?) ?? 0) > 0;
    _scopeMuted[key] = muted;
    Timer(const Duration(minutes: 5), () => _scopeMuted.remove(key));
    return muted;
  }

  Future<void> alert(String title, String text) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        1,
        title,
        text,
        const NotificationDetails(
          android: AndroidNotificationDetails('gengram_security', 'Безопасность',
              importance: Importance.max, priority: Priority.high),
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  Future<void> refreshBadge() async {
    var total = 0;
    for (final a in accounts.list) {
      total += a.unread;
    }
    if (total == _lastBadge) return;
    _lastBadge = total;
    try {
      if (Platform.isAndroid) await AppBadgePlus.updateBadge(total);
    } catch (_) {}
    await background.setBadge(total);
  }
}
