import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

final chatLock = ChatLock();

const _iterations = 30000;

Uint8List _pbkdf2(List<String> args) {
  final password = utf8.encode(args[0]);
  final salt = utf8.encode(args[1]);
  final hmac = Hmac(sha256, password);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.from(block);
  for (var i = 1; i < _iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return Uint8List.fromList(result);
}

Future<String> lockHash(String salt, String code) async {
  final bytes = await compute(_pbkdf2, [code, salt]);
  return base64Encode(bytes);
}

enum _Check { wrong, main, panic }

class ChatLock {
  SharedPreferences? _prefs;
  final Set<int> _unlocked = {};

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(int chatId) => 'chatlock_$chatId';

  Future<bool> has(int chatId) async =>
      (await _p).getString(_key(chatId)) != null;

  Future<_Check> _check(int chatId, String code) async {
    final value = (await _p).getString(_key(chatId));
    if (value == null || code.isEmpty) return _Check.wrong;
    final parts = value.split('|');
    if (parts.length < 3) return _Check.wrong;
    final h = await lockHash(parts[0], code);
    if (h == parts[1]) return _Check.main;
    if (parts[2].isNotEmpty && h == parts[2]) return _Check.panic;
    return _Check.wrong;
  }

  Future<bool> ensure(BuildContext context, int chatId) async {
    if (!await has(chatId)) {
      _unlocked.removeWhere((id) => id != chatId);
      return true;
    }
    if (_unlocked.contains(chatId)) return true;
    if (!context.mounted) return false;
    final code = await _askCode(context, 'Введите код');
    if (code == null) return false;
    final r = await _check(chatId, code);
    if (r == _Check.wrong) {
      tgToast('Неверный код');
      return false;
    }
    if (r == _Check.panic) {
      await td.request({
        '@type': 'deleteChatHistory',
        'chat_id': chatId,
        'remove_from_chat_list': false,
        'revoke': false,
      });
    }
    _unlocked
      ..clear()
      ..add(chatId);
    return true;
  }

  Future<String?> _askCode(BuildContext context, String title,
      {String hint = 'Код'}) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: Tg.theme,
        child: AlertDialog(
          backgroundColor: Tg.panelOver,
          title: Text(title),
          content: TextField(
            controller: ctl,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('Готово')),
          ],
        ),
      ),
    );
  }

  Future<void> setup(BuildContext context, int chatId) async {
    final prefs = await _p;
    final existing = prefs.getString(_key(chatId)) != null;
    if (existing) {
      if (!context.mounted) return;
      final cur = await _askCode(context, 'Текущий код');
      if (cur == null) return;
      if (await _check(chatId, cur) != _Check.main) {
        tgToast('Неверный код');
        return;
      }
      if (!context.mounted) return;
      final remove = await tgConfirm(context,
          title: 'Код на чат',
          text: 'Убрать код совсем или задать новый?',
          yes: 'Убрать код');
      if (remove) {
        await prefs.remove(_key(chatId));
        _unlocked.remove(chatId);
        tgToast('Код снят');
        return;
      }
    }
    if (!context.mounted) return;
    final main = await _askCode(context, 'Новый код для входа');
    if (main == null || main.isEmpty) return;
    if (!context.mounted) return;
    final panic = await _askCode(context, 'Код-паника (необязательно)',
        hint: 'Очищает историю этого чата. Пусто = нет');
    if (panic != null && panic.isNotEmpty && panic == main) {
      tgToast('Код-паника должен отличаться от кода входа');
      return;
    }
    final rnd = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => rnd.nextInt(256)));
    final value =
        '$salt|${await lockHash(salt, main)}|${(panic == null || panic.isEmpty) ? '' : await lockHash(salt, panic)}';
    await prefs.setString(_key(chatId), value);
    _unlocked.remove(chatId);
    tgToast('Код поставлен');
  }
}
