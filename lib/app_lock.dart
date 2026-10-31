import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_lock.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

final appLock = AppLock();

class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  SharedPreferences? _prefs;
  bool locked = false;
  DateTime? _away;

  int minutes = 1;

  bool get enabled => _prefs?.getString('applock') != null;

  Future<void> init() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    minutes = prefs.getInt('applockMinutes') ?? 1;
    locked = enabled;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _away ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _away;
      _away = null;
      if (away != null &&
          DateTime.now().difference(away).inMinutes >= minutes &&
          !locked) {
        locked = true;
        notifyListeners();
      }
    }
  }

  Future<void> setMinutes(int value) async {
    minutes = value;
    await _prefs?.setInt('applockMinutes', value);
    notifyListeners();
  }

  Future<bool> unlock(String code) async {
    final value = _prefs?.getString('applock');
    if (value == null) return true;
    final parts = value.split('|');
    if (parts.length < 2) return false;
    if (await lockHash(parts[0], code) != parts[1]) return false;
    locked = false;
    notifyListeners();
    return true;
  }

  Future<bool> check(String code) async {
    final value = _prefs?.getString('applock');
    if (value == null) return true;
    final parts = value.split('|');
    return parts.length >= 2 && await lockHash(parts[0], code) == parts[1];
  }

  Future<void> set(String code) async {
    final rnd = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => rnd.nextInt(256)));
    await _prefs?.setString('applock', '$salt|${await lockHash(salt, code)}');
    notifyListeners();
  }

  Future<void> remove() async {
    await _prefs?.remove('applock');
    locked = false;
    notifyListeners();
  }
}

class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLock,
      builder: (context, _) => Stack(
        children: [
          Offstage(offstage: appLock.locked, child: child),
          if (appLock.locked)
            Overlay(initialEntries: [
              OverlayEntry(builder: (_) => const _LockScreen()),
            ]),
        ],
      ),
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _ctl = TextEditingController();
  bool _error = false;
  bool _busy = false;
  int _fails = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await appLock.unlock(_ctl.text);
    if (!mounted) return;
    if (!ok) {
      _fails++;
      if (_fails >= 3) {
        await Future<void>.delayed(Duration(seconds: min(30, _fails * 3)));
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = !ok;
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Tg.theme,
      child: Scaffold(
        backgroundColor: Tg.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 48, color: Tg.link),
                  const SizedBox(height: 16),
                  const Text('GenGram заблокирован',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ctl,
                    autofocus: true,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Код',
                      errorText: _error ? 'Неверный код' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Открыть'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> setupAppLock(BuildContext context) async {
  Future<String?> ask(String title) {
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
              onSubmitted: (v) => Navigator.pop(ctx, v)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('Готово')),
          ],
        ),
      ),
    ).whenComplete(ctl.dispose);
  }

  if (appLock.enabled) {
    final cur = await ask('Текущий код');
    if (cur == null) return;
    if (!await appLock.check(cur)) {
      tgToast('Неверный код');
      return;
    }
    if (!context.mounted) return;
    final remove = await tgConfirm(context,
        title: 'Код на приложение',
        text: 'Снять код совсем или задать новый?',
        yes: 'Снять код');
    if (remove) {
      await appLock.remove();
      tgToast('Код снят');
      return;
    }
  }
  final code = await ask('Новый код (не короче 4 символов)');
  if (code == null) return;
  if (code.length < 4) {
    tgToast('Слишком короткий код');
    return;
  }
  await appLock.set(code);
  tgToast('Код на приложение поставлен');
}
