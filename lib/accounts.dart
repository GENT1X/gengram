import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'config.dart';
import 'db_key.dart';
import 'guard.dart';
import 'keeper.dart';
import 'message_store.dart';
import 'notifier.dart';
import 'td_client.dart';

final accounts = Accounts();

class Account {
  Account(this.id)
      : store = MessageStore(
            id == 0 ? 'gengram_messages.json' : 'gengram_messages_$id.json');

  final int id;
  final TdClient td = TdClient();
  final MessageStore store;

  String authState = 'loading';
  Map<String, dynamic>? me;

  int unread = 0;

  List<Map<String, dynamic>> folders = [];

  String? startError;

  String _dbKey = '';
  bool _retriedKey = false;
  bool _paramsSent = false;
  bool _readyDone = false;
  StreamSubscription? _sub;

  bool get ready => authState == 'authorizationStateReady';

  String get name {
    final m = me;
    if (m == null) return 'Аккаунт ${id + 1}';
    final n = '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
    return n.isEmpty ? 'Аккаунт ${id + 1}' : n;
  }

  String get phone {
    final p = me?['phone_number'] as String?;
    return (p == null || p.isEmpty) ? '' : '+$p';
  }

  String get username {
    final list = me?['usernames']?['active_usernames'];
    if (list is List && list.isNotEmpty) return '@${list.first}';
    return '';
  }

  bool get isPremium => me?['is_premium'] == true;

  String get _suffix => id == 0 ? '' : '_$id';

  Future<void> start() async {
    await store.load();
    _sub = td.updates.listen(_onUpdate);
    await td.start();
    unawaited(td
        .request({'@type': 'getAuthorizationState'})
        .then(_applyState));
  }

  void _onUpdate(Map<String, dynamic> u) {
    unawaited(notifier.onUpdate(this, u));
    keeper.onUpdate(this, u);
    switch (u['@type']) {
      case 'updateAuthorizationState':
        unawaited(_applyState(u['authorization_state'] as Map<String, dynamic>));
      case 'updateUser':
        {
          final user = u['user'] as Map<String, dynamic>;
          if (me != null && user['id'] == me!['id']) {
            me = user;
            accounts.touch();
          }
        }
      case 'updateChatFolders':
        folders = ((u['chat_folders'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        accounts.touch();
      case 'updateUnreadMessageCount':
        if (u['chat_list']?['@type'] == 'chatListMain') {
          unread = (u['unread_unmuted_count'] as int?) ?? 0;
          accounts.touch();
        }
      case 'updateNewMessage':
      case 'updateMessageSendSucceeded':
        store.remember(u['message'] as Map<String, dynamic>);
      case 'updateMessageContent':
        store.updateContent(
            u['chat_id'] as int, u['message_id'] as int, u['new_content']);
      case 'updateDeleteMessages':
        if (u['is_permanent'] == true &&
            u['from_cache'] != true &&
            settings.saveDeleted) {
          store.markDeleted(u['chat_id'] as int, u['message_ids'] as List);
        }
    }
  }

  Future<void> _applyState(Map<String, dynamic> s) async {
    final type = s['@type'];
    if (type is! String) return;
    if (type == 'authorizationStateWaitTdlibParameters') {
      if (_paramsSent) return;
      _paramsSent = true;
      await _sendParams();
      return;
    }
    authState = type;
    if (type == 'authorizationStateReady' && !_readyDone) {
      _readyDone = true;
      await sendGhost(td, settings.ghost);
      final r = await td.request({'@type': 'getMe'});
      if (r['@type'] == 'user') me = r;
      await applySaver(td);
      await _encryptDatabase();
      unawaited(guard.watch(this));
    }
    accounts.touch();
  }

  Future<void> _encryptDatabase() async {
    if (_dbKey.isNotEmpty) return;
    final key = dbKeys.generate();
    if (!await dbKeys.save(id, key)) return;
    final r = await td.request({
      '@type': 'setDatabaseEncryptionKey',
      'new_encryption_key': key,
    });
    if (r['@type'] == 'error') {
      await dbKeys.forget(id);
    } else {
      _dbKey = key;
    }
  }

  Future<void> _sendParams({bool withKey = true}) async {
    final dir = await getApplicationSupportDirectory();
    _dbKey = withKey ? await dbKeys.read(id) : '';
    final r = await td.request({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': '${dir.path}/tdlib$_suffix',
      'files_directory': '${dir.path}/tdlib_files$_suffix',
      'database_encryption_key': _dbKey,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': true,
      'api_id': apiId,
      'api_hash': apiHash,
      'system_language_code': 'ru',
      'device_model': 'GenGram',
      'system_version': Platform.operatingSystem,
      'application_version': '0.2.0',
    });
    if (r['@type'] == 'error') {
      if (_dbKey.isNotEmpty && !_retriedKey) {
        _retriedKey = true;
        await dbKeys.forget(id);
        _paramsSent = false;
        await _sendParams(withKey: false);
        return;
      }
      startError = '${r['message']}';
      accounts.touch();
    }
  }

  Future<void> shutdown() async {
    final closed = td.updates
        .firstWhere((u) =>
            u['@type'] == 'updateAuthorizationState' &&
            u['authorization_state']?['@type'] == 'authorizationStateClosed')
        .timeout(const Duration(seconds: 8),
            onTimeout: () => <String, dynamic>{});
    var r = await td.request({'@type': ready ? 'logOut' : 'destroy'});
    if (r['@type'] == 'error') {
      r = await td.request({'@type': 'destroy'});
    }
    await closed;
    await _sub?.cancel();
    td.dispose();
    try {
      final dir = await getApplicationSupportDirectory();
      for (final p in ['tdlib$_suffix', 'tdlib_files$_suffix']) {
        final d = Directory('${dir.path}/$p');
        if (await d.exists()) await d.delete(recursive: true);
      }
      final f = File('${dir.path}/${store.fileName}');
      if (await f.exists()) await f.delete();
      await dbKeys.forget(id);
    } catch (_) {
    }
  }
}

class Accounts extends ChangeNotifier {
  final List<Account> list = [];
  int _activeId = 0;
  int _next = 1;
  SharedPreferences? _prefs;

  Account get active =>
      list.firstWhere((a) => a.id == _activeId, orElse: () => list.first);

  void touch() => notifyListeners();

  Future<void> init() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('accountIds') ?? const <String>['0'])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    if (ids.isEmpty) ids.add(0);
    _activeId = prefs.getInt('activeAccount') ?? ids.first;
    if (!ids.contains(_activeId)) _activeId = ids.first;
    final biggest = ids.reduce((a, b) => a > b ? a : b);
    final saved = prefs.getInt('nextAccountId') ?? 0;
    _next = saved > biggest ? saved : biggest + 1;
    for (final id in ids) {
      list.add(Account(id));
    }
    await Future.wait(list.map((a) => a.start()));
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setStringList('accountIds', list.map((a) => '${a.id}').toList());
    await prefs.setInt('activeAccount', _activeId);
    await prefs.setInt('nextAccountId', _next);
  }

  Future<void> addAccount() async {
    final a = Account(_next++);
    await a.start();
    list.add(a);
    _activeId = a.id;
    await _persist();
    notifyListeners();
  }

  Future<void> switchTo(int id) async {
    if (id == _activeId || !list.any((a) => a.id == id)) return;
    _activeId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> removeAccount(Account a) async {
    list.remove(a);
    if (list.isEmpty) {
      final fresh = Account(_next++);
      await fresh.start();
      list.add(fresh);
      _activeId = fresh.id;
    } else if (_activeId == a.id) {
      _activeId = list.firstWhere((x) => x.ready, orElse: () => list.first).id;
    }
    await _persist();
    notifyListeners();
    await a.shutdown();
  }

  Future<void> cancelAdd() async {
    final a = active;
    if (a.ready || list.length < 2) return;
    await removeAccount(a);
  }

  Future<void> flushAll() => Future.wait(list.map((a) => a.store.flush()));
}
