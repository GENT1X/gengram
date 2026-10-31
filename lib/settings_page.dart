import 'dart:io';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'background.dart';
import 'gengram_icons.dart';
import 'app_lock.dart';
import 'guard.dart';
import 'hidden_chats.dart';
import 'keeper.dart';
import 'streamer.dart';
import 'accounts.dart';
import 'message_store.dart';
import 'trash_icon.dart';
import 'translator.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _urlCtl = TextEditingController(text: settings.libreUrl);
  late final _keyCtl = TextEditingController(text: settings.libreKey);
  bool _testing = false;

  @override
  void dispose() {
    _urlCtl.dispose();
    _keyCtl.dispose();
    super.dispose();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить сохранённые?'),
        content: Text(
            'Будут стёрты ${store.deletedCount} сохранённых удалённых сообщений на этом устройстве.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Очистить')),
        ],
      ),
    );
    if (ok == true) {
      await store.clearDeleted();
      if (mounted) setState(() {});
    }
  }

  Future<void> _testTranslation() async {
    setState(() => _testing = true);
    final message = await translator.test();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки GenGram')),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, hidden]),
        builder: (context, _) => ListView(
          children: [
            const _Section('Приватность'),
            SwitchListTile(
              secondary: GenIcon(settings.ghost ? GIcon.ghost : GIcon.ghostVisible),
              title: const Text('Режим призрака'),
              subtitle: const Text(
                  'Другие не видят, что ты в сети, и не видят, что ты прочитал их сообщения.'),
              value: settings.ghost,
              onChanged: (v) => applyGhost(v),
            ),
            if (settings.ghost) ...[
              SwitchListTile(
                secondary: const GenIcon(GIcon.ghostVisible),
                title: const Text('Скрывать «в сети»'),
                subtitle: const Text(
                    'Собеседники не видят, что ты онлайн. Если выключить, '
                    'ты будешь появляться в сети, но сообщения всё равно не читаются.'),
                value: settings.ghostHideOnline,
                onChanged: (v) async {
                  await settings.change(() => settings.ghostHideOnline = v);
                  await reapplyGhost();
                },
              ),
              SwitchListTile(
                secondary: const GenIcon(GIcon.ghost),
                title: const Text('Не отмечать прочитанным'),
                subtitle: const Text(
                    'Двойная галочка у собеседника не появится. '
                    'Исключения для отдельных чатов — кнопка-призрак в самом чате. '
                    'Когда ты сам отправляешь сообщение в чат, Telegram всё равно '
                    'считает чат прочитанным.'),
                value: settings.ghostNoRead,
                onChanged: (v) => settings.change(() => settings.ghostNoRead = v),
              ),
              ListTile(
                leading: const GenIcon(GIcon.info),
                title: const Text('Чатов с исключениями'),
                subtitle: const Text(
                    'Нажми, чтобы сбросить. Время «был(а) в сети» ещё зависит от настройки Telegram '
                    '«Конфиденциальность → Был(а) в сети».'),
                trailing: Text('${settings.ghostReadIds.length}'),
                onTap: settings.ghostReadIds.isEmpty
                    ? null
                    : () => settings.change(() => settings.ghostReadIds = {}),
              ),
            ],

            const _Section('Скрытые чаты'),
            SwitchListTile(
              secondary: const GenIcon(GIcon.volume),
              title: const Text('Двойное нажатие громкости вверх'),
              subtitle: const Text(
                  'Открывает скрытые чаты, повторное двойное нажатие закрывает их. '
                  'На ПК то же делает Ctrl+Shift+H. На телефоне нужен один шаг настройки, он описан в README.'),
              value: settings.revealByVolume,
              onChanged: (v) => settings.change(() => settings.revealByVolume = v),
            ),
            SwitchListTile(
              secondary: const GenIcon(GIcon.hiddenChat),
              title: const Text('Двойное нажатие на название GenGram'),
              subtitle: const Text(
                  'Название в верхней строке списка чатов. Работает и на ПК, и на телефоне.'),
              value: settings.revealByTitle,
              onChanged: (v) => settings.change(() => settings.revealByTitle = v),
            ),
            ListTile(
              leading: const GenIcon(GIcon.timer),
              title: const Text('Сколько показывать скрытые чаты'),
              subtitle: const Text(
                  'Они закроются и раньше, если свернуть GenGram.'),
              trailing: DropdownButton<int>(
                value: settings.revealSeconds,
                onChanged: (v) {
                  if (v != null) settings.change(() => settings.revealSeconds = v);
                },
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 секунд')),
                  DropdownMenuItem(value: 30, child: Text('30 секунд')),
                  DropdownMenuItem(value: 60, child: Text('1 минуту')),
                  DropdownMenuItem(value: 300, child: Text('5 минут')),
                  DropdownMenuItem(value: 0, child: Text('Пока не закрою')),
                ],
              ),
            ),
            ListTile(
              leading: const GenIcon(GIcon.lock),
              title: const Text('Скрытые чаты'),
              subtitle: Text(hidden.revealed
                  ? 'Скрыто: ${settings.hiddenIds.length}'
                  : 'Список доступен, когда скрытые чаты открыты. '
                      'Чтобы скрыть чат, зажми его в списке чатов.'),
              trailing: TextButton(
                onPressed: hidden.revealed
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const _HiddenChatsPage()))
                    : null,
                child: const Text('Управлять'),
              ),
            ),

            const _Section('Удалённые сообщения'),
            SwitchListTile(
              secondary: const TrashIcon(size: 24),
              title: const Text('Сохранять удалённые сообщения'),
              subtitle: const Text(
                  'Если собеседник удалит сообщение, GenGram покажет его копию с пометкой. '
                  'Сохраняются только сообщения, которые GenGram успел получить. '
                  'Копии хранятся только на этом устройстве.'),
              value: settings.saveDeleted,
              onChanged: (v) => settings.setSaveDeleted(v),
            ),
            SwitchListTile(
              secondary: const GenIcon(GIcon.moon),
              title: const Text('Работать в фоне'),
              subtitle: Text(Platform.isAndroid
                  ? 'GenGram остаётся запущенным (в шторке будет уведомление), поэтому удалённые '
                      'сообщения сохраняются, пока приложение свёрнуто. Разреши работу без ограничений батареи.'
                  : 'Закрытие окна сворачивает GenGram в трей, поэтому удалённые сообщения '
                      'сохраняются, пока окно закрыто. Выйти совсем: правая кнопка по значку в трее, «Выйти».'),
              value: settings.runInBackground,
              onChanged: (v) async {
                await settings.change(() => settings.runInBackground = v);
                await background.sync(ask: v);
              },
            ),
            ListTile(
              leading: const TrashIcon(size: 24),
              title: const Text('Сохранённых удалённых сообщений'),
              subtitle: Text('${store.deletedCount}'),
              trailing: TextButton(
                  onPressed: store.deletedCount == 0 ? null : _clear,
                  child: const Text('Очистить')),
            ),

            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Сохранённые исчезающие фото и видео'),
              subtitle: const Text('Копии того, что Telegram доставил этому устройству'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SavedMediaPage())),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.save_alt_outlined),
              title: const Text('Сохранять исчезающие фото и видео'),
              subtitle: const Text(
                  'Одноразовое медиа сохраняется, когда вы сами его открыли.'),
              value: settings.keepSelfDestruct,
              onChanged: (v) => settings.change(() => settings.keepSelfDestruct = v),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Подпись у удалённых'),
              subtitle: Text(settings.deletedMark),
              onTap: () async {
                final ctl = TextEditingController(text: settings.deletedMark);
                final v = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Подпись у удалённых'),
                    content: TextField(controller: ctl, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                      TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Готово')),
                    ],
                  ),
                );
                ctl.dispose();
                if (v != null && v.trim().isNotEmpty) {
                  settings.change(() => settings.deletedMark = v.trim());
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: Color(settings.deletedColor)),
              title: const Text('Цвет рамки у удалённых'),
              trailing: Wrap(spacing: 8, children: [
                for (final c in const [0xFFFF5555, 0xFFFFB020, 0xFFB26BFF, 0xFF4FC3F7, 0xFF66BB6A])
                  GestureDetector(
                    onTap: () => settings.change(() => settings.deletedColor = c),
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Color(c),
                      child: settings.deletedColor == c
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
              ]),
            ),

            const _Section('Уведомления и экономия'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Уведомления о сообщениях'),
              subtitle: Text(Platform.isAndroid
                  ? 'Системные уведомления с ответом прямо из шторки. Счётчик на значке.'
                  : 'Системные уведомления Windows, даже когда окно в трее. Счётчик в подсказке значка.'),
              value: settings.notify,
              onChanged: (v) => settings.change(() => settings.notify = v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text('Показывать текст в уведомлении'),
              value: settings.notifyPreview,
              onChanged: settings.notify
                  ? (v) => settings.change(() => settings.notifyPreview = v)
                  : null,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.battery_saver_outlined),
              title: const Text('Режим экономии батареи и трафика'),
              subtitle: const Text(
                  'Фото и видео не скачиваются сами, анимированные стикеры стоят на месте.'),
              value: settings.saver,
              onChanged: (v) async {
                await settings.change(() => settings.saver = v);
                await reapplySaver();
              },
            ),
            ListTile(
              leading: const Icon(Icons.animation),
              title: const Text('Анимированных стикеров одновременно'),
              subtitle: Slider(
                min: 1,
                max: 15,
                divisions: 14,
                label: '${settings.maxStickers}',
                value: settings.maxStickers.toDouble(),
                onChanged: (v) =>
                    settings.change(() => settings.maxStickers = v.round()),
              ),
            ),

            const _Section('Безопасность'),
            SwitchListTile(
              secondary: const Icon(Icons.shield_outlined),
              title: const Text('Слежение за сеансами'),
              subtitle: const Text(
                  'Предупреждать, если в аккаунт вошло новое устройство, и предлагать завершить сеанс.'),
              value: settings.guardSessions,
              onChanged: (v) async {
                await settings.change(() => settings.guardSessions = v);
                if (v) await guard.check(accounts.active);
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.live_tv_outlined),
              title: const Text('Режим стримера'),
              subtitle: const Text(
                  'Окно не попадает в запись экрана и трансляции, номера телефонов скрываются.'),
              value: settings.streamer,
              onChanged: (v) async {
                await settings.change(() => settings.streamer = v);
                setCaptureProtection(v);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Код на приложение'),
              subtitle: Text(appLock.enabled
                  ? 'Включён. Спрашивается при запуске и после паузы.'
                  : 'Выключен'),
              onTap: () async {
                await setupAppLock(context);
                setState(() {});
              },
            ),
            if (appLock.enabled)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Блокировать через'),
                trailing: DropdownButton<int>(
                  value: appLock.minutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('сразу')),
                    DropdownMenuItem(value: 1, child: Text('1 мин')),
                    DropdownMenuItem(value: 5, child: Text('5 мин')),
                    DropdownMenuItem(value: 15, child: Text('15 мин')),
                    DropdownMenuItem(value: 60, child: Text('1 час')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await appLock.setMinutes(v);
                    setState(() {});
                  },
                ),
              ),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Код на отдельный чат'),
              subtitle: Text('Откройте чат → меню ⋮ → «Код на этот чат». Там же код-паника.'),
            ),

            const _Section('Автоперевод'),
            SwitchListTile(
              secondary: const GenIcon(GIcon.translate),
              title: const Text('Переводить сообщения'),
              subtitle: const Text(
                  'Текст входящих сообщений заменяется переводом. '
                  'Нажми на сообщение, чтобы увидеть оригинал.'),
              value: settings.autoTranslate,
              onChanged: (v) => settings.change(() => settings.autoTranslate = v),
            ),
            if (settings.autoTranslate) ...[
              ListTile(
                leading: const GenIcon(GIcon.globe),
                title: const Text('Переводить на'),
                trailing: DropdownButton<String>(
                  value: settings.translateTo,
                  onChanged: (v) {
                    if (v != null) settings.change(() => settings.translateTo = v);
                  },
                  items: [
                    for (final l in translateLanguages)
                      DropdownMenuItem(value: l.$1, child: Text(l.$2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'telegram', label: Text('Telegram')),
                    ButtonSegment(value: 'libre', label: Text('LibreTranslate')),
                  ],
                  selected: {settings.translateProvider},
                  onSelectionChanged: (s) =>
                      settings.change(() => settings.translateProvider = s.first),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  settings.translateProvider == 'telegram'
                      ? 'Переводит сам Telegram. Тексты не уходят никуда, кроме Telegram.'
                      : 'Тексты сообщений отправляются на сервер, адрес которого ты укажешь ниже. '
                          'Для полной приватности подними свой сервер.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              if (settings.translateProvider == 'libre') ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _urlCtl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                        labelText: 'Адрес сервера',
                        hintText: 'http://localhost:5000',
                        border: OutlineInputBorder()),
                    onChanged: (v) => settings.change(() => settings.libreUrl = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _keyCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Ключ API (если нужен)',
                        border: OutlineInputBorder()),
                    onChanged: (v) => settings.change(() => settings.libreKey = v),
                  ),
                ),
              ],
              ListTile(
                leading: const GenIcon(GIcon.checkCircle),
                title: const Text('Проверить перевод'),
                subtitle: const Text('Переведёт тестовую фразу и покажет результат или ошибку.'),
                trailing: _testing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: _testing ? null : _testTranslation,
              ),
            ],

            const _Section('О приложении'),
            const ListTile(
              leading: GenIcon(GIcon.info),
              title: Text('GenGram 0.1.0'),
              subtitle: Text(
                  'Неофициальный клиент Telegram. Не связан с Telegram и не одобрен им.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenChatsPage extends StatefulWidget {
  const _HiddenChatsPage();

  @override
  State<_HiddenChatsPage> createState() => _HiddenChatsPageState();
}

class _HiddenChatsPageState extends State<_HiddenChatsPage> {
  late Future<List<(int, String)>> _future = _load();

  @override
  void initState() {
    super.initState();
    hidden.addListener(_guard);
  }

  @override
  void dispose() {
    hidden.removeListener(_guard);
    super.dispose();
  }

  void _guard() {
    if (!hidden.revealed && mounted) Navigator.of(context).pop();
  }

  Future<List<(int, String)>> _load() async {
    final out = <(int, String)>[];
    for (final id in settings.hiddenIds) {
      final c = await td.request({'@type': 'getChat', 'chat_id': id});
      out.add((id, c['@type'] == 'chat' ? c['title'] as String : 'Чат $id'));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Скрытые чаты')),
      body: FutureBuilder<List<(int, String)>>(
        future: _future,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('Скрытых чатов нет'));
          }
          return ListView(
            children: [
              for (final (id, title) in items)
                ListTile(
                  leading: CircleAvatar(
                      child: Text(title.characters.firstOrNull ?? '?')),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(
                    onPressed: () async {
                      await settings.setHidden(id, false);
                      if (mounted) setState(() => _future = _load());
                    },
                    child: const Text('Вернуть в список'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600)),
      );
}
