import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import 'tg_widgets.dart';

final banners = Banners();

const _video = {'mp4', 'webm', 'mov', 'm4v', 'mkv'};

class Banners extends ChangeNotifier {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/gengram_banners');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File?> fileFor(int chatId) async {
    final dir = await _dir();
    for (final e in dir.listSync().whereType<File>()) {
      final name = e.uri.pathSegments.last;
      if (name.startsWith('$chatId.')) return e;
    }
    return null;
  }

  Future<void> pick(int chatId) async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', ..._video],
    );
    final path = r?.files.single.path;
    if (path == null) return;
    await clear(chatId, silent: true);
    final ext = path.split('.').last.toLowerCase();
    final dir = await _dir();
    await File(path).copy('${dir.path}/$chatId.$ext');
    notifyListeners();
    tgToast('Баннер поставлен');
  }

  Future<void> clear(int chatId, {bool silent = false}) async {
    final f = await fileFor(chatId);
    if (f != null) await f.delete();
    if (!silent) notifyListeners();
  }
}

class BannerView extends StatefulWidget {
  const BannerView({super.key, required this.chatId, this.height = 150});

  final int chatId;
  final double height;

  @override
  State<BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView> {
  File? _file;

  @override
  void initState() {
    super.initState();
    banners.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    banners.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final f = await banners.fileFor(widget.chatId);
    if (mounted) setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    if (f == null) return const SizedBox.shrink();
    final ext = f.path.split('.').last.toLowerCase();
    final Widget content = _video.contains(ext)
        ? _VideoBanner(path: f.path)
        : Image.file(f,
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: 1000,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          content,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0x99000000)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _VideoBanner extends StatefulWidget {
  const _VideoBanner({required this.path});
  final String path;

  @override
  State<_VideoBanner> createState() => _VideoBannerState();
}

class _VideoBannerState extends State<_VideoBanner> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.setVolume(0);
    _player.setPlaylistMode(PlaylistMode.single);
    _player.open(Media(widget.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(
        controller: _controller,
        fit: BoxFit.cover,
        controls: NoVideoControls,
      );
}
