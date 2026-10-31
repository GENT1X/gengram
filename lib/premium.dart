import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accounts.dart';
import 'gengram_icons.dart';
import 'gift_effects.dart';
import 'media.dart';
import 'message_view.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

final premium = PremiumState();

class GiftKind {
  const GiftKind(this.key, this.emoji, this.name, this.stars, this.colors);
  final String key;
  final String emoji;
  final String name;
  final int stars;
  final List<Color> colors;
}

const giftCatalog = <GiftKind>[
  GiftKind('coffee', '☕', 'Кофе', 15, [Color(0xFFC8A27A), Color(0xFF7A5230)]),
  GiftKind('choco', '🍫', 'Шоколад', 15, [Color(0xFFB07A5A), Color(0xFF6B3F2A)]),
  GiftKind('balloon', '🎈', 'Шар', 15, [Color(0xFFFF8A8A), Color(0xFFC44A4A)]),
  GiftKind('heart', '💝', 'Сердце', 15, [Color(0xFFFF8FA3), Color(0xFFD94A6B)]),
  GiftKind('bear', '🧸', 'Мишка', 15, [Color(0xFFD7A86E), Color(0xFF9C6B3A)]),
  GiftKind('clover', '🍀', 'Клевер', 25, [Color(0xFF7BCB8F), Color(0xFF2F8A4E)]),
  GiftKind('flake', '❄️', 'Снежинка', 25, [Color(0xFF9ED8F5), Color(0xFF4F8FC4)]),
  GiftKind('fire', '🔥', 'Огонь', 25, [Color(0xFFFFAA5A), Color(0xFFD4582A)]),
  GiftKind('pizza', '🍕', 'Пицца', 25, [Color(0xFFFFC86E), Color(0xFFC4782A)]),
  GiftKind('berry', '🍓', 'Клубника', 25, [Color(0xFFFF7A8A), Color(0xFFB02A44)]),
  GiftKind('rose', '🌹', 'Роза', 25, [Color(0xFFE5566D), Color(0xFF9E2A3F)]),
  GiftKind('cake', '🎂', 'Торт', 50, [Color(0xFFF2A6C8), Color(0xFFB05A8A)]),
  GiftKind('bouquet', '💐', 'Букет', 50, [Color(0xFF7BCB8F), Color(0xFF3E8F5A)]),
  GiftKind('champagne', '🍾', 'Шампанское', 50, [Color(0xFFE6C86E), Color(0xFF9A7A2A)]),
  GiftKind('rocket', '🚀', 'Ракета', 50, [Color(0xFF6C93FF), Color(0xFF3A4FB8)]),
  GiftKind('box', '🎁', 'Коробка', 50, [Color(0xFFFF8FB0), Color(0xFFB0406A)]),
  GiftKind('tree', '🎄', 'Ёлка', 50, [Color(0xFF5FBF7A), Color(0xFF1F7A45)]),
  GiftKind('pumpkin', '🎃', 'Тыква', 50, [Color(0xFFFFA85A), Color(0xFFC4601A)]),
  GiftKind('rainbow', '🌈', 'Радуга', 50, [Color(0xFF8FD0FF), Color(0xFFB06AFF)]),
  GiftKind('cat', '🐱', 'Кот', 50, [Color(0xFFFFC88A), Color(0xFFB07A3A)]),
  GiftKind('dog', '🐶', 'Пёс', 50, [Color(0xFFD7B48A), Color(0xFF8A6A3A)]),
  GiftKind('trophy', '🏆', 'Кубок', 100, [Color(0xFFFFC857), Color(0xFFC48A1A)]),
  GiftKind('ring', '💍', 'Кольцо', 100, [Color(0xFF9FB6D8), Color(0xFF55709A)]),
  GiftKind('diamond', '💎', 'Алмаз', 100, [Color(0xFF63D2E8), Color(0xFF2A7FA3)]),
  GiftKind('star', '🌟', 'Звезда', 100, [Color(0xFFFFE27A), Color(0xFFD4A21A)]),
  GiftKind('gamepad', '🎮', 'Геймпад', 100, [Color(0xFF8A9BFF), Color(0xFF4A54C4)]),
  GiftKind('guitar', '🎸', 'Гитара', 100, [Color(0xFFE0884A), Color(0xFF8A4A1A)]),
  GiftKind('crown', '👑', 'Корона', 250, [Color(0xFFFFD35A), Color(0xFFC48A0A)]),
  GiftKind('unicorn', '🦄', 'Единорог', 250, [Color(0xFFE6A6FF), Color(0xFF8A5AD4)]),
  GiftKind('dragon', '🐉', 'Дракон', 500, [Color(0xFF6FD08A), Color(0xFF1F7A5A)]),
  GiftKind('car', '🏎️', 'Спорткар', 500, [Color(0xFFFF6A6A), Color(0xFFA01A2A)]),
];

GiftKind giftByKey(String key) =>
    giftCatalog.firstWhere((g) => g.key == key, orElse: () => giftCatalog.first);

const giftSenders = <(String, String)>[
  ('me', 'От меня'),
  ('anon', 'Анонимно'),
  ('santa', 'Дед Мороз'),
  ('friend', 'Тайный друг'),
  ('stranger', 'Незнакомец'),
];

String giftSenderLine(String from) {
  if (from == 'me') return 'Вы отправили подарок';
  if (from == 'anon') return 'Анонимный подарок';
  final label = giftSenders.firstWhere((s) => s.$1 == from,
      orElse: () => ('', 'Незнакомец')).$2;
  return 'Подарок от «$label»';
}

class LocalGift {
  LocalGift({
    required this.id,
    required this.accountId,
    required this.chatId,
    required this.chatTitle,
    required this.kind,
    required this.from,
    required this.text,
    required this.date,
    this.stars = 0,
    this.sticker,
    this.giftName = '',
  });

  final int stars;
  final Map<String, dynamic>? sticker;
  final String giftName;
  final int id;
  final int accountId;
  final int chatId;
  final String chatTitle;
  final String kind;
  final String from;
  final String text;
  final int date; // unix-время

  /// Идёт отправка: показываем часы, потом галочку.
  bool sending = false;

  Map<String, dynamic> toJson() => {
        'id': id,
        'acc': accountId,
        'chat': chatId,
        'title': chatTitle,
        'kind': kind,
        'from': from,
        'text': text,
        'date': date,
        'stars': stars,
        'sticker': sticker,
        'gname': giftName,
      };

  factory LocalGift.fromJson(Map<String, dynamic> j) => LocalGift(
        id: j['id'] as int,
        accountId: j['acc'] as int,
        chatId: j['chat'] as int,
        chatTitle: (j['title'] as String?) ?? '',
        kind: j['kind'] as String,
        from: (j['from'] as String?) ?? 'me',
        text: (j['text'] as String?) ?? '',
        date: j['date'] as int,
        stars: (j['stars'] as int?) ?? 0,
        sticker: (j['sticker'] as Map?)?.cast<String, dynamic>(),
        giftName: (j['gname'] as String?) ?? '',
      );
}

const premiumThemes = <List<Color>>[
  [Color(0xFF2B5278), Color(0xFF1B3A57)],
  [Color(0xFF7B4FD6), Color(0xFF3F2B8F)],
  [Color(0xFFD6567A), Color(0xFF8F2B4A)],
  [Color(0xFF2E9E8F), Color(0xFF16605A)],
  [Color(0xFFE08A2E), Color(0xFF9A4F12)],
  [Color(0xFF4C6FFF), Color(0xFF7A3FD0)],
];

const premiumEmoji = ['⭐', '🔥', '💎', '🚀', '🌙', '🦄', '👻', '🎧'];

const _starPacks = [50, 100, 250, 500, 1000, 2500];

class PremiumState extends ChangeNotifier {
  SharedPreferences? _p;
  final Set<int> _on = {};
  final Map<int, int> _stars = {};
  final Map<int, String> _emoji = {};
  final Map<int, int> _theme = {};
  final List<LocalGift> gifts = [];

  Future<void> load() async {
    final p = _p = await SharedPreferences.getInstance();
    _on.addAll((p.getStringList('vp_on') ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>());
    _stars.addAll(_readMap<int>(p.getString('vp_stars')));
    _emoji.addAll(_readMap<String>(p.getString('vp_emoji')));
    _theme.addAll(_readMap<int>(p.getString('vp_theme')));
    try {
      final raw = p.getString('vp_gifts');
      if (raw != null) {
        for (final g in jsonDecode(raw) as List) {
          gifts.add(LocalGift.fromJson(g as Map<String, dynamic>));
        }
      }
    } catch (_) {
    }
  }

  static Map<int, T> _readMap<T>(String? raw) {
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) int.parse(e.key): e.value as T};
    } catch (_) {
      return {};
    }
  }

  static String _writeMap(Map<int, Object> m) =>
      jsonEncode({for (final e in m.entries) '${e.key}': e.value});

  Future<void> _save() async {
    notifyListeners();
    final p = _p;
    if (p == null) return;
    await p.setStringList('vp_on', _on.map((e) => '$e').toList());
    await p.setString('vp_stars', _writeMap(_stars));
    await p.setString('vp_emoji', _writeMap(_emoji));
    await p.setString('vp_theme', _writeMap(_theme));
    await p.setString('vp_gifts', jsonEncode(gifts.map((g) => g.toJson()).toList()));
  }

  int get _active => accounts.active.id;

  bool isOn([int? id]) => _on.contains(id ?? _active);

  bool showBadge(Account a) => a.isPremium || _on.contains(a.id);

  int starsOf([int? id]) => _stars[id ?? _active] ?? 0;
  String emojiOf(int id) => _emoji[id] ?? '';
  int themeOf(int id) => _theme[id] ?? 0;

  Future<void> setOn(bool value) {
    if (value) {
      _on.add(_active);
    } else {
      _on.remove(_active);
    }
    return _save();
  }

  Future<void> setEmoji(String value) {
    _emoji[_active] = value;
    return _save();
  }

  Future<void> setTheme(int index) {
    _theme[_active] = index;
    return _save();
  }

  Future<void> addStars(int n) {
    _stars[_active] = starsOf() + n;
    return _save();
  }

  Future<bool> spend(int n) async {
    if (starsOf() < n) return false;
    _stars[_active] = starsOf() - n;
    await _save();
    return true;
  }

  Future<void> addGift(LocalGift g) {
    g.sending = true;
    gifts.add(g);
    // Как у настоящей отправки: сначала часы, через секунду доставлено.
    Timer(Duration(milliseconds: 700 + Random().nextInt(700)), () {
      g.sending = false;
      notifyListeners();
    });
    return _save();
  }

  List<LocalGift> giftsFor(int chatId) => [
        for (final g in gifts)
          if (g.accountId == _active && g.chatId == chatId) g,
      ];

  List<LocalGift> allGifts() => [
        for (final g in gifts)
          if (g.accountId == _active) g,
      ]..sort((a, b) => b.date.compareTo(a.date));

  Future<void> clearGifts() {
    gifts.removeWhere((g) => g.accountId == _active);
    return _save();
  }
}

// ---------- Значки ----------

class PremiumStar extends StatelessWidget {
  const PremiumStar({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StarPainter(const [
            Color(0xFF6C93FF),
            Color(0xFFB06CFF),
            Color(0xFFFF7AC6),
          ]),
        ),
      );
}

class StarCoin extends StatelessWidget {
  const StarCoin({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _StarPainter(const [Color(0xFFFFD54F), Color(0xFFFF9800)]),
        ),
      );
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.colors);
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ro = size.width / 2;
    final ri = ro * 0.46;
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final r = k.isEven ? ro : ri;
      final a = -math.pi / 2 + k * math.pi / 5;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    final shader =
        LinearGradient(colors: colors).createShader(Offset.zero & size);
    canvas.drawPath(path, Paint()..shader = shader);
    canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.08
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.colors != colors;
}

class AccountName extends StatelessWidget {
  const AccountName(this.account, {super.key, this.style});
  final Account account;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final badge = premium.showBadge(account);
        final emoji = premium.isOn(account.id) ? premium.emojiOf(account.id) : '';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(account.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
            ),
            if (badge) ...[
              const SizedBox(width: 6),
              const PremiumStar(size: 16),
            ],
            if (emoji.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(emoji, style: const TextStyle(fontSize: 15)),
            ],
          ],
        );
      },
    );
  }
}

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final acc = accounts.active;
        final on = premium.isOn();
        return TgPage(
          title: 'Premium',
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4C6FFF), Color(0xFF8A4FE0), Color(0xFFE05AA8)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0x33FFFFFF)),
                    child: const PremiumStar(size: 52),
                  ),
                  const SizedBox(height: 16),
                  const Text('Premium',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                      on
                          ? 'Внешний вид включён: звезда у имени, эмодзи-статус и цвет профиля.'
                          : 'Включи, чтобы увидеть звезду у имени, эмодзи-статус и цветной профиль.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, height: 1.35, color: Color(0xFFF3E9FF))),
                ],
              ),
            ),
            if (acc.isPremium)
              const TgSection(
                children: [
                  TgRow(
                    title: 'На этом аккаунте есть настоящий Premium',
                    subtitle: 'Звезда у имени показывается и без внешнего вида.',
                    icon: GIcon.checkCircle,
                    iconColor: Color(0xFF8A4FE0),
                  ),
                ],
              ),
            TgSection(
              children: [
                TgSwitchRow(
                  title: 'Значок Premium',
                  icon: GIcon.star,
                  iconColor: const Color(0xFF8A4FE0),
                  value: on,
                  onChanged: (v) => premium.setOn(v),
                ),
              ],
            ),
            if (on) ...[
              TgSection(
                title: 'Эмодзи-статус',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Choice(
                          selected: premium.emojiOf(acc.id).isEmpty,
                          onTap: () => premium.setEmoji(''),
                          child: Text('нет',
                              style: TextStyle(color: Tg.textSecondary)),
                        ),
                        for (final e in premiumEmoji)
                          _Choice(
                            selected: premium.emojiOf(acc.id) == e,
                            onTap: () => premium.setEmoji(e),
                            child: Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              TgSection(
                title: 'Цвет профиля',
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < premiumThemes.length; i++)
                          GestureDetector(
                            onTap: () => premium.setTheme(i),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: premiumThemes[i]),
                                border: Border.all(
                                    color: premium.themeOf(acc.id) == i
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            TgSection(
              title: 'Работает только в официальном Telegram',
              footer:
                  'Эти возможности даёт настоящая подписка Telegram Premium. В GenGram их включить нельзя.',
              children: [
                TgRow(
                    title: 'Удвоенные лимиты',
                    subtitle: 'Больше чатов, папок, закреплённых сообщений.',
                    icon: GIcon.sliders,
                    iconColor: Tg.textSecondary),
                TgRow(
                    title: 'Файлы до 4 ГБ',
                    subtitle: 'И более быстрая загрузка.',
                    icon: GIcon.send,
                    iconColor: Tg.textSecondary),
                TgRow(
                    title: 'Без рекламы',
                    subtitle: 'В публичных каналах.',
                    icon: GIcon.eyeOff,
                    iconColor: Tg.textSecondary),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 46),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Tg.panelOver,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? Tg.link : Colors.transparent, width: 2),
        ),
        child: child,
      ),
    );
  }
}

class StarsPage extends StatelessWidget {
  const StarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final history = premium.allGifts();
        return TgPage(
          title: 'Звёзды',
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Tg.panel,
              ),
              child: Column(
                children: [
                  const StarCoin(size: 56),
                  const SizedBox(height: 12),
                  Text('${premium.starsOf()}',
                      style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Tg.text)),
                  Text('звёзд на этом аккаунте',
                      style: TextStyle(fontSize: 14, color: Tg.textSecondary)),
                ],
              ),
            ),
            TgSection(
              title: 'Пополнить',
              footer:
                  'Условные звёзды: их нельзя потратить в Telegram. Они нужны только для подарков внутри GenGram. Настоящие Звёзды покупаются в официальном приложении.',
              children: [
                for (final n in _starPacks)
                  TgRow(
                    title: '$n ${tgPlural(n, 'звезда', 'звезды', 'звёзд')}',
                    leading: const StarCoin(size: 30),
                    value: 'Добавить',
                    onTap: () {
                      premium.addStars(n);
                      tgToast('Добавлено условных звёзд: $n');
                    },
                  ),
              ],
            ),
            if (history.isNotEmpty)
              TgSection(
                title: 'Подарки',
                children: [
                  for (final g in history)
                    ListTile(
                      leading: Text(giftByKey(g.kind).emoji,
                          style: const TextStyle(fontSize: 28)),
                      title: Text(giftByKey(g.kind).name),
                      subtitle: Text(
                          '${g.chatTitle.isEmpty ? 'Чат' : g.chatTitle} · ${tgListTime(g.date)}',
                          style: TextStyle(color: Tg.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StarCoin(size: 14),
                          const SizedBox(width: 4),
                          Text('${giftByKey(g.kind).stars}'),
                        ],
                      ),
                    ),
                  TgRow(
                    title: 'Очистить историю подарков',
                    danger: true,
                    onTap: () => premium.clearGifts(),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

Future<void> showGiftSheet(BuildContext context,
    {required int chatId, required String chatTitle}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tg.panel,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => Theme(
      data: Tg.theme,
      child: _GiftSheet(chatId: chatId, chatTitle: chatTitle),
    ),
  );
}

class _GiftSheet extends StatefulWidget {
  const _GiftSheet({required this.chatId, required this.chatTitle});
  final int chatId;
  final String chatTitle;

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _G {
  _G({
    required this.key,
    required this.name,
    required this.stars,
    this.sticker,
    this.emoji,
    this.colors,
    this.total = 0,
    this.remaining = 0,
  });
  final String key;
  final String name;
  final int stars;
  final Map<String, dynamic>? sticker;
  final String? emoji;
  final List<Color>? colors;
  final int total;
  final int remaining;
  bool get limited => total > 0;
  bool get soldOut => total > 0 && remaining <= 0;
}

final Map<int, List<_G>> _giftCache = {};

Future<List<_G>> _loadGifts() async {
  final acc = accounts.active;
  final cached = _giftCache[acc.id];
  if (cached != null) return cached;
  final out = <_G>[];
  try {
    final r = await acc.td.request({'@type': 'getAvailableGifts'});
    for (final raw in ((r['gifts'] as List?) ?? const [])) {
      if (raw is! Map) continue;
      final g = (raw['gift'] is Map ? raw['gift'] : raw) as Map;
      final sticker = (g['sticker'] as Map?)?.cast<String, dynamic>();
      final stars = g['star_count'];
      if (sticker == null || stars is! int) continue;
      out.add(_G(
        key: 'tg:${g['id']}',
        name: 'Подарок',
        stars: stars,
        sticker: sticker,
        total: (g['total_count'] as int?) ?? 0,
        remaining: (g['remaining_count'] as int?) ?? 0,
      ));
    }
  } catch (_) {}
  out.sort((a, b) => a.stars.compareTo(b.stars));
  if (out.isNotEmpty) _giftCache[acc.id] = out;
  return out;
}

class _GiftSheetState extends State<_GiftSheet> {
  List<_G>? _gifts;
  _G? _sel;
  bool _onlyLimited = false;
  bool _hideName = false;
  String _from = 'me';
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGifts().then((l) {
      if (mounted) setState(() => _gifts = l);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final g = _sel;
    if (g == null) return;
    final to = widget.chatTitle.isEmpty ? 'получателя' : widget.chatTitle;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: Tg.theme,
        child: AlertDialog(
          backgroundColor: Tg.panelOver,
          title: const Text('Отправка подарка'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 110,
                child: g.sticker != null
                    ? StickerView(g.sticker!, size: 110)
                    : Text(g.emoji ?? '🎁', style: const TextStyle(fontSize: 70)),
              ),
              const SizedBox(height: 10),
              Text('Подарок для $to',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15)),
              if (_text.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('«${_text.text.trim()}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Tg.textSecondary)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const StarCoin(size: 16),
                  const SizedBox(width: 6),
                  Text('${g.stars}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Отправить за ⭐${g.stars}')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await premium.spend(g.stars);
    if (!ok) return;
    await premium.addGift(LocalGift(
      id: DateTime.now().microsecondsSinceEpoch,
      accountId: accounts.active.id,
      chatId: widget.chatId,
      chatTitle: widget.chatTitle,
      kind: g.key,
      from: _hideName ? 'anon' : _from,
      text: _text.text.trim(),
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      stars: g.stars,
      sticker: g.sticker,
      giftName: g.name,
    ));
    if (!mounted) return;
    Navigator.pop(context);
    showGiftBurst();
  }

  Widget _tile(_G g) {
    final selected = _sel?.key == g.key;
    final c = g.colors;
    return GestureDetector(
      onTap: g.soldOut ? null : () => setState(() => _sel = g),
      child: Opacity(
        opacity: g.soldOut ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Tg.panelOver,
            gradient: c == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c[0].withOpacity(0.35), c[1].withOpacity(0.35)]),
            border: Border.all(
                color: selected ? Tg.link : Colors.transparent, width: 2),
          ),
          child: Stack(
            children: [
              if (g.limited)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: Tg.accent, borderRadius: BorderRadius.circular(8)),
                    child: Text(g.soldOut ? 'нет' : '${g.remaining}/${g.total}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: g.sticker != null
                            ? StickerView(g.sticker!, size: 68)
                            : Text(g.emoji ?? '🎁',
                                style: const TextStyle(fontSize: 38)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0x33FFC857),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const StarCoin(size: 12),
                          const SizedBox(width: 3),
                          Text('${g.stars}',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _gifts;
    final shown = all == null
        ? const <_G>[]
        : [for (final g in all) if (!_onlyLimited || g.limited) g];
    return ListenableBuilder(
      listenable: premium,
      builder: (context, _) {
        final sel = _sel;
        final enough = sel != null && premium.starsOf() >= sel.stars;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              widget.chatTitle.isEmpty
                                  ? 'Отправить подарок'
                                  : 'Подарок для ${widget.chatTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w600)),
                        ),
                        const StarCoin(size: 16),
                        const SizedBox(width: 4),
                        AnimatedCount(premium.starsOf(),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Все подарки'),
                          selected: !_onlyLimited,
                          onSelected: (_) => setState(() => _onlyLimited = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Ограниченные'),
                          selected: _onlyLimited,
                          onSelected: (_) => setState(() => _onlyLimited = true),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (all == null)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (all.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(30),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text('Не удалось загрузить подарки Telegram',
                                        style: TextStyle(color: Tg.textSecondary)),
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() => _gifts = null);
                                        _loadGifts().then((l) {
                                          if (mounted) setState(() => _gifts = l);
                                        });
                                      },
                                      child: const Text('Повторить'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (shown.isEmpty)
                            Padding(
                              padding: EdgeInsets.all(30),
                              child: Center(
                                  child: Text('Таких подарков сейчас нет',
                                      style: TextStyle(color: Tg.textSecondary))),
                            )
                          else
                            GridView.count(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.82,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [for (final g in shown) _tile(g)],
                            ),
                          if (sel != null) ...[
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Скрыть моё имя'),
                              subtitle: const Text(
                                  'Подарок покажется как анонимный.',
                                  style: TextStyle(fontSize: 12.5)),
                              value: _hideName,
                              onChanged: (v) => setState(() => _hideName = v),
                            ),
                            if (!_hideName)
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final s in giftSenders)
                                    if (s.$1 != 'anon')
                                      ChoiceChip(
                                        label: Text(s.$2),
                                        selected: _from == s.$1,
                                        onSelected: (_) =>
                                            setState(() => _from = s.$1),
                                      ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _text,
                      maxLength: 200,
                      maxLines: 2,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          counterText: '',
                          prefixIcon: Icon(Icons.chat_bubble_outline),
                          hintText: 'Комментарий к подарку (необязательно)'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: sel == null
                            ? null
                            : enough
                                ? _send
                                : () {
                                    Navigator.pop(context);
                                    tgPush(context, const StarsPage());
                                  },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(sel == null
                              ? 'Выберите подарок'
                              : enough
                                  ? 'Отправить подарок за ⭐${sel.stars}'
                                  : 'Не хватает звёзд. Пополнить'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GiftBubble extends StatelessWidget {
  const GiftBubble(this.gift, {super.key});
  final LocalGift gift;

  @override
  Widget build(BuildContext context) {
    final real = gift.sticker != null;
    final kind = giftByKey(gift.kind);
    final stars = gift.stars > 0 ? gift.stars : kind.stars;
    final c = real
        ? const [Color(0xFF3F6E9E), Color(0xFF2B4F78)]
        : kind.colors;
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c[0].withOpacity(0.9), c[1].withOpacity(0.9)],
        ),
      ),
      child: Column(
        children: [
          Text(giftSenderLine(gift.from),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          Text(gift.text.isEmpty ? 'Подарок' : gift.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.3, color: Colors.white)),
          const SizedBox(height: 8),
          FloatingGift(
              child: real
                  ? StickerView(gift.sticker!, size: 110)
                  : Text(kind.emoji, style: const TextStyle(fontSize: 70))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StarCoin(size: 14),
                const SizedBox(width: 5),
                Text('$stars',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(gift.sending ? Icons.schedule : Icons.done_all,
                  size: 13, color: const Color(0xBFFFFFFF)),
              const SizedBox(width: 4),
              Text(gift.sending ? 'Отправка…' : tgHhmm(gift.date),
                  style: const TextStyle(fontSize: 11, color: Color(0xBFFFFFFF))),
            ],
          ),
        ],
      ),
    );
  }
}
