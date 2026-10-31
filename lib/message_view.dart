import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'local_emoji.dart';
import 'media.dart';
import 'polls.dart';
import 'reactions.dart';
import 'tg_style.dart';
import 'translator.dart';

enum MsgKind {
  text,

  media,

  sticker,

  service,

  gift,
}

const _serviceTypes = {
  'messageChatAddMembers',
  'messageChatJoinByLink',
  'messageChatJoinByRequest',
  'messageChatDeleteMember',
  'messageChatChangeTitle',
  'messageChatChangePhoto',
  'messageChatDeletePhoto',
  'messagePinMessage',
  'messageBasicGroupChatCreate',
  'messageSupergroupChatCreate',
  'messageChatUpgradeTo',
  'messageChatUpgradeFrom',
  'messageScreenshotTaken',
  'messageContactRegistered',
  'messageCustomServiceAction',
};

MsgKind kindOf(Map content) {
  switch (content['@type']) {
    case 'messagePhoto':
    case 'messageVideo':
    case 'messageAnimation':
    case 'messageVideoNote':
      return MsgKind.media;
    case 'messageSticker':
    case 'messageAnimatedEmoji':
      return MsgKind.sticker;
    case 'messageGift':
    case 'messageUpgradedGift':
    case 'messageGiftedStars':
    case 'messageGiftedPremium':
      return MsgKind.gift;
    default:
      return _serviceTypes.contains(content['@type'])
          ? MsgKind.service
          : MsgKind.text;
  }
}

int _cl(int v, int max) => v < 0 ? 0 : (v > max ? max : v);

String _plain(dynamic v) => v is Map ? '${v['text'] ?? ''}' : '${v ?? ''}';

String captionOf(Map content) => _plain(content['caption']);

bool metaOnImage(Map content) =>
    kindOf(content) == MsgKind.media && captionOf(content).isEmpty;

class MessageContent extends StatelessWidget {
  const MessageContent({
    super.key,
    required this.msg,
    required this.mine,
    required this.gap,
    this.metaPill,
  });

  final Map<String, dynamic> msg;
  final bool mine;

  final double gap;

  final Widget? metaPill;

  @override
  Widget build(BuildContext context) {
    final c = msg['content'] as Map;
    switch (c['@type']) {
      case 'messageText':
        {
          final shown = c['text'] as Map?;
          final local = mine
              ? localEmoji.of(msg['chat_id'] as int, msg['id'] as int)
              : null;
          final same = local != null &&
              '${local['text']}' == '${shown?['text'] ?? ''}';
          return FormattedText(same ? local : shown, gap: gap, mine: mine);
        }
      case 'messagePhoto':
        return _photo(context, c);
      case 'messageSticker':
        return StickerView(c['sticker'] as Map, size: 170);
      case 'messageAnimatedEmoji':
        {
          final st = (c['animated_emoji'] as Map?)?['sticker'] as Map?;
          if (st != null) return StickerView(st, size: 130);
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${c['emoji'] ?? ''}', style: const TextStyle(fontSize: 72)),
          );
        }
      case 'messageAnimation':
        {
          final a = c['animation'] as Map;
          return _video(
            context,
            c,
            thumb: (a['thumbnail'] as Map?)?['file'] as Map?,
            mini: a['minithumbnail'] as Map?,
            file: a['animation'] as Map?,
            w: (a['width'] as int?) ?? 0,
            h: (a['height'] as int?) ?? 0,
            label: 'GIF',
          );
        }
      case 'messageVideo':
        {
          final v = c['video'] as Map;
          return _video(
            context,
            c,
            thumb: (v['thumbnail'] as Map?)?['file'] as Map?,
            mini: v['minithumbnail'] as Map?,
            file: v['video'] as Map?,
            w: (v['width'] as int?) ?? 0,
            h: (v['height'] as int?) ?? 0,
            label: _duration((v['duration'] as int?) ?? 0),
          );
        }
      case 'messageVideoNote':
        return _round(c);
      case 'messageVoiceNote':
        {
          final v = c['voice_note'] as Map;
          return _fileRow(
            icon: Icons.play_arrow_rounded,
            title: 'Голосовое сообщение',
            subtitle: _duration((v['duration'] as int?) ?? 0),
            file: v['voice'] as Map?,
            caption: c,
          );
        }
      case 'messageAudio':
        {
          final a = c['audio'] as Map;
          final title = '${a['title'] ?? ''}'.isEmpty
              ? '${a['file_name'] ?? 'Музыка'}'
              : '${a['performer'] ?? ''} ${a['performer'] == null ? '' : '— '}${a['title']}';
          return _fileRow(
            icon: Icons.music_note_rounded,
            title: title,
            subtitle: _duration((a['duration'] as int?) ?? 0),
            file: a['audio'] as Map?,
            caption: c,
          );
        }
      case 'messageDocument':
        {
          final d = c['document'] as Map;
          final f = d['document'] as Map?;
          return _fileRow(
            icon: Icons.insert_drive_file_rounded,
            title: '${d['file_name'] ?? 'Файл'}',
            subtitle: _size((f?['size'] as num?) ?? 0),
            file: f,
            caption: c,
          );
        }
      case 'messageLocation':
        return _lines(['📍 Геопозиция'], gap);
      case 'messageVenue':
        {
          final v = c['venue'] as Map?;
          return _lines(
              ['📍 ${v?['title'] ?? 'Место'}', '${v?['address'] ?? ''}'], gap);
        }
      case 'messageContact':
        {
          final k = c['contact'] as Map?;
          return _lines([
            '👤 ${k?['first_name'] ?? ''} ${k?['last_name'] ?? ''}'.trim(),
            '${k?['phone_number'] ?? ''}',
          ], gap);
        }
      case 'messagePoll':
        return PollView(msg: msg, mine: mine);
      case 'messageGift':
      case 'messageUpgradedGift':
      case 'messageGiftedStars':
      case 'messageGiftedPremium':
        return GiftMessageCard(content: c);
      default:
        return FormattedText({'text': messageText(c)}, gap: gap, mine: mine);
    }
  }

  // ---------- Части ----------

  static Widget _lines(List<String> lines, double gap) {
    final shown = lines.where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Text.rich(TextSpan(children: [
            TextSpan(text: shown[i]),
            if (i == shown.length - 1 && gap > 0)
              WidgetSpan(child: SizedBox(width: gap)),
          ])),
      ],
    );
  }

  Widget _pillOverlay() => metaPill == null
      ? const SizedBox.shrink()
      : Positioned(right: 6, bottom: 6, child: metaPill!);

  Widget _withCaption(Widget media, Map c) {
    final cap = c['caption'] as Map?;
    final text = _plain(cap);
    if (text.isEmpty) return media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        media,
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
          child: FormattedText(cap, gap: gap, mine: mine),
        ),
      ],
    );
  }

  static Size _fit(int w, int h) {
    if (w <= 0 || h <= 0) return const Size(240, 240);
    final k = math.min(320 / w, 380 / h);
    return Size(math.max(120, w * k), math.max(90, h * k));
  }

  Widget _photo(BuildContext context, Map c) {
    final photo = c['photo'] as Map;
    final sizes = (photo['sizes'] as List?) ?? const [];
    Map? best;
    for (final s in sizes) {
      final m = s as Map;
      final side = math.max((m['width'] as int?) ?? 0, (m['height'] as int?) ?? 0);
      if (side <= 1280) best = m;
    }
    best ??= sizes.isNotEmpty ? sizes.first as Map : null;
    final largest = sizes.isNotEmpty ? sizes.last as Map : null;
    final box = _fit((best?['width'] as int?) ?? 0, (best?['height'] as int?) ?? 0);
    final mini = photo['minithumbnail'] as Map?;
    final image = GestureDetector(
      onTap: () => showPhotoViewer(context, largest?['photo'] as Map?, mini),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TgImage(file: best?['photo'] as Map?, mini: mini),
              if (captionOf(c).isEmpty) _pillOverlay(),
            ],
          ),
        ),
      ),
    );
    return _withCaption(image, c);
  }

  Widget _video(
    BuildContext context,
    Map c, {
    required Map? thumb,
    required Map? mini,
    required Map? file,
    required int w,
    required int h,
    required String label,
  }) {
    final box = _fit(w, h);
    final media = GestureDetector(
      onTap: () => openFileMap(file),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TgImage(file: thumb, mini: mini),
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0x99000000)),
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 34, color: Colors.white),
                ),
              ),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(label,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white)),
                ),
              ),
              if (captionOf(c).isEmpty) _pillOverlay(),
            ],
          ),
        ),
      ),
    );
    return _withCaption(media, c);
  }

  Widget _round(Map c) {
    final v = c['video_note'] as Map;
    return GestureDetector(
      onTap: () => openFileMap(v['video'] as Map?, loop: true),
      child: ClipOval(
        child: SizedBox.square(
          dimension: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TgImage(
                  file: (v['thumbnail'] as Map?)?['file'] as Map?,
                  mini: v['minithumbnail'] as Map?),
              const Center(
                child: Icon(Icons.play_arrow_rounded,
                    size: 48, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Map? file,
    required Map caption,
  }) {
    final cap = captionOf(caption);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => openFileMap(file),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mine ? Tg.link : Tg.accent),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: mine ? Tg.metaOut : Tg.textSecondary)),
                  ],
                ),
              ),
              SizedBox(width: cap.isEmpty ? gap : 6),
            ],
          ),
        ),
        if (cap.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FormattedText(caption['caption'] as Map?, gap: gap, mine: mine),
          ),
      ],
    );
  }

  static String _duration(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  static String _size(num bytes) {
    final b = bytes.toDouble();
    if (b < 1024) return '${b.toStringAsFixed(0)} Б';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} КБ';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} МБ';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} ГБ';
  }
}

class FormattedText extends StatefulWidget {
  const FormattedText(this.formatted,
      {super.key, this.gap = 0, this.mine = false});

  final Map? formatted;
  final double gap;
  final bool mine;

  @override
  State<FormattedText> createState() => _FormattedTextState();
}

class _FormattedTextState extends State<FormattedText> {
  final List<TapGestureRecognizer> _taps = [];

  void _clearTaps() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _clearTaps();
    super.dispose();
  }

  Future<void> _open(String url) async {
    var u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final text = '${widget.formatted?['text'] ?? ''}';
    if (!widget.mine && settings.autoTranslate) {
      return TranslatedText(text, trailingGap: widget.gap);
    }
    _clearTaps();
    final entities = ((widget.formatted?['entities'] as List?) ?? const [])
        .cast<Map>();
    final spans = <InlineSpan>[];
    if (entities.isEmpty) {
      spans.add(TextSpan(text: text));
    } else {
      final cuts = <int>{0, text.length};
      for (final e in entities) {
        final o = (e['offset'] as int?) ?? 0;
        final l = (e['length'] as int?) ?? 0;
        cuts
          ..add(_cl(o, text.length))
          ..add(_cl(o + l, text.length));
      }
      final sorted = cuts.toList()..sort();
      for (var i = 0; i + 1 < sorted.length; i++) {
        final a = sorted[i], b = sorted[i + 1];
        if (a == b) continue;
        var bold = false, italic = false, under = false, strike = false;
        var code = false, link = false;
        String? url;
        String? customId;
        var customStart = -1;
        for (final e in entities) {
          final o = (e['offset'] as int?) ?? 0;
          final l = (e['length'] as int?) ?? 0;
          if (a < o || b > o + l) continue;
          final t = '${(e['type'] as Map?)?['@type']}';
          switch (t) {
            case 'textEntityTypeBold':
              bold = true;
            case 'textEntityTypeItalic':
              italic = true;
            case 'textEntityTypeUnderline':
              under = true;
            case 'textEntityTypeStrikethrough':
              strike = true;
            case 'textEntityTypeCode':
            case 'textEntityTypePre':
            case 'textEntityTypePreCode':
              code = true;
            case 'textEntityTypeUrl':
              link = true;
              url = text.substring(_cl(o, text.length),
                  _cl(o + l, text.length));
            case 'textEntityTypeTextUrl':
              link = true;
              url = '${(e['type'] as Map)['url']}';
            case 'textEntityTypeCustomEmoji':
              customId = '${(e['type'] as Map)['custom_emoji_id']}';
              customStart = o;
            case 'textEntityTypeMention':
            case 'textEntityTypeHashtag':
            case 'textEntityTypeBotCommand':
            case 'textEntityTypeMentionName':
              link = true;
          }
        }
        if (customId != null) {
          if (a == customStart) {
            spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: CustomEmojiView(customId,
                    size: settings.chatTextSize * 1.5,
                    fallback: text.substring(a, b))));
          }
          continue;
        }
        TapGestureRecognizer? tap;
        if (url != null) {
          final target = url;
          tap = TapGestureRecognizer()..onTap = () => _open(target);
          _taps.add(tap);
        }
        spans.add(TextSpan(
          text: text.substring(a, b),
          recognizer: tap,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : null,
            fontStyle: italic ? FontStyle.italic : null,
            fontFamily: code ? 'Consolas' : null,
            backgroundColor: code ? const Color(0x33000000) : null,
            color: link ? Tg.link : null,
            decoration: TextDecoration.combine([
              if (under || link) TextDecoration.underline,
              if (strike) TextDecoration.lineThrough,
            ]),
            decorationColor: link ? Tg.link : null,
          ),
        ));
      }
    }
    if (widget.gap > 0) {
      spans.add(WidgetSpan(child: SizedBox(width: widget.gap)));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

class ReplyQuote extends StatelessWidget {
  const ReplyQuote({super.key, required this.name, required this.text, this.mine = false});

  final String name;
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine ? Tg.outText : Tg.link;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(8, 2, 6, 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
          Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: Tg.text)),
        ],
      ),
    );
  }
}

class ReactionsRow extends StatelessWidget {
  const ReactionsRow({super.key, required this.msg, required this.onTap});

  final Map<String, dynamic> msg;
  final void Function(Map type, bool chosen) onTap;

  static List<Map> reactionsOf(Map<String, dynamic> msg) {
    final info = msg['interaction_info'] as Map?;
    final r = info?['reactions'];
    final list = r is List ? r : (r is Map ? r['reactions'] : null);
    return ((list as List?) ?? const []).cast<Map>();
  }

  static String emojiOf(Map type) {
    switch (type['@type']) {
      case 'reactionTypeEmoji':
        return '${type['emoji']}';
      default:
        return '⭐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = reactionsOf(msg);
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final r in list)
            GestureDetector(
              onTap: () => onTap(r['type'] as Map, r['is_chosen'] == true),
              onLongPress: () => showReactionUsers(
                  context, msg['chat_id'] as int, msg['id'] as int, r['type'] as Map),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r['is_chosen'] == true
                      ? Tg.accent
                      : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReactionIcon(r['type'] as Map, size: 18),
                    const SizedBox(width: 4),
                    Text('${r['total_count'] ?? 1}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GiftMessageCard extends StatelessWidget {
  const GiftMessageCard({super.key, required this.content});
  final Map content;

  @override
  Widget build(BuildContext context) {
    final type = content['@type'];
    final gift = content['gift'] as Map?;
    Map? sticker = gift?['sticker'] as Map?;
    sticker ??= (gift?['model'] as Map?)?['sticker'] as Map?;

    String title;
    String sub = '';
    switch (type) {
      case 'messageUpgradedGift':
        title = '${gift?['title'] ?? 'Подарок'} #${gift?['number'] ?? ''}'.trim();
        sub = 'Улучшенный подарок';
      case 'messageGiftedStars':
        title = 'Звёзды в подарок';
        sub = '${content['star_count'] ?? ''} ⭐';
      case 'messageGiftedPremium':
        title = 'Premium в подарок';
        sub = '${content['month_count'] ?? ''} мес.';
      default:
        title = content['is_private'] == true ? 'Анонимный подарок' : 'Подарок';
        final stars = gift?['star_count'];
        if (stars != null) sub = '$stars ⭐';
    }
    final text = _plain(content['text']);
    return Container(
      width: 230,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE64C6FFF), Color(0xE6B04FE0)],
        ),
      ),
      child: Column(
        children: [
          if (sticker != null)
            _Float(child: StickerView(sticker, size: 120))
          else
            const _Float(child: Text('🎁', style: TextStyle(fontSize: 64))),
          const SizedBox(height: 6),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF))),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _Float extends StatefulWidget {
  const _Float({required this.child});
  final Widget child;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class FloatingGift extends StatelessWidget {
  const FloatingGift({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => _Float(child: child);
}
