import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'banner.dart';
import 'gengram_icons.dart';
import 'message_filters.dart';
import 'streamer.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'contacts_page.dart';
import 'doodle.dart';
import 'message_store.dart';
import 'plus_page.dart';
import 'themes_page.dart';
import 'premium.dart';
import 'profile_sheet.dart';
import 'settings_page.dart';
import 'tg_privacy.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

class TgSettingsPage extends StatelessWidget {
  const TgSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([accounts, premium]),
      builder: (context, _) {
        final a = accounts.active;
        return TgPage(
          title: 'Настройки',
          children: [
            _ProfileHeader(a),
            TgSection(
              title: 'Аккаунты',
              footer:
                  'Аккаунтов можно добавить сколько угодно. Нажмите на аккаунт, чтобы переключиться.',
              children: [
                for (final other in accounts.list)
                  if (other.id != a.id)
                    TgRow(
                      title: other.name,
                      subtitle: other.ready ? null : 'нужно войти',
                      leading: TgAvatar(id: other.id + 1, title: other.name, size: 36),
                      trailing: other.unread > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Tg.badge,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text('${other.unread}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        accounts.switchTo(other.id);
                      },
                    ),
                TgRow(
                  title: 'Добавить аккаунт',
                  icon: GIcon.plus,
                  iconColor: const Color(0xFF5288C1),
                  onTap: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    accounts.addAccount();
                  },
                ),
              ],
            ),
            TgSection(
              children: [
                TgRow(
                  title: 'Аккаунт',
                  subtitle: 'Имя, имя пользователя, «О себе»',
                  icon: GIcon.user,
                  iconColor: const Color(0xFF3A9BDC),
                  onTap: () => tgPush(context, const EditProfilePage()),
                ),
                TgRow(
                  title: 'Баннер профиля',
                  subtitle: 'Фото, GIF или видео, только на этом устройстве',
                  icon: GIcon.sliders,
                  iconColor: const Color(0xFFE5566D),
                  onTap: () => banners.pick((a.me?['id'] as int?) ?? 0),
                  trailing: IconButton(
                    tooltip: 'Убрать баннер',
                    icon: const Icon(Icons.close),
                    onPressed: () => banners.clear((a.me?['id'] as int?) ?? 0),
                  ),
                ),
                TgRow(
                  title: 'Фильтры сообщений',
                  subtitle: 'Скрывать входящие по слову или выражению',
                  icon: GIcon.sliders,
                  iconColor: const Color(0xFF3FAE5A),
                  onTap: () => tgPush(context, const FiltersPage()),
                ),
                TgRow(
                  title: 'Оформление',
                  subtitle: 'Темы, цвет акцента, день и ночь',
                  icon: GIcon.sliders,
                  iconColor: const Color(0xFF9B6BFF),
                  onTap: () => tgPush(context, const ThemesPage()),
                ),
                TgRow(
                  title: 'Настройки чатов',
                  subtitle: 'Обои, размер текста, отправка по Enter',
                  icon: GIcon.chat,
                  iconColor: const Color(0xFFE5A02E),
                  onTap: () => tgPush(context, const ChatSettingsPage()),
                ),
                TgRow(
                  title: 'Конфиденциальность',
                  subtitle: 'Время захода, номер, фото, звонки',
                  icon: GIcon.lock,
                  iconColor: const Color(0xFF3FAE5A),
                  onTap: () => tgPush(context, const PrivacyPage()),
                ),
                TgRow(
                  title: 'Уведомления',
                  subtitle: 'Личные чаты, группы, каналы',
                  icon: GIcon.volume,
                  iconColor: const Color(0xFFE5566D),
                  onTap: () => tgPush(context, const NotificationsPage()),
                ),
                TgRow(
                  title: 'Данные и память',
                  subtitle: 'Кэш, занятое место',
                  icon: GIcon.refresh,
                  iconColor: const Color(0xFF4A6FE0),
                  onTap: () => tgPush(context, const DataPage()),
                ),
                TgRow(
                  title: 'Папки с чатами',
                  subtitle: 'Сортировка чатов по папкам',
                  icon: GIcon.pin,
                  iconColor: const Color(0xFF3A9BDC),
                  onTap: () => tgPush(context, const FoldersPage()),
                ),
                TgRow(
                  title: 'Устройства',
                  subtitle: 'Управление активными сеансами',
                  icon: GIcon.phone,
                  iconColor: const Color(0xFF2EA6A6),
                  onTap: () => tgPush(context, const SessionsPage()),
                ),
                TgRow(
                  title: 'Язык',
                  subtitle: 'Русский',
                  icon: GIcon.globe,
                  iconColor: const Color(0xFF8A4FE0),
                  onTap: () => tgToast('Интерфейс GenGram пока только на русском'),
                ),
              ],
            ),
            TgSection(
              children: [
                TgRow(
                  title: 'GenGram Plus',
                  subtitle: 'Расширенные функции клиента',
                  icon: GIcon.star,
                  iconColor: const Color(0xFFB794FF),
                  onTap: () => tgPush(context, const PlusPage()),
                ),
                TgRow(
                  title: 'Premium',
                  icon: GIcon.star,
                  iconColor: const Color(0xFF8A4FE0),
                  onTap: () => tgPush(context, const PremiumPage()),
                ),
                TgRow(
                  title: 'Звёзды и подарки',
                  icon: GIcon.coin,
                  iconColor: const Color(0xFFE0A02E),
                  value: '${premium.starsOf()}',
                  onTap: () => tgPush(context, const StarsPage()),
                ),
                TgRow(
                  title: 'Отправить подарок',
                  icon: GIcon.gift,
                  iconColor: const Color(0xFFE08A2E),
                  onTap: () => sendGiftFlow(context),
                ),
              ],
            ),
            TgSection(
              title: 'Помощь',
              children: [
                TgRow(
                  title: 'Задать вопрос',
                  icon: GIcon.chat,
                  iconColor: const Color(0xFFE5A02E),
                  onTap: () => _askSupport(context),
                ),
                TgRow(
                  title: 'Вопросы о Telegram',
                  icon: GIcon.info,
                  iconColor: const Color(0xFF3A9BDC),
                  onTap: () => _link('https://telegram.org/faq?setln=ru'),
                ),
                TgRow(
                  title: 'Политика конфиденциальности',
                  icon: GIcon.lock,
                  iconColor: const Color(0xFF3FAE5A),
                  onTap: () => _link('https://telegram.org/privacy?setln=ru'),
                ),
              ],
            ),
            TgSection(
              title: 'GenGram',
              children: [
                TgRow(
                  title: 'Настройки GenGram',
                  subtitle: 'Призрак, удалённые сообщения, скрытые чаты, перевод',
                  icon: GIcon.ghost,
                  iconColor: const Color(0xFF7B4FD6),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
                TgRow(
                  title: 'Выйти из этого аккаунта',
                  icon: GIcon.logout,
                  iconColor: Tg.danger,
                  danger: true,
                  onTap: () => _logout(context, a),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static Future<void> _link(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<void> _askSupport(BuildContext context) async {
    final u = await td.request({'@type': 'getSupportUser'});
    if (u['@type'] != 'user') {
      tgToast('Поддержка сейчас недоступна');
      return;
    }
    final chat = await td.request(
        {'@type': 'createPrivateChat', 'user_id': u['id'], 'force': false});
    if (chat['@type'] != 'chat' || !context.mounted) return;
    await tgPush(context,
        ChatPage(chatId: chat['id'] as int, title: chat['title'] as String));
  }

  Future<void> _logout(BuildContext context, Account a) async {
    final ok = await tgConfirm(
      context,
      title: 'Выйти из аккаунта?',
      text:
          '${a.name} выйдет из GenGram. Сохранённые удалённые сообщения этого аккаунта на устройстве будут стёрты.',
      yes: 'Выйти',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await accounts.removeAccount(a);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader(this.account);
  final Account account;

  @override
  Widget build(BuildContext context) {
    final me = account.me;
    final themed = premium.isOn(account.id);
    final colors = premiumThemes[premium.themeOf(account.id)];
    final sub = [hideInStream(account.phone), account.username]
        .where((e) => e.isNotEmpty)
        .join('  ·  ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final id = me?['id'];
        if (id is int) showProfile(context, id, canWrite: false);
      },
      child: Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Tg.panel,
        gradient: themed ? LinearGradient(colors: colors) : null,
      ),
      child: Column(
        children: [
          BannerView(chatId: (me?['id'] as int?) ?? 0, height: 130),
          const SizedBox(height: 12),
          Row(
        children: [
          TgAvatar(
            id: (me?['id'] as int?) ?? 0,
            title: account.name,
            photo: me?['profile_photo']?['small'] as Map?,
            size: 72,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AccountName(account,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Tg.text)),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(sub,
                        style: TextStyle(
                            fontSize: 14,
                            color: themed
                                ? const Color(0xCCFFFFFF)
                                : Tg.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
          ),
        ],
      ),
    ),
    );
  }
}

Future<void> reloadMe() async {
  final a = accounts.active;
  final r = await a.td.request({'@type': 'getMe'});
  if (r['@type'] == 'user') {
    a.me = r;
    accounts.touch();
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadBio();
  }

  Future<void> _loadBio() async {
    final id = accounts.active.me?['id'];
    if (id is! int) return;
    final r = await td.request({'@type': 'getUserFullInfo', 'user_id': id});
    if (!mounted || r['@type'] == 'error') return;
    final b = r['bio'];
    setState(() => _bio = b is Map ? '${b['text'] ?? ''}' : '${b ?? ''}');
  }

  Future<bool> _do(Map<String, dynamic> q) async {
    final r = await td.request(q);
    if (r['@type'] == 'error') {
      tgToast('Не получилось: ${r['message']}');
      return false;
    }
    await reloadMe();
    return true;
  }

  Future<void> _editName() async {
    final me = accounts.active.me;
    final first = await tgAsk(context,
        title: 'Имя', initial: '${me?['first_name'] ?? ''}');
    if (first == null || first.isEmpty || !mounted) return;
    final last = await tgAsk(context,
        title: 'Фамилия (можно пусто)', initial: '${me?['last_name'] ?? ''}');
    if (last == null) return;
    await _do({'@type': 'setName', 'first_name': first, 'last_name': last});
  }

  Future<void> _editUsername() async {
    final a = accounts.active.username.replaceFirst('@', '');
    final v = await tgAsk(context,
        title: 'Имя пользователя',
        initial: a,
        hint: 'латиница, цифры и _ (от 5 знаков)');
    if (v == null) return;
    await _do({'@type': 'setUsername', 'username': v.replaceFirst('@', '')});
  }

  Future<void> _editBio() async {
    final v = await tgAsk(context,
        title: 'О себе', initial: _bio, maxLength: 70, maxLines: 2);
    if (v == null) return;
    if (await _do({'@type': 'setBio', 'bio': v})) setState(() => _bio = v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: accounts,
      builder: (context, _) {
        final a = accounts.active;
        return TgPage(
          title: 'Изменить профиль',
          children: [
            TgSection(
              footer:
                  'Фото профиля меняется в официальном приложении. Имя, имя пользователя и «О себе» меняются здесь.',
              children: [
                TgRow(
                    title: 'Имя',
                    value: a.name,
                    onTap: _editName),
                TgRow(
                    title: 'Имя пользователя',
                    value: a.username.isEmpty ? 'не задано' : a.username,
                    onTap: _editUsername),
                TgRow(
                    title: 'О себе',
                    value: _bio.isEmpty ? 'пусто' : _bio,
                    onTap: _editBio),
                TgRow(
                    title: 'Телефон',
                    value: a.phone.isEmpty ? '—' : hideInStream(a.phone)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return TgPage(
          title: 'Настройки чатов',
          children: [
            const TgSection(
              title: 'Обои',
              children: [WallpaperPicker()],
            ),
            TgSection(
              children: [
                TgSwitchRow(
                  title: 'Узор на фоне',
                  icon: GIcon.star,
                  iconColor: const Color(0xFF8A4FE0),
                  value: settings.doodles,
                  onChanged: (v) => settings.change(() => settings.doodles = v),
                ),
              ],
            ),
            TgSection(
              title: 'Сообщения',
              children: [
                TgSwitchRow(
                  title: 'Секунды во времени',
                  subtitle: 'Время сообщения с секундами',
                  value: settings.showSeconds,
                  onChanged: (v) => settings.change(() => settings.showSeconds = v),
                ),
                TgSwitchRow(
                  title: 'Реакция двойным касанием',
                  subtitle: 'Двойной щелчок по сообщению ставит ❤️',
                  value: settings.doubleTapReact,
                  onChanged: (v) => settings.change(() => settings.doubleTapReact = v),
                ),
                TgSwitchRow(
                  title: 'Отправлять без звука',
                  subtitle: 'Сообщения уходят тихо, пока не выбрано иное',
                  value: settings.silentSend,
                  onChanged: (v) => settings.change(() => settings.silentSend = v),
                ),
              ],
            ),
            TgSection(
              title: 'Размер текста',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Tg.outgoing,
                        borderRadius: BorderRadius.circular(14)),
                    child: Text('Так выглядят ваши сообщения',
                        style: TextStyle(
                            fontSize: settings.chatTextSize, color: Tg.text)),
                  ),
                ),
                Slider(
                  min: 12,
                  max: 22,
                  divisions: 10,
                  value: settings.chatTextSize.clamp(12.0, 22.0).toDouble(),
                  label: settings.chatTextSize.toStringAsFixed(0),
                  onChanged: (v) =>
                      settings.change(() => settings.chatTextSize = v),
                ),
              ],
            ),
            TgSection(
              footer:
                  'Включено: Enter отправляет, Shift+Enter переносит строку. Выключено: Enter переносит строку, отправка кнопкой. Работает на компьютере.',
              children: [
                TgSwitchRow(
                  title: 'Отправка по Enter',
                  icon: GIcon.send,
                  iconColor: const Color(0xFF5288C1),
                  value: settings.sendByEnter,
                  onChanged: (v) =>
                      settings.change(() => settings.sendByEnter = v),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  Map<String, dynamic>? _stats;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await td.request({'@type': 'getStorageStatisticsFast'});
    if (mounted && r['@type'] != 'error') setState(() => _stats = r);
  }

  String _size(Object? bytes) {
    final b = (bytes is num) ? bytes.toDouble() : 0.0;
    if (b < 1024) return '${b.toStringAsFixed(0)} Б';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} КБ';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / 1024 / 1024).toStringAsFixed(1)} МБ';
    }
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} ГБ';
  }

  Future<void> _clear() async {
    final ok = await tgConfirm(context,
        title: 'Очистить кэш?',
        text:
            'Скачанные файлы удалятся с устройства. При необходимости они скачаются снова.',
        yes: 'Очистить');
    if (!ok) return;
    setState(() => _busy = true);
    final r = await td.request({
      '@type': 'optimizeStorage',
      'size': 0,
      'ttl': -1,
      'count': -1,
      'immunity_delay': -1,
      'file_types': <dynamic>[],
      'chat_ids': <dynamic>[],
      'exclude_chat_ids': <dynamic>[],
      'return_deleted_file_statistics': false,
      'chat_limit': 0,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    tgToast(r['@type'] == 'error'
        ? 'Не получилось: ${r['message']}'
        : 'Кэш очищен');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return TgPage(
      title: 'Данные и память',
      children: [
        TgSection(
          title: 'Занято на устройстве',
          children: [
            TgRow(
                title: 'Файлы',
                value: s == null ? '…' : _size(s['files_size'])),
            TgRow(
                title: 'База данных',
                value: s == null ? '…' : _size(s['database_size'])),
            TgRow(
              title: _busy ? 'Очищаем…' : 'Очистить кэш',
              icon: GIcon.trash,
              iconColor: Tg.danger,
              onTap: _busy ? null : _clear,
            ),
          ],
        ),
        TgSection(
          title: 'GenGram',
          footer:
              'Копии удалённых сообщений лежат только на этом устройстве. Очистить их можно в настройках GenGram.',
          children: [
            TgRow(
                title: 'Сохранённые удалённые сообщения',
                value: '${store.deletedCount}'),
          ],
        ),
      ],
    );
  }
}

class FoldersPage extends StatelessWidget {
  const FoldersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: accounts,
      builder: (context, _) {
        final folders = accounts.active.folders;
        return TgPage(
          title: 'Папки с чатами',
          children: [
            TgSection(
              footer:
                  'Папки показываются над списком чатов. Создавать и менять их можно в официальном приложении Telegram, здесь они появятся сами.',
              children: [
                if (folders.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Папок пока нет',
                        style: TextStyle(color: Tg.textSecondary)),
                  ),
                for (final f in folders)
                  TgRow(
                    title: folderTitle(f),
                    icon: GIcon.pin,
                    iconColor: const Color(0xFF3A9BDC),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
