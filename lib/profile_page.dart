import 'package:flutter/material.dart';

import 'accounts.dart';
import 'app_state.dart';
import 'banner.dart';
import 'chat_lock.dart';
import 'chat_page.dart';
import 'media.dart';
import 'profile_sheet.dart';
import 'streamer.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

class _Gift {
  const _Gift({this.sticker, required this.title, this.stars = 0, this.nft = false});
  final Map? sticker;
  final String title;
  final int stars;
  final bool nft;
}

class _Story {
  const _Story({this.file, this.mini, this.video = false});
  final Map? file;
  final Map? mini;
  final bool video;
}

enum _Tab { stories, gifts, nft }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.chatId, this.canWrite = true});

  final int chatId;
  final bool canWrite;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _chat;
  Map<String, dynamic>? _user;
  String _bio = '';
  List<_Story> _stories = const [];
  int _storyTotal = 0;
  List<_Gift> _gifts = const [];
  String? _giftError;
  bool _loadingExtra = true;
  _Tab _tab = _Tab.stories;

  int? get _userId {
    final t = _chat?['type'] as Map?;
    final id = t?['user_id'];
    return id is int ? id : null;
  }

  bool get _isMe => _userId != null && _userId == accounts.active.me?['id'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final td = accounts.active.td;
    final chat = await td.request({'@type': 'getChat', 'chat_id': widget.chatId});
    if (!mounted || chat['@type'] != 'chat') return;
    setState(() => _chat = chat);
    final uid = _userId;
    if (uid != null) {
      final user = await td.request({'@type': 'getUser', 'user_id': uid});
      final full = await td.request({'@type': 'getUserFullInfo', 'user_id': uid});
      if (!mounted) return;
      setState(() {
        if (user['@type'] == 'user') _user = user;
        final bio = full['bio'];
        _bio = bio is Map ? '${bio['text'] ?? ''}' : (bio is String ? bio : '');
      });
    }
    await Future.wait([_loadStories(), _loadGifts()]);
    if (mounted) setState(() => _loadingExtra = false);
  }

  Future<void> _loadStories() async {
    final r = await accounts.active.td.request({
      '@type': 'getChatPostedToChatPageStories',
      'chat_id': widget.chatId,
      'from_story_id': 0,
      'limit': 60,
    });
    if (r['@type'] != 'stories') return;
    final out = <_Story>[];
    for (final raw in ((r['stories'] as List?) ?? const [])) {
      final s = raw as Map;
      final c = s['content'] as Map?;
      switch (c?['@type']) {
        case 'storyContentPhoto':
          final photo = c!['photo'] as Map?;
          final sizes = ((photo?['sizes'] as List?) ?? const []).cast<Map>();
          Map? pick;
          for (final z in sizes) {
            if (((z['width'] as int?) ?? 0) >= 320) {
              pick = z;
              break;
            }
          }
          pick ??= sizes.isNotEmpty ? sizes.last : null;
          out.add(_Story(
              file: pick?['photo'] as Map?, mini: photo?['minithumbnail'] as Map?));
        case 'storyContentVideo':
          final video = c!['video'] as Map?;
          out.add(_Story(
              file: (video?['thumbnail'] as Map?)?['file'] as Map?,
              mini: video?['minithumbnail'] as Map?,
              video: true));
      }
    }
    if (!mounted) return;
    setState(() {
      _stories = out;
      _storyTotal = (r['total_count'] as int?) ?? out.length;
    });
  }

  Future<void> _loadGifts() async {
    final uid = _userId;
    if (uid == null) return;
    final r = await accounts.active.td.request({
      '@type': 'getReceivedGifts',
      'owner_id': {'@type': 'messageSenderUser', 'user_id': uid},
      'offset': '',
      'limit': 100,
      'exclude_unsaved': false,
      'exclude_saved': false,
      'exclude_unlimited': false,
      'exclude_upgraded': false,
      'sort_by_price': false,
    });
    if (!mounted) return;
    if (r['@type'] == 'error') {
      setState(() => _giftError = '${r['message']}');
      return;
    }
    final out = <_Gift>[];
    for (final raw in ((r['gifts'] as List?) ?? const [])) {
      final g = (raw as Map)['gift'] as Map?;
      if (g == null) continue;
      final t = g['@type'];
      final inner = (g['gift'] is Map ? g['gift'] : g) as Map;
      if (t == 'sentGiftUpgraded' || t == 'upgradedGift') {
        final sticker = (inner['model'] as Map?)?['sticker'] as Map?;
        out.add(_Gift(
            sticker: sticker,
            title: '${inner['title'] ?? 'NFT'} #${inner['number'] ?? ''}'.trim(),
            nft: true));
      } else {
        out.add(_Gift(
            sticker: inner['sticker'] as Map?,
            title: 'Подарок',
            stars: (inner['star_count'] as int?) ?? 0));
      }
    }
    setState(() => _gifts = out);
  }

  String get _title {
    final u = _user;
    if (u != null) {
      final n = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      if (n.isNotEmpty) return n;
    }
    return '${_chat?['title'] ?? ''}';
  }

  String? get _phone {
    final p = '${_user?['phone_number'] ?? ''}';
    return p.isEmpty ? null : hideInStream('+$p');
  }

  String? get _username {
    final un = _user?['usernames'];
    if (un is Map && un['active_usernames'] is List && (un['active_usernames'] as List).isNotEmpty) {
      return '@${(un['active_usernames'] as List).first}';
    }
    final old = _user?['username'];
    return (old is String && old.isNotEmpty) ? '@$old' : null;
  }

  Future<void> _write() async {
    if (!await chatLock.ensure(context, widget.chatId)) return;
    if (!mounted) return;
    await tgPush(context, ChatPage(chatId: widget.chatId, title: _title));
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, color: Tg.text)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 13, color: Tg.textSecondary)),
          ],
        ),
      );

  Widget _tabChip(_Tab t, String label, int count) {
    final on = _tab == t;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(count > 0 ? '$label $count' : label),
        selected: on,
        onSelected: (_) => setState(() => _tab = t),
      ),
    );
  }

  Widget _storiesGrid() {
    if (_loadingExtra && _stories.isEmpty) return _hint(null);
    if (_stories.isEmpty) return _hint('Публикаций нет');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.75),
      itemCount: _stories.length,
      itemBuilder: (_, i) {
        final s = _stories[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TgImage(file: s.file, mini: s.mini),
              if (s.video)
                const Positioned(
                  right: 6,
                  bottom: 6,
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _giftsGrid(bool nftOnly) {
    final list = [for (final g in _gifts) if (!nftOnly || g.nft) g];
    if (_loadingExtra && list.isEmpty) return _hint(null);
    if (_giftError != null && list.isEmpty) {
      return _hint('Telegram не отдал список: $_giftError');
    }
    if (list.isEmpty) return _hint(nftOnly ? 'NFT нет' : 'Подарков нет');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final g = list[i];
        return Container(
          decoration: BoxDecoration(
            color: Tg.panelOver,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: g.sticker == null
                    ? const Center(child: Text('🎁', style: TextStyle(fontSize: 36)))
                    : StickerView(g.sticker!, size: 76),
              ),
              const SizedBox(height: 4),
              Text(
                g.nft ? g.title : (g.stars > 0 ? '⭐ ${g.stars}' : g.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: Tg.text),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hint(String? text) => Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: text == null
              ? const CircularProgressIndicator()
              : Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Tg.textSecondary)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final isUser = _userId != null;
    final nftCount = _gifts.where((g) => g.nft).length;
    return Theme(
      data: Tg.theme,
      child: Scaffold(
        backgroundColor: Tg.bg,
        appBar: AppBar(
          backgroundColor: Tg.panel,
          title: const Text('Профиль'),
        ),
        body: chat == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  BannerView(chatId: widget.chatId),
                  const SizedBox(height: 12),
                  Center(
                    child: TgAvatar(
                      id: widget.chatId,
                      title: _title,
                      photo: ((chat['photo'] as Map?)?['big'] ??
                          (chat['photo'] as Map?)?['small']) as Map?,
                      size: 110,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(_title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700, color: Tg.text)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (widget.canWrite && !_isMe)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _write,
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Написать'),
                          ),
                        ),
                      if (widget.canWrite && !_isMe) const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showProfileSheet(context, widget.chatId),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Подробнее'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_phone != null) _info('Телефон', _phone!),
                  if (_username != null) _info('Имя пользователя', _username!),
                  if (_bio.isNotEmpty) _info('О себе', _bio),
                  if (settings.showIds) _info('ID', '${_userId ?? widget.chatId}'),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tabChip(_Tab.stories, 'Публикации', _storyTotal),
                        if (isUser) _tabChip(_Tab.gifts, 'Подарки', _gifts.length),
                        if (isUser) _tabChip(_Tab.nft, 'NFT', nftCount),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_tab == _Tab.stories)
                    _storiesGrid()
                  else
                    _giftsGrid(_tab == _Tab.nft),
                ],
              ),
      ),
    );
  }
}
