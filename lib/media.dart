import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:open_filex/open_filex.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'tg_style.dart';
import 'video_player.dart';
import 'tg_widgets.dart';

String? readyPath(Map? file) {
  final local = file?['local'] as Map?;
  final path = local?['path'] as String?;
  final done = local?['is_downloading_completed'] == true;
  return (done && path != null && path.isNotEmpty) ? path : null;
}

final Map<String, Future<String?>> _paths = {};

Future<String?> tdFilePath(Map? file, {int priority = 8}) {
  if (file == null) return Future.value(null);
  final ready = readyPath(file);
  if (ready != null) return Future.value(ready);
  final id = file['id'];
  if (id is! int) return Future.value(null);
  final account = accounts.active;
  final key = '${account.id}:$id';
  return _paths[key] ??= _download(account, id, priority).then((p) {
    if (p == null) _paths.remove(key);
    return p;
  });
}

Future<String?> _download(Account account, int id, int priority) async {
  for (var i = 0; i < 3; i++) {
    final r = await account.td.request({
      '@type': 'downloadFile',
      'file_id': id,
      'priority': priority,
      'offset': 0,
      'limit': 0,
      'synchronous': true,
    });
    final p = readyPath(r);
    if (p != null) return p;
    await Future<void>.delayed(Duration(seconds: 1 + i));
  }
  return null;
}

Future<void> openFileMap(Map? file, {bool loop = false}) async {
  if (file == null) return;
  if (readyPath(file) == null) tgToast('Загружаем файл…');
  final path = await tdFilePath(file, priority: 16);
  if (path == null) {
    tgToast('Не удалось скачать файл');
    return;
  }
  if (canPlayInApp(path)) {
    await playInApp(path, loop: loop);
    return;
  }
  final r = await OpenFilex.open(path);
  if (r.type != ResultType.done) {
    tgToast('Не удалось открыть файл: ${r.message}');
  }
}

class TgImage extends StatefulWidget {
  const TgImage({
    super.key,
    required this.file,
    this.mini,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.priority = 8,
  });

  final Map? file;
  final Map? mini;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int priority;

  @override
  State<TgImage> createState() => _TgImageState();
}

class _TgImageState extends State<TgImage> {
  late Future<String?> _future =
      tdFilePath(widget.file, priority: widget.priority);

  @override
  void didUpdateWidget(TgImage old) {
    super.didUpdateWidget(old);
    if (old.file?['id'] != widget.file?['id']) {
      _future = tdFilePath(widget.file, priority: widget.priority);
    }
  }

  Widget _flat() => Container(
      width: widget.width, height: widget.height, color: Tg.panelOver);

  Widget _placeholder() {
    final data = widget.mini?['data'];
    if (data is String && data.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(data);
        return Image.memory(bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _flat());
      } catch (_) {
        return _flat();
      }
    }
    return _flat();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      initialData: readyPath(widget.file),
      future: _future,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return _placeholder();
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final w = widget.width;
        return Image.file(
          File(p),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheWidth: (w != null && w.isFinite) ? (w * dpr).round() : 1000,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      },
    );
  }
}

class StickerView extends StatelessWidget {
  const StickerView(this.sticker,
      {super.key, this.size = 160, this.thumbOnly = false});

  final Map sticker;
  final double size;

  final bool thumbOnly;

  @override
  Widget build(BuildContext context) {
    final inner = _inner(context);
    if (!settings.roundStickers || size < 100) return inner;
    return ClipRRect(borderRadius: BorderRadius.circular(size * 0.16), child: inner);
  }

  Widget _inner(BuildContext context) {
    final fmt = (sticker['format'] as Map?)?['@type'];
    final file = sticker['sticker'] as Map?;
    final thumb = (sticker['thumbnail'] as Map?)?['file'] as Map?;
    final isTgs = fmt == 'stickerFormatTgs' || sticker['is_animated'] == true;
    final isWebm = fmt == 'stickerFormatWebm' || sticker['is_video'] == true;

    Widget still() => TgImage(
          file: (isTgs || isWebm) ? thumb : (file ?? thumb),
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

    if (thumbOnly || isWebm || !isTgs) return SizedBox.square(dimension: size, child: still());

    return SizedBox.square(
      dimension: size,
      child: FutureBuilder<String?>(
        initialData: readyPath(file),
        future: tdFilePath(file),
        builder: (context, snap) {
          final p = snap.data;
          if (p == null) return still();
          return _AnimatedSticker(path: p, size: size, still: still);
        },
      ),
    );
  }
}

Future<void> showPhotoViewer(BuildContext context, Map? file, Map? mini) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Theme(
      data: Tg.theme,
      child: Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 6,
                child: Center(
                  child: TgImage(
                      file: file,
                      mini: mini,
                      fit: BoxFit.contain,
                      priority: 16),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final Map<String, Future<Map?>> _customEmoji = {};

Future<Map?> customEmojiSticker(String id) {
  final account = accounts.active;
  final key = '${account.id}:$id';
  return _customEmoji[key] ??= () async {
    final r = await account.td.request({
      '@type': 'getCustomEmojiStickers',
      'custom_emoji_ids': [id],
    });
    final list = r['stickers'];
    if (list is List && list.isNotEmpty) return list.first as Map;
    _customEmoji.remove(key);
    return null;
  }();
}

class CustomEmojiView extends StatelessWidget {
  const CustomEmojiView(this.id, {super.key, this.size = 22, this.fallback = ''});
  final String id;
  final double size;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map?>(
      future: customEmojiSticker(id),
      builder: (context, snap) {
        final st = snap.data;
        if (st == null) {
          return SizedBox(
              width: size,
              height: size,
              child: Center(
                  child: Text(fallback, style: TextStyle(fontSize: size * 0.8))));
        }
        return StickerView(st, size: size);
      },
    );
  }
}

class _StickerBudget extends ChangeNotifier {
  final List<Object> _playing = [];

  bool request(Object token) {
    if (_playing.contains(token)) return true;
    if (_playing.length >= settings.maxStickers) return false;
    _playing.add(token);
    return true;
  }

  void release(Object token) {
    if (_playing.remove(token)) {
      scheduleMicrotask(notifyListeners);
    }
  }
}

final _budget = _StickerBudget();

class _AnimatedSticker extends StatefulWidget {
  const _AnimatedSticker(
      {required this.path, required this.size, required this.still});

  final String path;
  final double size;
  final Widget Function() still;

  @override
  State<_AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends State<_AnimatedSticker> {
  final _token = Object();
  bool _visible = false;
  bool _play = false;

  @override
  void initState() {
    super.initState();
    _budget.addListener(_recheck);
    settings.addListener(_recheck);
  }

  @override
  void dispose() {
    _budget.removeListener(_recheck);
    settings.removeListener(_recheck);
    _budget.release(_token);
    super.dispose();
  }

  void _recheck() {
    if (!mounted) return;
    final want = _visible && !settings.saver && _budget.request(_token);
    if (!want) _budget.release(_token);
    if (want != _play) setState(() => _play = want);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(_token),
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction > 0.2;
        _recheck();
      },
      child: _play
          ? Lottie.file(
              File(widget.path),
              width: widget.size,
              height: widget.size,
              decoder: LottieComposition.decodeGZip,
              errorBuilder: (_, __, ___) => widget.still(),
            )
          : widget.still(),
    );
  }
}
