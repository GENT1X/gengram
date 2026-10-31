# GenGram

Клиент Telegram на Flutter и TDLib. Windows, Linux, macOS, Android.

## Сборка

1. Положить `tdjson` рядом с приложением (`tdjson.dll`, `libtdjson.so`, `libtdjson.dylib`). Для Windows есть `tools/build_tdlib_windows.ps1`.
2. Свои `apiId` и `apiHash` вписать в `lib/config.dart`.
3. `flutter pub get`, затем `flutter run -d windows` или `-d android`.

## Что умеет

- вход по номеру, коду, паролю и QR; несколько аккаунтов
- режим призрака: скрытие «в сети» и отключение отметки о прочтении (отдельно, с исключениями по чатам)
- сохранение удалённых сообщений и истории правок; исчезающие фото и видео
- скрытые чаты (жест, двойное нажатие на название или Ctrl+Shift+H)
- код на приложение и на отдельный чат с кодом-паникой, шифрование базы TDLib
- слежение за сеансами
- уведомления, поиск по всем чатам, вкладки медиа в профиле, баннер профиля
- отложенная и тихая отправка, ответ с цитатой, закреплённые и отложенные списком
- секретные чаты
- автоперевод (Telegram или LibreTranslate)
- 9 тем, свой акцент, день и ночь по системе
- встроенный плеер, стикеры и эмодзи, подарки, Premium-оформление
- фоновая работа: трей на ПК, foreground-сервис на Android

## Android

В `AndroidManifest.xml` разрешения `INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_REMOTE_MESSAGING`, `POST_NOTIFICATIONS`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` и внутри `<application>`:

```xml
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="remoteMessaging"
    android:exported="false" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
```

Для двойного нажатия громкости в `MainActivity.kt` перехватывается `KEYCODE_VOLUME_UP` и отправляется в канал `gengram/keys` (`volumeUp`).

## Файлы

Копии удалённых сообщений: `gengram_messages*.json`. Сохранённые исчезающие: `gengram_saved/`. Баннеры: `gengram_banners/`. Всё в папке данных приложения.
