# Сборка GenGram на Windows

Нужно: Windows 10/11 x64, 20 ГБ места, 4 ГБ ОЗУ минимум (при 4 ГБ увеличьте файл подкачки до 16 ГБ).

## 1. Инструменты

1. Visual Studio Build Tools 2022 (или Community). В установщике отметить «Разработка классических приложений на C++», а справа в списке компонентов добавить «C++ ATL для последних средств сборки» и Windows SDK.
2. Git for Windows.
3. CMake (при установке «Add to PATH»).
4. Flutter SDK: распаковать архив с flutter.dev в `C:\src\flutter` (путь без пробелов и русских букв), добавить `C:\src\flutter\bin` в PATH.
5. Включить режим разработчика Windows (нужен плагинам): `start ms-settings:developers`.
6. Закрыть и открыть новое окно cmd, проверить: `flutter doctor`. Для Windows должна стоять галочка у «Visual Studio».

## 2. Проект

```
cd /d D:\gengram
flutter config --enable-windows-desktop
flutter create --platforms=windows,android --org com.gengram .
flutter pub get
```

`lib/` и `pubspec.yaml` команда `create` не трогает.

## 3. TDLib (tdjson.dll)

В «x64 Native Tools Command Prompt for VS 2022»:

```
cd /d D:\gengram\tools
powershell -ExecutionPolicy Bypass -File build_tdlib_windows.ps1
```

Идёт 1–2 часа, на 4 ГБ ОЗУ закройте всё остальное. Результат: папка `tools\tdlib_dll` с `tdjson.dll` и несколькими dll рядом.

## 4. Запуск и сборка

```
cd /d D:\gengram
flutter run -d windows
```

Первый запуск соберёт приложение (несколько минут), и сразу выдаст ошибку про `tdjson.dll`, пока dll не лежат рядом с exe. Скопировать всё из `tools\tdlib_dll` в `build\windows\x64\runner\Debug\`, запустить снова.

Готовая версия:

```
flutter build windows --release
```

Копировать dll в `build\windows\x64\runner\Release\`. Эта папка целиком и есть программа: `gengram.exe` запускать оттуда, переносить только всю папку.

## 5. Ошибки

Лог в файл и поиск строк с ошибкой:

```
flutter run -d windows > D:\flutter.log 2>&1
findstr /i /c:"error" D:\flutter.log
```

- `Unable to find suitable Visual Studio toolchain`: не поставлен компонент C++ для Windows.
- `Building with plugins requires symlink support`: не включён режим разработчика.
- `Failed to load dynamic library 'tdjson.dll'`: dll лежат не рядом с `gengram.exe` или нет одной из соседних (`libcrypto`, `libssl`, `zlib`).
- ошибка про ATL или `atlbase.h`: не поставлен «C++ ATL».
- ошибка про `nuget`: установить nuget.exe и добавить в PATH.

## Android (APK через GitHub Actions)

Сборка идёт на серверах GitHub: workflow `.github/workflows/android.yml` собирает TDLib для arm64 и приложение. Локально Android SDK не нужен.

1. Создать пустой приватный репозиторий на github.com.
2. В папке проекта: `git init`, `git add .`, `git commit -m "GenGram"`, `git branch -M main`, `git remote add origin <адрес>`, `git push -u origin main`.
3. Вкладка Actions, workflow `android`, Run workflow. Сборка 40-70 минут.
4. В готовом запуске внизу артефакт `GenGram-apk`: скачать, распаковать, перенести `app-release.apk` на телефон и установить (разрешить установку из неизвестных источников).
