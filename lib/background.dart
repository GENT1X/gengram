import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:tray_manager/legacy.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'accounts.dart';

final background = Background();

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class Background with TrayListener, WindowListener {
  bool _trayReady = false;

  Future<void> init() async {
    if (_isDesktop) await _initDesktop();
    if (Platform.isAndroid) _initAndroid();
  }

  Future<void> _initDesktop() async {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: const Size(1000, 700),
      minimumSize: const Size(420, 560),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    try {
      trayManager.addListener(this);
      await trayManager.setIcon(
          Platform.isWindows ? 'assets/tray.ico' : 'assets/tray.png');
      if (!Platform.isLinux) await trayManager.setToolTip('GenGram');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Открыть GenGram'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Выйти'),
      ]));
      _trayReady = true;
    } catch (_) {
      _trayReady = false;
    }
  }

  @override
  Future<void> onWindowClose() async {
    if (settings.runInBackground && _trayReady) {
      await windowManager.hide();
    } else {
      await quit();
    }
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') _showWindow();
    if (menuItem.key == 'exit') quit();
  }

  Future<void> showWindow() async {
    if (!_isDesktop) return;
    await _showWindow();
  }

  Future<void> setBadge(int count) async {
    if (!_trayReady || Platform.isLinux) return;
    await trayManager.setToolTip(count > 0 ? 'GenGram · $count' : 'GenGram');
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quit() async {
    await accounts.flushAll();
    if (_trayReady) await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  void _initAndroid() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'gengram_background',
        channelName: 'GenGram в фоне',
        channelDescription:
            'Позволяет GenGram сохранять удалённые сообщения, пока приложение свёрнуто.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> sync({bool ask = false}) async {
    if (!Platform.isAndroid) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (settings.runInBackground && !running) {
      if (ask) {
        final perm = await FlutterForegroundTask.checkNotificationPermission();
        if (perm != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
        if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        }
      }
      await FlutterForegroundTask.startService(
        notificationTitle: 'GenGram работает в фоне',
        notificationText: 'Сохраняю удалённые сообщения',
      );
    } else if (!settings.runInBackground && running) {
      await FlutterForegroundTask.stopService();
    }
  }
}
