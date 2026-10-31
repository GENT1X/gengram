import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'notifier.dart';
import 'tg_widgets.dart';

final guard = Guard();

class Guard {
  final Set<int> _watching = {};
  bool _dialogOpen = false;

  Future<void> watch(Account a) async {
    if (!_watching.add(a.id)) return;
    await check(a);
    Timer.periodic(const Duration(minutes: 2), (_) {
      if (settings.guardSessions && accounts.list.contains(a)) check(a);
    });
  }

  Future<void> check(Account a) async {
    if (!settings.guardSessions || !a.ready) return;
    final r = await a.td.request({'@type': 'getActiveSessions'});
    final list = (r['sessions'] as List?)?.cast<Map>() ?? const [];
    if (list.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'guardKnown_${a.id}';
    final known = (prefs.getStringList(key) ?? const <String>[]).toSet();
    final first = !prefs.containsKey(key);
    final fresh = <Map>[];
    for (final s in list) {
      final id = '${s['id']}';
      if (!known.contains(id)) {
        known.add(id);
        if (!first && s['is_current'] != true) fresh.add(s);
      }
    }
    await prefs.setStringList(key, known.toList());
    if (fresh.isEmpty || _dialogOpen) return;
    _dialogOpen = true;
    try {
      final text = [
        for (final s in fresh)
          '• ${s['application_name']} · ${s['device_model']} (${s['platform']})\n'
              '  ${s['ip_address']} · ${s['location'] ?? s['country'] ?? ''}',
      ].join('\n');
      await notifier.alert('GenGram: новый вход', text);
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      final terminate = await tgConfirm(ctx,
          title: 'Новый вход в аккаунт ${a.name}',
          text: '$text\n\nЕсли это не вы, завершите сеанс и смените пароль.',
          yes: 'Завершить сеанс',
          danger: true);
      if (terminate) {
        for (final s in fresh) {
          await a.td.request({
            '@type': 'terminateSession',
            'session_id': s['id'],
          });
        }
        tgToast('Сеанс завершён');
      }
    } finally {
      _dialogOpen = false;
    }
  }
}
