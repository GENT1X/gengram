import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'app_state.dart';
import 'gengram_icons.dart';
import 'keeper.dart';
import 'settings_page.dart';
import 'themes_page.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

class PlusPage extends StatelessWidget {
  const PlusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, appLock]),
      builder: (context, _) => TgPage(title: 'GenGram Plus', children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Tg.accent, Tg.link.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text('GenGram Plus',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        TgSection(title: 'Внешний вид', children: [
          TgRow(
            title: 'Темы и свой акцент',
            subtitle: '9 тем, свой цвет, день и ночь по системе',
            icon: GIcon.sliders,
            iconColor: const Color(0xFF9B6BFF),
            onTap: () => tgPush(context, const ThemesPage()),
          ),
          TgRow(
            title: 'Баннер профиля',
            subtitle: 'Фото, GIF или видео за аватаркой: профиль → «Баннер профиля»',
            icon: GIcon.user,
            iconColor: const Color(0xFF3A9BDC),
            onTap: () => tgToast('Откройте профиль человека и выберите «Баннер профиля»'),
          ),
        ]),
        TgSection(title: 'Приватность', children: [
          TgSwitchRow(
            title: 'Режим призрака',
            subtitle: 'Не показывать «в сети», не отмечать прочитанным',
            icon: GIcon.ghost,
            iconColor: const Color(0xFF8A4FE0),
            value: settings.ghost,
            onChanged: (v) => applyGhost(v),
          ),
          TgRow(
            title: 'Код на приложение',
            subtitle: appLock.enabled ? 'Включён' : 'Выключен',
            icon: GIcon.lock,
            iconColor: const Color(0xFF3FAE5A),
            onTap: () => setupAppLock(context),
          ),
          TgRow(
            title: 'Шифрование базы',
            subtitle: 'Ключ хранится в защищённом хранилище системы',
            icon: GIcon.lock,
            iconColor: const Color(0xFF2EA6A6),
            onTap: () => tgToast('Включается само при первом запуске'),
          ),
        ]),
        TgSection(title: 'Сообщения', children: [
          TgSwitchRow(
            title: 'Сохранять удалённые сообщения',
            icon: GIcon.trash,
            iconColor: const Color(0xFFEC6A6A),
            value: settings.saveDeleted,
            onChanged: (v) => settings.setSaveDeleted(v),
          ),
          TgSwitchRow(
            title: 'Сохранять исчезающие фото и видео',
            icon: GIcon.timer,
            iconColor: const Color(0xFFE5A02E),
            value: settings.keepSelfDestruct,
            onChanged: (v) => settings.change(() => settings.keepSelfDestruct = v),
          ),
          TgRow(
            title: 'Сохранённые исчезающие',
            icon: GIcon.timer,
            iconColor: const Color(0xFFE5A02E),
            onTap: () => tgPush(context, const SavedMediaPage()),
          ),
          TgRow(
            title: 'История правок',
            subtitle: 'В меню сообщения, если его меняли',
            icon: GIcon.edit,
            iconColor: const Color(0xFF3A9BDC),
            onTap: () => tgToast('Долгое нажатие на изменённое сообщение'),
          ),
          TgSwitchRow(
            title: 'Автоперевод',
            icon: GIcon.translate,
            iconColor: const Color(0xFF8A4FE0),
            value: settings.autoTranslate,
            onChanged: (v) => settings.change(() => settings.autoTranslate = v),
          ),
        ]),
        TgSection(title: 'Батарея и трафик', children: [
          TgSwitchRow(
            title: 'Режим экономии',
            subtitle: 'Без автозагрузки медиа и анимации стикеров',
            icon: GIcon.clock,
            iconColor: const Color(0xFF3FAE5A),
            value: settings.saver,
            onChanged: (v) async {
              await settings.change(() => settings.saver = v);
              await reapplySaver();
            },
          ),
        ]),
        TgSection(children: [
          TgRow(
            title: 'Все настройки GenGram',
            icon: GIcon.sliders,
            iconColor: const Color(0xFF708499),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ]),
      ]),
    );
  }
}
