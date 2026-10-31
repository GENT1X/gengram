import 'package:flutter/material.dart';

import 'app_state.dart';
import 'gengram_icons.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

bool _isError(Map<String, dynamic> r) => r['@type'] == 'error';

void _fail(Map<String, dynamic> r) =>
    tgToast('Не получилось: ${r['message'] ?? 'неизвестная ошибка'}');

const _scopes = <(String, String)>[
  ('notificationSettingsScopePrivateChats', 'Личные чаты'),
  ('notificationSettingsScopeGroupChats', 'Группы'),
  ('notificationSettingsScopeChannelChats', 'Каналы'),
];

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Map<String, Map<String, dynamic>> _s = {};

  @override
  void initState() {
    super.initState();
    for (final scope in _scopes) {
      td.request({
        '@type': 'getScopeNotificationSettings',
        'scope': {'@type': scope.$1},
      }).then((r) {
        if (mounted && !_isError(r)) setState(() => _s[scope.$1] = r);
      });
    }
  }

  Future<void> _change(String scope, Map<String, dynamic> patch) async {
    final current = _s[scope];
    if (current == null) return;
    final next = {...current, ...patch};
    setState(() => _s[scope] = next);
    final r = await td.request({
      '@type': 'setScopeNotificationSettings',
      'scope': {'@type': scope},
      'notification_settings': next,
    });
    if (_isError(r)) {
      _fail(r);
      if (mounted) setState(() => _s[scope] = current);
    }
  }

  Future<void> _reset() async {
    final ok = await tgConfirm(context,
        title: 'Сбросить уведомления?',
        text: 'Все настройки уведомлений вернутся к значениям по умолчанию.',
        yes: 'Сбросить');
    if (!ok) return;
    final r = await td.request({'@type': 'resetAllNotificationSettings'});
    if (_isError(r)) {
      _fail(r);
      return;
    }
    tgToast('Настройки уведомлений сброшены');
    for (final scope in _scopes) {
      final n = await td.request({
        '@type': 'getScopeNotificationSettings',
        'scope': {'@type': scope.$1},
      });
      if (mounted && !_isError(n)) setState(() => _s[scope.$1] = n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TgPage(
      title: 'Уведомления',
      children: [
        for (final scope in _scopes)
          TgSection(
            title: scope.$2,
            children: [
              if (_s[scope.$1] == null)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Загружаем…',
                      style: TextStyle(color: Tg.textSecondary)),
                )
              else ...[
                TgSwitchRow(
                  title: 'Уведомления',
                  value: ((_s[scope.$1]!['mute_for'] as int?) ?? 0) == 0,
                  onChanged: (v) =>
                      _change(scope.$1, {'mute_for': v ? 0 : 2147483647}),
                ),
                TgSwitchRow(
                  title: 'Показывать текст',
                  value: _s[scope.$1]!['show_preview'] == true,
                  onChanged: (v) => _change(scope.$1, {'show_preview': v}),
                ),
              ],
            ],
          ),
        TgSection(
          footer:
              'Звук и показ уведомлений на компьютере зависят и от настроек Windows.',
          children: [
            TgRow(
              title: 'Сбросить все уведомления',
              danger: true,
              onTap: _reset,
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacyItem {
  const _PrivacyItem(this.type, this.title, this.icon, this.color,
      {this.noNobody = false});
  final String type;
  final String title;
  final GIcon icon;
  final Color color;

  final bool noNobody;
}

const _privacyItems = <_PrivacyItem>[
  _PrivacyItem('userPrivacySettingShowStatus', 'Был(а) в сети', GIcon.eye,
      Color(0xFF5288C1)),
  _PrivacyItem('userPrivacySettingShowPhoneNumber', 'Номер телефона',
      GIcon.phone, Color(0xFF3E9E6A)),
  _PrivacyItem('userPrivacySettingShowProfilePhoto', 'Фото профиля',
      GIcon.user, Color(0xFFE08A2E)),
  _PrivacyItem(
      'userPrivacySettingShowBio', 'О себе', GIcon.info, Color(0xFF7B4FD6)),
  _PrivacyItem('userPrivacySettingShowLinkInForwardedMessages',
      'Пересылка сообщений', GIcon.send, Color(0xFF2E9E8F)),
  _PrivacyItem('userPrivacySettingAllowChatInvites', 'Приглашения в группы',
      GIcon.group, Color(0xFFE5566D)),
  _PrivacyItem('userPrivacySettingAllowCalls', 'Звонки', GIcon.volume,
      Color(0xFF6C7A89)),
  _PrivacyItem('userPrivacySettingAllowFindingByPhoneNumber',
      'Поиск по номеру телефона', GIcon.search, Color(0xFF5288C1),
      noNobody: true),
];

const _ruleTypes = <String, String>{
  'all': 'userPrivacySettingRuleAllowAll',
  'contacts': 'userPrivacySettingRuleAllowContacts',
  'nobody': 'userPrivacySettingRuleRestrictAll',
};

const _ruleNames = <String, String>{
  'all': 'Все',
  'contacts': 'Мои контакты',
  'nobody': 'Никто',
};

String _baseOf(List rules) {
  for (final r in rules) {
    switch ((r as Map)['@type']) {
      case 'userPrivacySettingRuleAllowAll':
        return 'all';
      case 'userPrivacySettingRuleAllowContacts':
        return 'contacts';
      case 'userPrivacySettingRuleRestrictAll':
        return 'nobody';
    }
  }
  return 'nobody';
}

bool _hasExceptions(List rules) => rules.any((r) {
      final t = '${(r as Map)['@type']}';
      return t.endsWith('Users') || t.endsWith('ChatMembers');
    });

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final Map<String, List> _rules = {};
  String? _ttl;

  @override
  void initState() {
    super.initState();
    for (final item in _privacyItems) {
      td.request({
        '@type': 'getUserPrivacySettingRules',
        'setting': {'@type': item.type},
      }).then((r) {
        if (mounted && !_isError(r)) {
          setState(() => _rules[item.type] = (r['rules'] as List?) ?? []);
        }
      });
    }
    td.request({'@type': 'getAccountTtl'}).then((r) {
      if (mounted && !_isError(r)) setState(() => _ttl = '${r['days']}');
    });
  }

  Future<void> _pick(_PrivacyItem item) async {
    final rules = _rules[item.type];
    if (rules == null) return;
    final choice = await tgPick(
      context,
      title: item.title,
      selected: _baseOf(rules),
      options: [
        for (final k in ['all', 'contacts', 'nobody'])
          if (!(item.noNobody && k == 'nobody')) (k, _ruleNames[k]!),
      ],
    );
    if (choice == null) return;
    final keep = [
      for (final r in rules)
        if ('${(r as Map)['@type']}'.endsWith('Users') ||
            '${r['@type']}'.endsWith('ChatMembers'))
          r,
    ];
    final next = [
      ...keep,
      {'@type': _ruleTypes[choice]},
    ];
    final r = await td.request({
      '@type': 'setUserPrivacySettingRules',
      'setting': {'@type': item.type},
      'rules': {'@type': 'userPrivacySettingRules', 'rules': next},
    });
    if (_isError(r)) {
      _fail(r);
      return;
    }
    if (mounted) setState(() => _rules[item.type] = next);
  }

  Future<void> _pickTtl() async {
    final choice = await tgPick(
      context,
      title: 'Удалить аккаунт, если меня не было',
      selected: _ttl,
      options: const [
        ('30', '1 месяц'),
        ('90', '3 месяца'),
        ('180', '6 месяцев'),
        ('365', '1 год'),
      ],
    );
    if (choice == null) return;
    final r = await td.request({
      '@type': 'setAccountTtl',
      'ttl': {'@type': 'accountTtl', 'days': int.parse(choice)},
    });
    if (_isError(r)) {
      _fail(r);
      return;
    }
    if (mounted) setState(() => _ttl = choice);
  }

  String _ttlName(String? days) {
    switch (days) {
      case '30':
        return '1 месяц';
      case '90':
        return '3 месяца';
      case '180':
        return '6 месяцев';
      case '365':
        return '1 год';
      case null:
        return '…';
      default:
        return '$days дн.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TgPage(
      title: 'Конфиденциальность',
      children: [
        TgSection(
          title: 'Кто может видеть и писать мне',
          footer:
              'Если скрыть «Был(а) в сети», вы тоже не увидите время захода других людей. Режим призрака GenGram работает отдельно: он не показывает вас «в сети» и не отмечает сообщения прочитанными, не меняя эти настройки.',
          children: [
            for (final item in _privacyItems)
              TgRow(
                title: item.title,
                icon: item.icon,
                iconColor: item.color,
                value: _rules[item.type] == null
                    ? '…'
                    : '${_ruleNames[_baseOf(_rules[item.type]!)]}'
                        '${_hasExceptions(_rules[item.type]!) ? ' (+искл.)' : ''}',
                onTap: () => _pick(item),
              ),
          ],
        ),
        TgSection(
          title: 'Автоудаление аккаунта',
          footer:
              'Если вы не заходили в Telegram так долго, аккаунт будет удалён.',
          children: [
            TgRow(
              title: 'Если меня долго нет',
              icon: GIcon.timer,
              iconColor: const Color(0xFFE5566D),
              value: _ttlName(_ttl),
              onTap: _pickTtl,
            ),
          ],
        ),
        const TgSection(
          footer:
              'Исключения для отдельных людей, чёрный список и облачный пароль настраиваются в официальном приложении Telegram.',
          children: [],
        ),
      ],
    );
  }
}

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<Map<String, dynamic>>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await td.request({'@type': 'getActiveSessions'});
    if (!mounted) return;
    if (_isError(r)) {
      _fail(r);
      setState(() => _list = []);
      return;
    }
    setState(() => _list =
        ((r['sessions'] as List?) ?? []).cast<Map<String, dynamic>>());
  }

  String _when(Map<String, dynamic> s) {
    if (s['is_current'] == true) return 'сейчас онлайн';
    final t = s['last_active_date'] as int?;
    return (t == null || t == 0) ? '' : tgLastSeen(t);
  }

  Future<void> _end(Map<String, dynamic> s) async {
    final ok = await tgConfirm(context,
        title: 'Завершить сеанс?',
        text:
            '${s['application_name'] ?? 'Устройство'} на ${s['device_model'] ?? ''} выйдет из аккаунта.',
        yes: 'Завершить',
        danger: true);
    if (!ok) return;
    final r = await td.request(
        {'@type': 'terminateSession', 'session_id': s['id']});
    if (_isError(r)) {
      _fail(r);
      return;
    }
    _load();
  }

  Future<void> _endAll() async {
    final ok = await tgConfirm(context,
        title: 'Завершить все другие сеансы?',
        text: 'Все устройства, кроме GenGram, выйдут из этого аккаунта.',
        yes: 'Завершить',
        danger: true);
    if (!ok) return;
    final r = await td.request({'@type': 'terminateAllOtherSessions'});
    if (_isError(r)) {
      _fail(r);
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) {
      return TgPage(title: 'Устройства', children: [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: Tg.link)),
        ),
      ]);
    }
    final current = [for (final s in list) if (s['is_current'] == true) s];
    final others = [for (final s in list) if (s['is_current'] != true) s];
    return TgPage(
      title: 'Устройства',
      children: [
        if (current.isNotEmpty)
          TgSection(title: 'Это устройство', children: [
            for (final s in current) _tile(s),
          ]),
        if (others.isNotEmpty)
          TgSection(
            title: 'Другие сеансы',
            children: [
              TgRow(
                title: 'Завершить все другие сеансы',
                danger: true,
                onTap: _endAll,
              ),
              for (final s in others) _tile(s),
            ],
          ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> s) {
    final place = [s['country'], s['ip']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(', ');
    final current = s['is_current'] == true;
    return TgRow(
      title: '${s['application_name'] ?? 'Telegram'} ${s['application_version'] ?? ''}'
          .trim(),
      subtitle: [
        '${s['device_model'] ?? ''}, ${s['platform'] ?? ''} ${s['system_version'] ?? ''}'
            .trim(),
        if (place.isNotEmpty) place,
        _when(s),
      ].where((e) => e.isNotEmpty).join('\n'),
      icon: GIcon.phone,
      iconColor: current ? const Color(0xFF3E9E6A) : const Color(0xFF5288C1),
      onTap: current ? null : () => _end(s),
    );
  }
}
