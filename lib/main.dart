import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'accounts.dart';
import 'app_lock.dart';
import 'app_state.dart';
import 'auth_page.dart';
import 'background.dart';
import 'hidden_chats.dart';
import 'local_emoji.dart';
import 'message_filters.dart';
import 'streamer.dart';
import 'home_page.dart';
import 'notifier.dart';
import 'themes.dart';
import 'premium.dart';
import 'tg_style.dart';

RandomAccessFile? _instanceLock;

Future<bool> _acquireSingleInstance() async {
  RandomAccessFile file;
  try {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    file = await File('${dir.path}/gengram.lock').open(mode: FileMode.write);
  } catch (_) {
    return true;
  }
  try {
    await file.lock(FileLock.exclusive);
    _instanceLock = file;
    return true;
  } on FileSystemException {
    await file.close();
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (!await _acquireSingleInstance()) {
    runApp(const _AlreadyRunningApp());
    return;
  }
  await settings.load();
  await themes.load();
  await localEmoji.load();
  await messageFilters.load();
  await premium.load();
  await background.init();
  await accounts.init();
  hidden.start();
  await appLock.init();
  await notifier.init();
  unawaited(background.sync());
  runApp(const GenGramApp());
  if (settings.streamer) {
    WidgetsBinding.instance.addPostFrameCallback((_) => setCaptureProtection(true));
  }
}

class GenGramApp extends StatelessWidget {
  const GenGramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) => _app(),
    );
  }

  Widget _app() {
    final scheme = ThemeData(
      brightness: Tg.p.dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: Tg.p.accent,
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'GenGram',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      builder: (context, child) => AppLockGate(child: child ?? const SizedBox()),
      themeMode: Tg.p.dark ? ThemeMode.dark : ThemeMode.light,
      theme: scheme,
      darkTheme: scheme,
      home: Theme(
        data: Tg.theme,
        child: ListenableBuilder(
          listenable: accounts,
          builder: (context, _) {
            final id = accounts.active.id;
            return AuthGate(
              key: ValueKey('auth$id'),
              onReady: (_) => HomePage(key: ValueKey('home$id')),
            );
          },
        ),
      ),
    );
  }
}

class _AlreadyRunningApp extends StatelessWidget {
  const _AlreadyRunningApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Tg.theme,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('GenGram уже запущен',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Tg.text)),
                  SizedBox(height: 12),
                  Text(
                      'Он свёрнут в трей (значки возле часов, стрелка вверх). '
                      'Нажми на его значок, чтобы открыть окно. Если значка нет, '
                      'завершите gengram.exe в диспетчере задач и запустите заново.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, height: 1.4, color: Tg.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
