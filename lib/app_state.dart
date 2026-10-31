import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounts.dart';
import 'td_client.dart';

TdClient get td => accounts.active.td;
final settings = AppSettings();

final messengerKey = GlobalKey<ScaffoldMessengerState>();

final navigatorKey = GlobalKey<NavigatorState>();

class AppSettings extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool ghost = true;

  bool ghostHideOnline = true;

  bool ghostNoRead = true;

  Set<int> ghostReadIds = {};

  bool noReadIn(int chatId) =>
      ghost && ghostNoRead && !ghostReadIds.contains(chatId);

  bool saveDeleted = true;

  bool runInBackground = true;

  // ---- Скрытые чаты ----

  Set<int> hiddenIds = {};

  bool revealByVolume = true;

  bool revealByTitle = true;

  int revealSeconds = 30;

  double chatTextSize = 15.5;

  int wallpaper = 1;
  bool doodles = true;

  bool sendByEnter = true;

  bool notify = true;

  bool notifyPreview = true;

  bool saver = false;

  bool keepSelfDestruct = true;

  int maxStickers = 6;

  String deletedMark = 'удалено';
  int deletedColor = 0xFFFF5555;

  bool guardSessions = true;
  bool streamer = false;
  double bubbleRadius = 16;
  double bubbleWidth = 520;
  bool roundStickers = false;
  bool showIds = false;
  bool showSeconds = false;
  bool silentSend = false;
  bool doubleTapReact = true;

  // ---- Автоперевод ----

  bool autoTranslate = false;

  String translateTo = 'ru';

  String translateProvider = 'telegram';
  String libreUrl = '';
  String libreKey = '';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    ghost = _prefs.getBool('ghost') ?? true;
    ghostHideOnline = _prefs.getBool('ghostHideOnline') ?? true;
    ghostNoRead = _prefs.getBool('ghostNoRead') ?? true;
    ghostReadIds = (_prefs.getStringList('ghostReadIds') ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    saveDeleted = _prefs.getBool('saveDeleted') ?? true;
    runInBackground = _prefs.getBool('runInBackground') ?? true;
    hiddenIds = (_prefs.getStringList('hiddenIds') ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    revealByVolume = _prefs.getBool('revealByVolume') ?? true;
    revealByTitle = _prefs.getBool('revealByTitle') ?? true;
    revealSeconds = _prefs.getInt('revealSeconds') ?? 30;
    chatTextSize = _prefs.getDouble('chatTextSize') ?? 15.5;
    sendByEnter = _prefs.getBool('sendByEnter') ?? true;
    wallpaper = _prefs.getInt('wallpaper') ?? 1;
    doodles = _prefs.getBool('doodles') ?? true;
    autoTranslate = _prefs.getBool('autoTranslate') ?? false;
    translateTo = _prefs.getString('translateTo') ?? 'ru';
    translateProvider = _prefs.getString('translateProvider') ?? 'telegram';
    libreUrl = _prefs.getString('libreUrl') ?? '';
    libreKey = _prefs.getString('libreKey') ?? '';
    notify = _prefs.getBool('notify') ?? true;
    notifyPreview = _prefs.getBool('notifyPreview') ?? true;
    saver = _prefs.getBool('saver') ?? false;
    keepSelfDestruct = _prefs.getBool('keepSelfDestruct') ?? true;
    maxStickers = _prefs.getInt('maxStickers') ?? 6;
    deletedMark = _prefs.getString('deletedMark') ?? 'удалено';
    deletedColor = _prefs.getInt('deletedColor') ?? 0xFFFF5555;
    guardSessions = _prefs.getBool('guardSessions') ?? true;
    streamer = _prefs.getBool('streamer') ?? false;
    bubbleRadius = _prefs.getDouble('bubbleRadius') ?? 16;
    bubbleWidth = _prefs.getDouble('bubbleWidth') ?? 520;
    roundStickers = _prefs.getBool('roundStickers') ?? false;
    showIds = _prefs.getBool('showIds') ?? false;
    showSeconds = _prefs.getBool('showSeconds') ?? false;
    silentSend = _prefs.getBool('silentSend') ?? false;
    doubleTapReact = _prefs.getBool('doubleTapReact') ?? true;
  }

  Future<void> change(void Function() mutate) async {
    mutate();
    notifyListeners();
    await _put('ghost', ghost);
    await _put('ghostHideOnline', ghostHideOnline);
    await _put('ghostNoRead', ghostNoRead);
    await _put('ghostReadIds', ghostReadIds.map((e) => '$e').toList());
    await _put('saveDeleted', saveDeleted);
    await _put('runInBackground', runInBackground);
    await _put('hiddenIds', hiddenIds.map((e) => '$e').toList());
    await _put('revealByVolume', revealByVolume);
    await _put('revealByTitle', revealByTitle);
    await _put('revealSeconds', revealSeconds);
    await _put('chatTextSize', chatTextSize);
    await _put('sendByEnter', sendByEnter);
    await _put('wallpaper', wallpaper);
    await _put('doodles', doodles);
    await _put('autoTranslate', autoTranslate);
    await _put('translateTo', translateTo);
    await _put('translateProvider', translateProvider);
    await _put('libreUrl', libreUrl);
    await _put('libreKey', libreKey);
    await _put('notify', notify);
    await _put('notifyPreview', notifyPreview);
    await _put('saver', saver);
    await _put('keepSelfDestruct', keepSelfDestruct);
    await _put('maxStickers', maxStickers);
    await _put('deletedMark', deletedMark);
    await _put('deletedColor', deletedColor);
    await _put('guardSessions', guardSessions);
    await _put('streamer', streamer);
    await _put('bubbleRadius', bubbleRadius);
    await _put('bubbleWidth', bubbleWidth);
    await _put('roundStickers', roundStickers);
    await _put('showIds', showIds);
    await _put('showSeconds', showSeconds);
    await _put('silentSend', silentSend);
    await _put('doubleTapReact', doubleTapReact);
  }

  Future<void> _put(String key, Object value) async {
    final old = _prefs.get(key);
    if (value is List<String>) {
      if (old is List && old.length == value.length) {
        var same = true;
        for (var i = 0; i < value.length; i++) {
          if (old[i] != value[i]) {
            same = false;
            break;
          }
        }
        if (same) return;
      }
      await _prefs.setStringList(key, value);
    } else if (old != value) {
      if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is String) {
        await _prefs.setString(key, value);
      }
    }
  }

  Future<void> setGhost(bool value) => change(() => ghost = value);

  Future<void> setSaveDeleted(bool value) => change(() => saveDeleted = value);

  Future<void> setHidden(int chatId, bool hide) => change(() {
        if (hide) {
          hiddenIds = {...hiddenIds, chatId};
        } else {
          hiddenIds = hiddenIds.where((id) => id != chatId).toSet();
        }
      });
}

Future<void> applyGhost(bool value) async {
  await settings.setGhost(value);
  await Future.wait([
    for (final a in accounts.list)
      if (a.ready) sendGhost(a.td, value),
  ]);
}

Future<void> reapplyGhost() => applyGhost(settings.ghost);

Future<void> sendGhost(TdClient client, bool ghost) async {
  await client.request({
    '@type': 'setOption',
    'name': 'online',
    'value': {
      '@type': 'optionValueBoolean',
      'value': !(ghost && settings.ghostHideOnline)
    },
  });
}

String messageText(Map content) {
  if (content['@type'] == 'messageText') {
    return (content['text']?['text'] ?? '') as String;
  }
  final type = content['@type'].toString();
  final label = _mediaLabels[type] ??
      '[${type.replaceFirst('message', '')}]';
  final caption = (content['caption']?['text'] ?? '') as String;
  return caption.isEmpty ? label : '$label $caption';
}

const _mediaLabels = <String, String>{
  'messagePhoto': '[Фото]',
  'messageVideo': '[Видео]',
  'messageAnimation': '[GIF]',
  'messageAudio': '[Музыка]',
  'messageVoiceNote': '[Голосовое]',
  'messageVideoNote': '[Кружок]',
  'messageDocument': '[Файл]',
  'messageSticker': '[Стикер]',
  'messageContact': '[Контакт]',
  'messageLocation': '[Геопозиция]',
  'messageVenue': '[Место]',
  'messagePoll': '[Опрос]',
  'messageCall': '[Звонок]',
  'messageBasicGroupChatCreate': '[Группа создана]',
  'messageSupergroupChatCreate': '[Группа создана]',
  'messageChatJoinByLink': '[Вступил(а) по ссылке]',
  'messageChatAddMembers': '[Добавлены участники]',
  'messageChatDeleteMember': '[Участник вышел]',
  'messagePinMessage': '[Закреплено сообщение]',
};

Future<void> applySaver(TdClient client) async {
  final presets = await client.request({'@type': 'getAutoDownloadSettingsPresets'});
  final medium = presets['medium'] as Map<String, dynamic>?;
  for (final network in const [
    'networkTypeMobile',
    'networkTypeWiFi',
    'networkTypeMobileRoaming',
  ]) {
    final value = <String, dynamic>{...?medium};
    value['@type'] = 'autoDownloadSettings';
    value['is_auto_download_enabled'] = !settings.saver;
    await client.request({
      '@type': 'setAutoDownloadSettings',
      'settings': value,
      'type': {'@type': network},
    });
  }
}

Future<void> reapplySaver() async {
  await Future.wait([
    for (final a in accounts.list)
      if (a.ready) applySaver(a.td),
  ]);
}
