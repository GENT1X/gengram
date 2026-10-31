import 'dart:io';

import 'package:flutter/material.dart';

import 'gengram_icons.dart';
import 'media.dart';

class TgPalette {
  const TgPalette({
    required this.id,
    required this.name,
    required this.dark,
    required this.bg,
    required this.panel,
    required this.panelOver,
    required this.selected,
    required this.outgoing,
    required this.incoming,
    required this.accent,
    required this.link,
    required this.text,
    required this.textSecondary,
    required this.outline,
    required this.badge,
    required this.badgeMuted,
    required this.metaOut,
  });

  final String id;
  final String name;
  final bool dark;
  final Color bg; // фон переписки
  final Color panel;
  final Color panelOver; // выделенные плитки
  final Color selected; // выбранный чат в списке
  final Color outgoing; // свои сообщения
  final Color incoming; // чужие сообщения
  final Color accent; // кнопки
  final Color link;
  final Color text;
  final Color textSecondary;
  final Color outline;
  final Color badge; // счётчик непрочитанных
  final Color badgeMuted;
  final Color metaOut;

  TgPalette withAccent(Color a) {
    final hsl = HSLColor.fromColor(a);
    Color tone(double s, double l) =>
        hsl.withSaturation((hsl.saturation * s).clamp(0.0, 1.0)).withLightness(l).toColor();
    if (dark) {
      return copy(
        accent: tone(0.9, 0.55),
        link: tone(1.0, 0.7),
        selected: tone(0.55, 0.28),
        outgoing: tone(0.55, 0.28),
        badge: tone(0.9, 0.5),
        badgeMuted: tone(0.25, 0.28),
        metaOut: tone(0.6, 0.72),
        outline: tone(0.25, 0.22),
      );
    }
    return copy(
      accent: tone(0.9, 0.5),
      link: tone(1.0, 0.42),
      selected: tone(0.5, 0.88),
      outgoing: tone(0.7, 0.9),
      badge: tone(0.9, 0.5),
      badgeMuted: tone(0.2, 0.7),
      metaOut: tone(0.4, 0.45),
      outline: tone(0.2, 0.85),
    );
  }

  TgPalette copy({
    Color? accent,
    Color? link,
    Color? selected,
    Color? outgoing,
    Color? badge,
    Color? badgeMuted,
    Color? metaOut,
    Color? outline,
  }) =>
      TgPalette(
        id: id,
        name: name,
        dark: dark,
        bg: bg,
        panel: panel,
        panelOver: panelOver,
        selected: selected ?? this.selected,
        outgoing: outgoing ?? this.outgoing,
        incoming: incoming,
        accent: accent ?? this.accent,
        link: link ?? this.link,
        text: text,
        textSecondary: textSecondary,
        outline: outline ?? this.outline,
        badge: badge ?? this.badge,
        badgeMuted: badgeMuted ?? this.badgeMuted,
        metaOut: metaOut ?? this.metaOut,
      );
}

class Tg {
  static TgPalette p = kPalettes.first;

  static Color get bg => p.bg;
  static Color get panel => p.panel;
  static Color get panelOver => p.panelOver;
  static Color get selected => p.selected;
  static Color get outgoing => p.outgoing;
  static Color get incoming => p.incoming;
  static Color get accent => p.accent;
  static Color get link => p.link;
  static Color get text => p.text;
  static Color get textSecondary => p.textSecondary;
  static Color get outline => p.outline;
  static Color get badge => p.badge;
  static Color get badgeMuted => p.badgeMuted;
  static Color get metaOut => p.metaOut;
  static const danger = Color(0xFFEC6A6A);

  static Color get outText => p.dark ? Colors.white : p.text;

  static TgPalette? _built;
  static ThemeData? _theme;

  static ThemeData get theme {
    if (!identical(_built, p) || _theme == null) {
      _built = p;
      _theme = _build();
    }
    return _theme!;
  }

  static ThemeData _build() {
    final scheme = ColorScheme(
      brightness: p.dark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: outgoing,
      onPrimaryContainer: outText,
      secondary: link,
      onSecondary: Colors.white,
      secondaryContainer: panelOver,
      onSecondaryContainer: text,
      surface: panel,
      onSurface: text,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: incoming,
      outline: outline,
      outlineVariant: outline,
      error: danger,
      onError: Colors.white,
    );
    final base = ThemeData(
        brightness: p.dark ? Brightness.dark : Brightness.light,
        useMaterial3: true,
        colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: panel,
      canvasColor: panel,
      dividerColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle:
            TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: selected,
        height: 66,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelOver,
        hintStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

const kPalettes = <TgPalette>[
  TgPalette(
    id: 'classic', name: 'Классика', dark: true,
    bg: Color(0xFF0E1621), panel: Color(0xFF17212B), panelOver: Color(0xFF202B36),
    selected: Color(0xFF2B5278), outgoing: Color(0xFF2B5278), incoming: Color(0xFF182533),
    accent: Color(0xFF5288C1), link: Color(0xFF6AB2F2),
    text: Color(0xFFF5F5F5), textSecondary: Color(0xFF708499), outline: Color(0xFF2F4052),
    badge: Color(0xFF4E8DC3), badgeMuted: Color(0xFF3E546A), metaOut: Color(0xFF7DA8D3),
  ),
  TgPalette(
    id: 'night', name: 'Ночь', dark: true,
    bg: Color(0xFF1B2430), panel: Color(0xFF242F3D), panelOver: Color(0xFF2E3A4A),
    selected: Color(0xFF3B5B7E), outgoing: Color(0xFF3B5B7E), incoming: Color(0xFF2A3646),
    accent: Color(0xFF6C9EDB), link: Color(0xFF7DB8FF),
    text: Color(0xFFF2F5F8), textSecondary: Color(0xFF8A9CB0), outline: Color(0xFF3A4859),
    badge: Color(0xFF5B8FCC), badgeMuted: Color(0xFF4A5B70), metaOut: Color(0xFF9CBCE0),
  ),
  TgPalette(
    id: 'amoled', name: 'AMOLED', dark: true,
    bg: Color(0xFF000000), panel: Color(0xFF0B0B0D), panelOver: Color(0xFF17181B),
    selected: Color(0xFF1E3A5C), outgoing: Color(0xFF1E3A5C), incoming: Color(0xFF141518),
    accent: Color(0xFF4C8DD6), link: Color(0xFF63B0FF),
    text: Color(0xFFF2F2F2), textSecondary: Color(0xFF7A8794), outline: Color(0xFF24272C),
    badge: Color(0xFF3F7FC4), badgeMuted: Color(0xFF30363D), metaOut: Color(0xFF7FB0E5),
  ),
  TgPalette(
    id: 'neon', name: 'Неон GenGram', dark: true,
    bg: Color(0xFF110D1F), panel: Color(0xFF1A1530), panelOver: Color(0xFF251F42),
    selected: Color(0xFF4A3A86), outgoing: Color(0xFF4A3A86), incoming: Color(0xFF211B3A),
    accent: Color(0xFF9B6BFF), link: Color(0xFFB794FF),
    text: Color(0xFFF4F0FF), textSecondary: Color(0xFF8E85B0), outline: Color(0xFF352C58),
    badge: Color(0xFF8A5CF5), badgeMuted: Color(0xFF4A4068), metaOut: Color(0xFFC2A8FF),
  ),
  TgPalette(
    id: 'forest', name: 'Лес', dark: true,
    bg: Color(0xFF0D1A14), panel: Color(0xFF14261D), panelOver: Color(0xFF1D3328),
    selected: Color(0xFF2C6046), outgoing: Color(0xFF2C6046), incoming: Color(0xFF16291F),
    accent: Color(0xFF4FA878), link: Color(0xFF6FCF9A),
    text: Color(0xFFF0F7F3), textSecondary: Color(0xFF6F9484), outline: Color(0xFF28463A),
    badge: Color(0xFF3F9A6A), badgeMuted: Color(0xFF3A5648), metaOut: Color(0xFF8FD6AE),
  ),
  TgPalette(
    id: 'sunset', name: 'Закат', dark: true,
    bg: Color(0xFF1C1215), panel: Color(0xFF2A1B1F), panelOver: Color(0xFF38262B),
    selected: Color(0xFF7A3F2E), outgoing: Color(0xFF7A3F2E), incoming: Color(0xFF30201F),
    accent: Color(0xFFE5834F), link: Color(0xFFFFA574),
    text: Color(0xFFFBF1EC), textSecondary: Color(0xFFA38878), outline: Color(0xFF4A3330),
    badge: Color(0xFFD9733F), badgeMuted: Color(0xFF5A4440), metaOut: Color(0xFFFFB892),
  ),
  TgPalette(
    id: 'day', name: 'День', dark: false,
    bg: Color(0xFFDDE5EC), panel: Color(0xFFFFFFFF), panelOver: Color(0xFFF1F3F5),
    selected: Color(0xFFE1EEFB), outgoing: Color(0xFFEFFDDE), incoming: Color(0xFFFFFFFF),
    accent: Color(0xFF3390EC), link: Color(0xFF168ACD),
    text: Color(0xFF0B0B0B), textSecondary: Color(0xFF707579), outline: Color(0xFFDADCE0),
    badge: Color(0xFF3390EC), badgeMuted: Color(0xFFC4C9CC), metaOut: Color(0xFF5DB85C),
  ),
  TgPalette(
    id: 'arctic', name: 'Арктика', dark: false,
    bg: Color(0xFFE3EEF6), panel: Color(0xFFF7FBFE), panelOver: Color(0xFFE9F1F7),
    selected: Color(0xFFD3E6F5), outgoing: Color(0xFFCFE6F8), incoming: Color(0xFFFFFFFF),
    accent: Color(0xFF2E86C8), link: Color(0xFF1F78B8),
    text: Color(0xFF10202B), textSecondary: Color(0xFF68808F), outline: Color(0xFFD0DEE8),
    badge: Color(0xFF2E86C8), badgeMuted: Color(0xFFB7C8D3), metaOut: Color(0xFF3E8FC9),
  ),
  TgPalette(
    id: 'sakura', name: 'Сакура', dark: false,
    bg: Color(0xFFF6E7EC), panel: Color(0xFFFFF8FA), panelOver: Color(0xFFF8E9EE),
    selected: Color(0xFFF5D7E0), outgoing: Color(0xFFF9D5E0), incoming: Color(0xFFFFFFFF),
    accent: Color(0xFFD8588A), link: Color(0xFFC2407A),
    text: Color(0xFF2A1219), textSecondary: Color(0xFF95707C), outline: Color(0xFFEBD3DB),
    badge: Color(0xFFD8588A), badgeMuted: Color(0xFFD9BCC6), metaOut: Color(0xFFC86A92),
  ),
];

class TgIcon extends StatelessWidget {
  const TgIcon(this.icon, {super.key, this.size, this.color});

  final GIcon icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Tg.text;
    return GenIcon(icon, size: size, color: c, accent: c);
  }
}

const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime _dt(int unix) => DateTime.fromMillisecondsSinceEpoch(unix * 1000);

int _daysAgo(DateTime t) {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(t.year, t.month, t.day))
      .inDays;
}

String tgHhmm(int unix) {
  final t = _dt(unix);
  return '${_two(t.hour)}:${_two(t.minute)}';
}

String tgHhmmss(int unix) {
  final t = _dt(unix);
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

bool tgSameDay(int a, int b) {
  final x = _dt(a), y = _dt(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String tgListTime(int unix) {
  final t = _dt(unix);
  final d = _daysAgo(t);
  if (d <= 0) return tgHhmm(unix);
  if (d < 7) return _weekdays[t.weekday - 1];
  return '${_two(t.day)}.${_two(t.month)}.${_two(t.year % 100)}';
}

String tgDayLabel(int unix) {
  final t = _dt(unix);
  final d = _daysAgo(t);
  if (d <= 0) return 'Сегодня';
  if (d == 1) return 'Вчера';
  final year = t.year == DateTime.now().year ? '' : ' ${t.year}';
  return '${t.day} ${_months[t.month - 1]}$year';
}

String tgLastSeen(int unix) {
  final t = _dt(unix);
  final d = _daysAgo(t);
  final time = tgHhmm(unix);
  if (d <= 0) return 'был(а) сегодня в $time';
  if (d == 1) return 'был(а) вчера в $time';
  return 'был(а) ${t.day} ${_months[t.month - 1]} в $time';
}

String tgPlural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

const _avatarColors = <List<Color>>[
  [Color(0xFFFF885E), Color(0xFFFF516A)],
  [Color(0xFFFFCD6A), Color(0xFFFFA85C)],
  [Color(0xFF82B1FF), Color(0xFF665FFF)],
  [Color(0xFFA0DE7E), Color(0xFF54CB68)],
  [Color(0xFF53EDD6), Color(0xFF28C9B7)],
  [Color(0xFF72D5FD), Color(0xFF2A9EF1)],
  [Color(0xFFE0A2F3), Color(0xFFD669ED)],
];

const _nameColors = <Color>[
  Color(0xFFE17076),
  Color(0xFFFAA774),
  Color(0xFFA695E7),
  Color(0xFF7BC862),
  Color(0xFF6EC9CB),
  Color(0xFF65AADD),
  Color(0xFFEE7AAE),
];

Color tgNameColor(int id) => _nameColors[id.abs() % _nameColors.length];

class TgAvatar extends StatefulWidget {
  const TgAvatar({
    super.key,
    required this.id,
    required this.title,
    this.photo,
    this.size = 54,
  });

  final int id;
  final String title;
  final Map? photo;
  final double size;

  @override
  State<TgAvatar> createState() => _TgAvatarState();
}

class _TgAvatarState extends State<TgAvatar> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(TgAvatar old) {
    super.didUpdateWidget(old);
    if (old.photo?['id'] != widget.photo?['id']) {
      _path = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final file = widget.photo;
    if (file == null) return;
    final ready = readyPath(file);
    if (ready != null) {
      if (mounted) setState(() => _path = ready);
      return;
    }
    final path = await tdFilePath(file);
    if (!mounted || path == null || widget.photo?['id'] != file['id']) return;
    setState(() => _path = path);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final colors = _avatarColors[widget.id.abs() % _avatarColors.length];
    final title = widget.title.trim();
    final letter = title.isEmpty ? '?' : title.characters.first.toUpperCase();
    final initials = Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Text(letter,
          style: TextStyle(
              color: Colors.white,
              fontSize: s * 0.42,
              fontWeight: FontWeight.w600)),
    );
    final path = _path;
    if (path == null) return initials;
    return ClipOval(
      child: Image.file(
        File(path),
        width: s,
        height: s,
        cacheWidth: (s * MediaQuery.devicePixelRatioOf(context)).round(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => initials,
      ),
    );
  }
}
