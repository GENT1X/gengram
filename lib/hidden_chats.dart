import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';

final hidden = HiddenChats();

class HiddenChats extends ChangeNotifier {
  static const _channel = MethodChannel('gengram/keys');

  bool _revealed = false;
  Timer? _timer;
  DateTime? _lastVolumeUp;
  AppLifecycleListener? _lifecycle;

  bool get revealed => _revealed;

  bool isVisible(int chatId) =>
      _revealed || !settings.hiddenIds.contains(chatId);

  void start() {
    HardwareKeyboard.instance.addHandler(_onKey);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') _volumeUp();
    });
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      if (state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused) {
        conceal();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _lifecycle?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !settings.revealByVolume) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      _volumeUp();
      return false;
    }
    if (key == LogicalKeyboardKey.keyH &&
        HardwareKeyboard.instance.isControlPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      toggle();
      return true;
    }
    return false;
  }

  void _volumeUp() {
    if (!settings.revealByVolume) return;
    final now = DateTime.now();
    final last = _lastVolumeUp;
    if (last != null && now.difference(last) < const Duration(milliseconds: 80)) {
      return;
    }
    if (last != null && now.difference(last) < const Duration(milliseconds: 700)) {
      _lastVolumeUp = null;
      toggle();
    } else {
      _lastVolumeUp = now;
    }
  }

  void toggle() => _revealed ? conceal() : reveal();

  void reveal() {
    _timer?.cancel();
    _revealed = true;
    final seconds = settings.revealSeconds;
    if (seconds > 0) _timer = Timer(Duration(seconds: seconds), conceal);
    HapticFeedback.mediumImpact();
    notifyListeners();
    messengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(settings.hiddenIds.isEmpty
            ? 'Скрытых чатов нет'
            : 'Скрытые чаты открыты'),
      ));
  }

  void conceal() {
    _timer?.cancel();
    _timer = null;
    if (!_revealed) return;
    _revealed = false;
    notifyListeners();
  }
}
