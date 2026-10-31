import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'app_state.dart';
import 'tg_style.dart';

const _playable = {
  'mp4', 'm4v', 'mov', 'webm', 'mkv', 'avi', 'gif',
  'mp3', 'm4a', 'ogg', 'oga', 'opus', 'wav', 'flac', 'aac',
};

bool canPlayInApp(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _playable.contains(path.substring(dot + 1).toLowerCase());
}

Future<void> playInApp(String path, {bool loop = false}) async {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  await nav.push(MaterialPageRoute<void>(
    builder: (_) => PlayerPage(path: path, loop: loop),
    fullscreenDialog: true,
  ));
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.path, this.loop = false});

  final String path;
  final bool loop;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);

  @override
  void initState() {
    super.initState();
    _player.setPlaylistMode(
        widget.loop ? PlaylistMode.single : PlaylistMode.none);
    _player.open(Media(widget.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Tg.theme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: Video(controller: _video)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
