import 'package:flutter/material.dart';

import 'app_state.dart';
import 'media.dart';
import 'tg_style.dart';

const _emojiList = [
  '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🙂', '😉', '😊', '😇',
  '🥰', '😍', '🤩', '😘', '😗', '😋', '😛', '😜', '🤪', '😎', '🤓', '🥳',
  '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '😣', '😖', '😫', '😩', '🥺',
  '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨',
  '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬',
  '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐',
  '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹',
  '👻', '💀', '👽', '🤖', '💩', '🙈', '🙉', '🙊', '👋', '🤚', '🖐', '✋',
  '🖖', '👌', '🤌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇',
  '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤝', '🙏', '💪',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '💕', '💞', '💓',
  '💗', '💖', '💘', '💝', '🔥', '✨', '⭐', '🌟', '💫', '⚡', '🎉', '🎊',
  '🎁', '🎂', '🍕', '🍔', '🍟', '🍺', '🍷', '☕', '⚽', '🏀', '🎮', '🎧',
  '🚀', '🌙', '☀️', '🌈', '🌹', '🌸', '🐶', '🐱', '🦊', '🐼', '🦄', '🐸',
];

class InputPanel extends StatefulWidget {
  const InputPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
    required this.onGif,
    this.onCustomEmoji,
  });

  final void Function(Map sticker)? onCustomEmoji;

  final void Function(String emoji) onEmoji;
  final void Function(Map sticker) onSticker;
  final void Function(Map animation) onGif;

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> {
  int _tab = 2;

  List<Map>? _gifs;
  List<Map> _recent = [];
  List<Map> _sets = [];
  final Map<String, List<Map>> _setStickers = {};
  int _setIndex = -1; // -1 = недавние
  bool _loadedStickers = false;
  List<Map> _emojiSets = [];
  final Map<String, List<Map>> _emojiSetItems = {};
  int _emojiSetIndex = 0;
  bool _loadedEmoji = false;

  @override
  void initState() {
    super.initState();
    _loadGifs();
    _loadStickers();
    _loadPremiumEmoji();
  }

  Future<void> _loadPremiumEmoji() async {
    final r = await td.request({
      '@type': 'getInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeCustomEmoji'},
    });
    if (!mounted) return;
    setState(() {
      _emojiSets = ((r['sets'] as List?) ?? const []).cast<Map>();
      _loadedEmoji = true;
    });
    if (_emojiSets.isNotEmpty) _selectEmojiSet(0);
  }

  Future<void> _selectEmojiSet(int i) async {
    setState(() => _emojiSetIndex = i);
    final id = '${_emojiSets[i]['id']}';
    if (_emojiSetItems.containsKey(id)) return;
    final r = await td.request({'@type': 'getStickerSet', 'set_id': _emojiSets[i]['id']});
    if (!mounted) return;
    setState(() => _emojiSetItems[id] =
        ((r['stickers'] as List?) ?? const []).cast<Map>());
  }

  Widget _premiumEmoji() {
    if (!_loadedEmoji) {
      return Center(child: CircularProgressIndicator(color: Tg.link));
    }
    if (_emojiSets.isEmpty) {
      return Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
            'Наборов премиум-эмодзи нет. Добавь их в официальном Telegram, и они появятся здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tg.textSecondary)),
      ));
    }
    final items = _emojiSetItems['${_emojiSets[_emojiSetIndex]['id']}'] ?? const <Map>[];
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              for (var i = 0; i < _emojiSets.length; i++)
                GestureDetector(
                  onTap: () => _selectEmojiSet(i),
                  child: Container(
                    width: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _emojiSetIndex == i ? Tg.panelOver : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _cover(_emojiSets[i]),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(6),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 48),
            itemCount: items.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () => widget.onCustomEmoji?.call(items[i]),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: StickerView(items[i], size: 36),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadGifs() async {
    final r = await td.request({'@type': 'getSavedAnimations'});
    if (!mounted) return;
    setState(() => _gifs = ((r['animations'] as List?) ?? const []).cast<Map>());
  }

  Future<void> _loadStickers() async {
    final recent = await td.request({'@type': 'getRecentStickers', 'is_attached': false});
    final sets = await td.request({
      '@type': 'getInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeRegular'},
    });
    if (!mounted) return;
    setState(() {
      _recent = ((recent['stickers'] as List?) ?? const []).cast<Map>();
      _sets = ((sets['sets'] as List?) ?? const []).cast<Map>();
      _loadedStickers = true;
      if (_recent.isEmpty && _sets.isNotEmpty) _selectSet(0);
    });
  }

  Future<void> _selectSet(int i) async {
    setState(() => _setIndex = i);
    if (i < 0) return;
    final id = '${_sets[i]['id']}';
    if (_setStickers.containsKey(id)) return;
    final r = await td.request({'@type': 'getStickerSet', 'set_id': _sets[i]['id']});
    if (!mounted) return;
    setState(() => _setStickers[id] =
        ((r['stickers'] as List?) ?? const []).cast<Map>());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      color: Tg.panel,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 52,
            child: switch (_tab) {
              0 => _emoji(),
              1 => _gifGrid(),
              3 => _premiumEmoji(),
              _ => _stickers(),
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Tg.panelOver,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in const [(0, 'Эмодзи'), (1, 'GIF'), (2, 'Стикеры'), (3, '⭐ Премиум')])
                      GestureDetector(
                        onTap: () => setState(() => _tab = t.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: _tab == t.$1 ? Tg.selected : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t.$2,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _tab == t.$1 ? Colors.white : Tg.textSecondary)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emoji() => GridView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 46),
        itemCount: _emojiList.length,
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onEmoji(_emojiList[i]),
          child: Center(
              child: Text(_emojiList[i], style: const TextStyle(fontSize: 26))),
        ),
      );

  Widget _gifGrid() {
    final gifs = _gifs;
    if (gifs == null) {
      return Center(child: CircularProgressIndicator(color: Tg.link));
    }
    if (gifs.isEmpty) {
      return Center(
          child: Text('Сохранённых GIF пока нет',
              style: TextStyle(color: Tg.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: gifs.length,
      itemBuilder: (_, i) {
        final g = gifs[i];
        return GestureDetector(
          onTap: () => widget.onGif(g),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TgImage(
                file: (g['thumbnail'] as Map?)?['file'] as Map?,
                mini: g['minithumbnail'] as Map?),
          ),
        );
      },
    );
  }

  Widget _stickers() {
    if (!_loadedStickers) {
      return Center(child: CircularProgressIndicator(color: Tg.link));
    }
    final List<Map> shown;
    if (_setIndex < 0) {
      shown = _recent;
    } else {
      shown = _setStickers['${_sets[_setIndex]['id']}'] ?? const [];
    }
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            children: [
              if (_recent.isNotEmpty)
                _tabButton(-1, Icon(Icons.access_time, color: Tg.textSecondary)),
              for (var i = 0; i < _sets.length; i++) _tabButton(i, _cover(_sets[i])),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text('Стикеров нет',
                      style: TextStyle(color: Tg.textSecondary)))
              : GridView.builder(
                  padding: const EdgeInsets.all(6),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 84),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => widget.onSticker(shown[i]),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: StickerView(shown[i], size: 72, thumbOnly: true),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _cover(Map set) {
    final covers = (set['covers'] as List?) ?? const [];
    if (covers.isNotEmpty) {
      return StickerView(covers.first as Map, size: 30, thumbOnly: true);
    }
    return TgImage(
        file: (set['thumbnail'] as Map?)?['file'] as Map?, width: 30, height: 30);
  }

  Widget _tabButton(int i, Widget child) => GestureDetector(
        onTap: () => _selectSet(i),
        child: Container(
          width: 42,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _setIndex == i ? Tg.panelOver : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      );
}
