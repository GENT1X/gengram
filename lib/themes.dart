import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tg_style.dart';

final themes = ThemeController();

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  SharedPreferences? _prefs;

  String id = 'classic';

  int accent = 0;

  bool auto = false;
  String dayId = 'day';
  String nightId = 'classic';

  TgPalette get palette => _compose(_effectiveId);

  String get _effectiveId {
    if (!auto) return id;
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    return dark ? nightId : dayId;
  }

  TgPalette _compose(String paletteId) {
    var p = kPalettes.firstWhere((e) => e.id == paletteId,
        orElse: () => kPalettes.first);
    if (accent != 0) p = p.withAccent(Color(accent));
    return p;
  }

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    id = prefs.getString('themeId') ?? 'classic';
    accent = prefs.getInt('themeAccent') ?? 0;
    auto = prefs.getBool('themeAuto') ?? false;
    dayId = prefs.getString('themeDay') ?? 'day';
    nightId = prefs.getString('themeNight') ?? 'classic';
    Tg.p = palette;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangePlatformBrightness() {
    if (auto) _apply();
  }

  Future<void> choose(String paletteId) async {
    id = paletteId;
    final p = kPalettes.firstWhere((e) => e.id == paletteId);
    if (p.dark) {
      nightId = paletteId;
    } else {
      dayId = paletteId;
    }
    await _save();
    _apply();
  }

  Future<void> setAccent(int? argb) async {
    accent = argb ?? 0;
    await _save();
    _apply();
  }

  Future<void> setAuto(bool value) async {
    auto = value;
    await _save();
    _apply();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('themeId', id);
    await p.setInt('themeAccent', accent);
    await p.setBool('themeAuto', auto);
    await p.setString('themeDay', dayId);
    await p.setString('themeNight', nightId);
  }

  void _apply() {
    Tg.p = palette;
    notifyListeners();
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }
}
