import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'gengram_icons.dart';

const translateLanguages = <(String, String)>[
  ('ru', 'Русский'),
  ('en', 'English'),
  ('uk', 'Українська'),
  ('be', 'Беларуская'),
  ('kk', 'Қазақша'),
  ('de', 'Deutsch'),
  ('fr', 'Français'),
  ('es', 'Español'),
  ('it', 'Italiano'),
  ('pt', 'Português'),
  ('pl', 'Polski'),
  ('tr', 'Türkçe'),
  ('ar', 'العربية'),
  ('zh-CN', '中文'),
  ('ja', '日本語'),
  ('ko', '한국어'),
];

final translator = Translator();

class Translator {
  static const _maxCache = 3000;
  static const _maxParallel = 3;
  static const _backoff = Duration(seconds: 30);

  final _cache = <String, String>{};
  final _inflight = <String, Future<String?>>{};
  final _failedUntil = <String, DateTime>{};
  final _waiters = <Completer<void>>[];
  int _active = 0;

  String? lastError;

  Future<String?> translate(String text) {
    final lang = settings.translateTo;
    final provider = settings.translateProvider;
    if (!_worthTranslating(text, lang)) return Future.value(null);

    final key = '$provider|$lang|$text';
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);

    final until = _failedUntil[provider];
    if (until != null && DateTime.now().isBefore(until)) {
      return Future.value(null);
    }

    return _inflight[key] ??= _limited(() => _run(text, lang, provider)).then((r) {
      _inflight.remove(key);
      if (r != null) {
        if (_cache.length >= _maxCache) _cache.remove(_cache.keys.first);
        _cache[key] = r;
      } else {
        _failedUntil[provider] = DateTime.now().add(_backoff);
      }
      return r;
    });
  }

  Future<String> test() async {
    _failedUntil.clear();
    lastError = null;
    final lang = settings.translateTo;
    final r = await _run('Hello, how are you?', lang, settings.translateProvider);
    return r != null ? 'Работает: «$r»' : (lastError ?? 'Перевод не получился.');
  }

  Future<T> _limited<T>(Future<T> Function() job) async {
    while (_active >= _maxParallel) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await job();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }

  Future<String?> _run(String text, String lang, String provider) =>
      provider == 'libre' ? _libre(text, lang) : _telegram(text, lang);

  Future<String?> _telegram(String text, String lang) async {
    final r = await td.request({
      '@type': 'translateText',
      'text': {
        '@type': 'formattedText',
        'text': text,
        'entities': <dynamic>[],
      },
      'to_language_code': lang,
    });
    if (r['@type'] == 'formattedText') return r['text'] as String?;
    lastError = 'Telegram не смог перевести: ${r['message'] ?? 'неизвестная ошибка'}';
    return null;
  }

  Future<String?> _libre(String text, String lang) async {
    final base = settings.libreUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      lastError = 'Укажи адрес сервера LibreTranslate в настройках.';
      return null;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.postUrl(Uri.parse('$base/translate'));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'q': text,
        'source': 'auto',
        'target': lang == 'zh-CN' ? 'zh' : lang,
        'format': 'text',
        if (settings.libreKey.isNotEmpty) 'api_key': settings.libreKey,
      })));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder.bind(res).join();
      final json = jsonDecode(body);
      if (res.statusCode == 200 && json is Map && json['translatedText'] is String) {
        return json['translatedText'] as String;
      }
      lastError = json is Map && json['error'] != null
          ? 'Сервер перевода: ${json['error']}'
          : 'Сервер перевода ответил кодом ${res.statusCode}.';
    } catch (_) {
      lastError = 'Нет связи с сервером перевода. Проверь адрес.';
    } finally {
      client.close();
    }
    return null;
  }

  bool _worthTranslating(String text, String lang) {
    final t = text.trim();
    if (t.length < 2) return false;
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(t).length;
    if (letters < 2) return false;
    final script = _scriptOf(lang);
    if (script != null && script.allMatches(t).length / letters > 0.6) {
      return false;
    }
    return true;
  }

  RegExp? _scriptOf(String lang) {
    switch (lang) {
      case 'ru':
      case 'uk':
      case 'be':
      case 'kk':
        return RegExp(r'[Ѐ-ӿ]');
      case 'ar':
        return RegExp(r'[؀-ۿ]');
      case 'ja':
        return RegExp(r'[぀-ヿ一-鿿]');
      case 'ko':
        return RegExp(r'[가-힯]');
      case 'zh-CN':
        return RegExp(r'[一-鿿]');
      default:
        return null;
    }
  }
}

class TranslatedText extends StatefulWidget {
  const TranslatedText(this.text, {super.key, this.trailingGap = 0});
  final String text;

  final double trailingGap;

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String? _translated;
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    settings.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(TranslatedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _translated = null;
      _refresh();
    }
  }

  @override
  void dispose() {
    settings.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!settings.autoTranslate) {
      if (_translated != null && mounted) setState(() => _translated = null);
      return;
    }
    final source = widget.text;
    final result = await translator.translate(source);
    if (!mounted || widget.text != source || !settings.autoTranslate) return;
    final changed = result != null && result.trim() != source.trim();
    setState(() => _translated = changed ? result : null);
  }

  @override
  Widget build(BuildContext context) {
    final translated = _translated;
    final gap = widget.trailingGap;
    Widget body(String shown) => Text.rich(TextSpan(children: [
          TextSpan(text: shown),
          if (gap > 0) WidgetSpan(child: SizedBox(width: gap)),
        ]));
    if (translated == null) return body(widget.text);

    final faint = Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    return GestureDetector(
      onTap: () => setState(() => _showOriginal = !_showOriginal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body(_showOriginal ? widget.text : translated),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GenIcon(GIcon.translate, size: 12, color: faint, accent: faint),
                const SizedBox(width: 4),
                Text(
                  _showOriginal ? 'Оригинал' : 'Переведено',
                  style: TextStyle(fontSize: 11, color: faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
