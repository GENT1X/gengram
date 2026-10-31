import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'config.dart';
import 'gengram_icons.dart';
import 'ghost_mark.dart';
import 'tg_style.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.onReady});

  final WidgetBuilder onReady;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _phoneState = 'authorizationStateWaitPhoneNumber';
  static const _codeState = 'authorizationStateWaitCode';
  static const _passwordState = 'authorizationStateWaitPassword';
  static const _registerState = 'authorizationStateWaitRegistration';
  static const _paramsState = 'authorizationStateWaitTdlibParameters';
  static const _readyState = 'authorizationStateReady';
  static const _qrState = 'authorizationStateWaitOtherDeviceConfirmation';
  static const _emailState = 'authorizationStateWaitEmailAddress';
  static const _emailCodeState = 'authorizationStateWaitEmailCode';

  String _state = 'loading';
  Map<String, dynamic> _data = const {};
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _hidePassword = true;

  String _conn = '';

  bool _qrDismissed = false;

  bool _emailFlow = false;

  bool _editPhone = false;
  int _resendIn = 0;
  Timer? _timer;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = td.updates.listen((u) {
      if (u['@type'] == 'updateAuthorizationState') {
        _handle(u['authorization_state']);
      } else if (u['@type'] == 'updateConnectionState') {
        final text = _connText(u['state']?['@type'] as String?);
        if (mounted && text != _conn) setState(() => _conn = text);
      }
    });
    td.request({'@type': 'getAuthorizationState'}).then(_handle);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _handle(Map<String, dynamic> s) async {
    final type = s['@type'];
    if (type is! String || type == 'error' || !mounted) return;
    setState(() {
      if (type != _state || _editPhone) {
        _a.clear();
        _b.clear();
      }
      _editPhone = false;
      if (type != _qrState) _qrDismissed = false;
      if (type == _emailState || type == _emailCodeState) _emailFlow = true;
      if (type == _phoneState) _emailFlow = false;
      _state = type;
      _data = s;
      _busy = false;
      _error = null;
    });
    if (type == _codeState) {
      _startResendTimer((s['code_info']?['timeout'] ?? 0) as int);
    }
  }

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  String _connText(String? type) {
    switch (type) {
      case 'connectionStateWaitingForNetwork':
        return 'Ждём сеть…';
      case 'connectionStateConnectingToProxy':
        return 'Подключаемся к прокси…';
      case 'connectionStateConnecting':
        return 'Подключаемся к Telegram…';
      case 'connectionStateUpdating':
        return 'Обновляем…';
      default:
        return '';
    }
  }

  int get _codeLength => _state == _emailCodeState
      ? (_data['code_info']?['length'] as int?) ?? 6
      : (_data['code_info']?['type']?['length'] as int?) ?? 5;

  String _friendly(String m) {
    final u = m.toUpperCase();
    if (u.contains('PHONE_NUMBER_INVALID')) {
      return 'Проверь номер: он должен быть в международном формате, например +375291234567.';
    }
    if (u.contains('PHONE_CODE_INVALID')) {
      return 'Код не подошёл. Проверь цифры и попробуй ещё раз.';
    }
    if (u.contains('PHONE_CODE_EXPIRED')) {
      return 'Код устарел. Запроси новый.';
    }
    if (u.contains('EMAIL_ADDRESS_INVALID') || u.contains('EMAIL_INVALID')) {
      return 'Проверь адрес почты: он должен быть вида name@example.com.';
    }
    if (u.contains('EMAIL_VERIFY_EXPIRED') || u.contains('CODE_INVALID')) {
      return 'Код из письма не подошёл или устарел. Проверь цифры или запроси письмо ещё раз.';
    }
    if (u.contains('PASSWORD_HASH_INVALID')) {
      return 'Пароль не подошёл. Проверь раскладку и регистр.';
    }
    if (u.contains('FIRSTNAME_INVALID')) return 'Укажи имя.';
    if (u.contains('FLOOD') || u.contains('RETRY AFTER')) {
      return 'Слишком много попыток. Подожди немного и повтори.';
    }
    if (u.contains('API_ID')) {
      return 'Telegram не принял api_id или api_hash. Проверь lib/config.dart.';
    }
    return 'Не получилось: $m';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final a = _a.text.trim();
    final Map<String, dynamic> query;
    switch (_state) {
      case _phoneState:
      case _qrState: // телефон можно ввести и с экрана QR-кода
        if (a.isEmpty) return;
        query = {
          '@type': 'setAuthenticationPhoneNumber',
          'phone_number': a.replaceAll(RegExp(r'[\s\-()]'), ''),
        };
      case _codeState:
        if (a.isEmpty) return;
        query = _editPhone
            ? {
                '@type': 'setAuthenticationPhoneNumber',
                'phone_number': a.replaceAll(RegExp(r'[\s\-()]'), ''),
              }
            : {'@type': 'checkAuthenticationCode', 'code': a};
      case _emailState:
        if (a.isEmpty) return;
        query = {'@type': 'setAuthenticationEmailAddress', 'email_address': a};
      case _emailCodeState:
        if (a.isEmpty) return;
        query = {
          '@type': 'checkAuthenticationEmailCode',
          'code': {'@type': 'emailAddressAuthenticationCode', 'code': a},
        };
      case _passwordState:
        if (_a.text.isEmpty) return;
        query = {'@type': 'checkAuthenticationPassword', 'password': _a.text};
      case _registerState:
        if (a.isEmpty) {
          setState(() => _error = 'Укажи имя.');
          return;
        }
        query = {
          '@type': 'registerUser',
          'first_name': a,
          'last_name': _b.text.trim(),
        };
      default:
        return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await td.request(query);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r['@type'] == 'error') _error = _friendly('${r['message']}');
    });
  }

  Future<void> _startQr() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _qrDismissed = false;
    });
    final r = await td.request({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': <int>[],
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r['@type'] == 'error') _error = _friendly('${r['message']}');
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    final r = await td.request({'@type': 'resendAuthenticationCode'});
    if (!mounted) return;
    if (r['@type'] == 'error') setState(() => _error = _friendly('${r['message']}'));
  }

  (Offset, double) _face() {
    if (_state == _passwordState) return (Offset.zero, 1.0);
    if (_state == 'loading' || _state == _paramsState) return (Offset.zero, 0.0);
    return (const Offset(0, 0.9), 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _readyState) return widget.onReady(context);

    final (gaze, closed) = _face();
    final (title, subtitle) = _heading();
    return Scaffold(
      backgroundColor: Tg.panel,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: Tg.accent),
                    child: GhostMark(size: 84, gaze: gaze, closed: closed),
                  ),
                  const SizedBox(height: 28),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Tg.text)),
                  const SizedBox(height: 10),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, height: 1.4, color: Tg.textSecondary)),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                        key: ValueKey('$_state$_qrDismissed$_editPhone'),
                        child: _body()),
                  ),
                  if (accounts.list.length > 1) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: accounts.cancelAdd,
                      child: Text('Вернуться к другому аккаунту',
                          style: TextStyle(color: Tg.link, fontSize: 15)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _heading() {
    if (apiId == 0) {
      return (
        'Нужны ключи Telegram',
        'Получи api_id и api_hash на my.telegram.org, впиши их в lib/config.dart и перезапусти GenGram.'
      );
    }
    switch (_state) {
      case _phoneState:
        return ('Ваш номер телефона', 'Проверьте код страны и введите свой номер телефона.');
      case _qrState:
        return _qrDismissed
            ? ('Ваш номер телефона', 'Проверьте код страны и введите свой номер телефона.')
            : ('Вход по QR-коду', 'Быстрый вход без кода из сообщения.');
      case _emailState:
        return ('Привяжите почту', 'Telegram просит подтвердить вход через электронную почту. Введите адрес, на который придёт код.');
      case _emailCodeState:
        final pattern = _data['code_info']?['email_address_pattern'] as String?;
        return ('Проверьте почту', 'Мы отправили код на ${pattern ?? 'вашу почту'}.');
      case _codeState:
        if (_editPhone) {
          return ('Ваш номер телефона', 'Введите новый номер, и мы отправим на него код.');
        }
        final phone = _data['code_info']?['phone_number'] as String?;
        return (phone == null ? 'Введите код' : _prettyPhone(phone), _codeHint());
      case _passwordState:
        final hint = _data['password_hint'] as String?;
        return (
          'Введите пароль',
          (hint != null && hint.isNotEmpty)
              ? 'Ваш аккаунт защищён двухэтапной проверкой. Подсказка: $hint'
              : 'Ваш аккаунт защищён двухэтапной проверкой. Введите облачный пароль.'
        );
      case _registerState:
        return ('Ваше имя', 'Этого номера ещё нет в Telegram. Введите имя и, если хотите, фамилию.');
      case 'loading':
      case _paramsState:
        final err = accounts.active.startError;
        if (err != null) {
          final busy = err.toLowerCase().contains('lock');
          return (
            'Не удалось запустить',
            busy
                ? 'База данных занята другим запущенным GenGram. Завершите gengram.exe в диспетчере задач и запустите заново.'
                : 'TDLib ответил: $err'
          );
        }
        return ('GenGram', _conn.isEmpty ? 'Запускаем…' : _conn);
      default:
        return ('Этот способ входа недоступен', 'Telegram запросил подтверждение, которое GenGram пока не поддерживает, например вход через Apple ID или Google. Попробуйте другой аккаунт.');
    }
  }

  String _codeHint() {
    final type = _data['code_info']?['type']?['@type'] as String?;
    switch (type) {
      case 'authenticationCodeTypeTelegramMessage':
        return 'Мы отправили код в приложение Telegram на другом вашем устройстве.';
      case 'authenticationCodeTypeSms':
      case 'authenticationCodeTypeSmsWord':
      case 'authenticationCodeTypeSmsPhrase':
        return 'Мы отправили SMS с кодом.';
      case 'authenticationCodeTypeCall':
      case 'authenticationCodeTypeFlashCall':
      case 'authenticationCodeTypeMissedCall':
        return 'Мы позвоним на этот номер, код будет в звонке.';
      default:
        return 'Мы отправили код на этот номер.';
    }
  }

  String _prettyPhone(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('7')) {
      return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
    }
    return '+$d';
  }

  Widget _body() {
    if (apiId == 0) return const SizedBox.shrink();
    switch (_state) {
      case _phoneState:
        return _phoneBody();
      case _qrState:
        return _qrDismissed ? _phoneBody() : _qrBody();
      case _emailState:
        return _form(
          field: _field(
              controller: _a,
              hint: 'name@example.com',
              keyboard: TextInputType.emailAddress),
          button: 'Далее',
        );
      case _emailCodeState:
        return _form(
          field: _codeField(),
          button: 'Далее',
          footer: [
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('Отправить письмо ещё раз'),
            ),
          ],
        );
      case _codeState:
        return _editPhone ? _phoneBody() : _codeBody();
      case _passwordState:
        return _form(
          field: _field(
            controller: _a,
            hint: 'Пароль',
            obscure: _hidePassword,
            suffix: IconButton(
              tooltip: _hidePassword ? 'Показать пароль' : 'Скрыть пароль',
              icon: TgIcon(_hidePassword ? GIcon.eye : GIcon.eyeOff,
                  color: Tg.textSecondary),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
          button: 'Далее',
        );
      case _registerState:
        return _form(
          field: Column(children: [
            _field(
                controller: _a,
                hint: 'Имя',
                capitalization: TextCapitalization.words),
            const SizedBox(height: 14),
            _field(
                controller: _b,
                hint: 'Фамилия (необязательно)',
                autofocus: false,
                capitalization: TextCapitalization.words),
          ]),
          button: 'Начать',
          footer: [
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Создавая аккаунт, вы принимаете правила Telegram.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Tg.textSecondary)),
            ),
          ],
        );
      case 'loading':
      case _paramsState:
        return SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: Tg.link));
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _phoneBody() => _form(
        field: _field(
          controller: _a,
          hint: 'Номер телефона, например +7 912 345 67 89',
          keyboard: TextInputType.phone,
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]'))],
        ),
        button: 'Далее',
        footer: [
          if (_state == _codeState)
            TextButton(
              onPressed: () => setState(() {
                _editPhone = false;
                _error = null;
              }),
              child: const Text('Назад к вводу кода'),
            )
          else
            TextButton(
              onPressed: _busy ? null : _startQr,
              child: const Text('ВОЙТИ ПО QR-КОДУ'),
            ),
          const SizedBox(height: 14),
          _ghostTile(),
        ],
      );

  Widget _codeBody() {
    final canResend = _data['code_info']?['next_type'] != null;
    return _form(
      field: _codeField(),
      button: 'Далее',
      footer: [
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _editPhone = true;
                    _a.clear();
                    _error = null;
                  }),
          child: const Text('Изменить номер'),
        ),
        if (canResend)
          TextButton(
            onPressed: (_resendIn > 0 || _busy) ? null : _resend,
            child: Text(_resendIn > 0
                ? 'Отправить код ещё раз через $_resendIn с'
                : 'Отправить код ещё раз'),
          ),
      ],
    );
  }

  Widget _qrBody() {
    final link = _data['link'] as String? ?? '';
    const steps = [
      'Откройте Telegram на телефоне',
      'Зайдите в Настройки → Устройства → Подключить устройство',
      'Наведите камеру на этот код',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: link.isEmpty
              ? const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(child: CircularProgressIndicator()))
              : QrImageView(
                  data: link,
                  size: 200,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: Tg.accent),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(steps[i],
                        style: TextStyle(
                            fontSize: 15, height: 1.3, color: Tg.text)),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) ...[const SizedBox(height: 4), _ErrorText(_error!)],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _qrDismissed = true;
            _error = null;
          }),
          child: const Text('ВОЙТИ ПО НОМЕРУ ТЕЛЕФОНА'),
        ),
        const SizedBox(height: 10),
        _ghostTile(),
      ],
    );
  }

  // ---------- Детали ----------

  Widget _form({
    required Widget field,
    String? button,
    List<Widget> footer = const [],
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        if (_error != null) ...[const SizedBox(height: 12), _ErrorText(_error!)],
        if (button != null) ...[const SizedBox(height: 22), _primaryButton(button)],
        if (footer.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final w in footer) Center(child: w),
        ],
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    bool autofocus = true,
    Widget? suffix,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: obscure,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      style: TextStyle(fontSize: 17, color: Tg.text),
      cursorColor: Tg.link,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: Tg.textSecondary),
        floatingLabelStyle: TextStyle(color: Tg.link),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: border(Tg.outline, 1),
        focusedBorder: border(Tg.accent, 2),
        border: border(Tg.outline, 1),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _codeField() => TextField(
        controller: _a,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: _codeLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 10,
            color: Tg.text),
        cursorColor: Tg.link,
        decoration: InputDecoration(
          hintText: '•' * _codeLength,
          hintStyle: TextStyle(color: Tg.outline, letterSpacing: 10),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Tg.outline)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Tg.accent, width: 2)),
        ),
        onChanged: (v) {
          if (v.length == _codeLength) _submit();
        },
        onSubmitted: (_) => _submit(),
      );

  Widget _primaryButton(String label) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Tg.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Tg.accent.withOpacity(0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(label),
      ),
    );
  }

  Widget _ghostTile() {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Material(
        color: Tg.panelOver,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => settings.setGhost(!settings.ghost),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                GenIcon(settings.ghost ? GIcon.ghost : GIcon.ghostVisible,
                    size: 22,
                    color: settings.ghost ? Tg.link : Tg.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          settings.ghost
                              ? 'Режим призрака включён'
                              : 'Режим призрака выключен',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Tg.text)),
                      Text(
                          settings.ghost
                              ? 'После входа вас не видно в сети.'
                              : 'После входа вы видны в сети.',
                          style: TextStyle(
                              fontSize: 12.5, color: Tg.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                    value: settings.ghost,
                    onChanged: (v) => settings.setGhost(v)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GenIcon(GIcon.alert, size: 18, color: Tg.danger, accent: Tg.danger),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.35, color: Tg.danger))),
      ],
    );
  }
}
