import 'package:flutter/material.dart';

import 'app_state.dart';
import 'themes.dart';
import 'tg_style.dart';
import 'tg_widgets.dart';

const _accents = <int>[
  0xFF3390EC, 0xFF2EA6A6, 0xFF3FAE5A, 0xFFE5A02E,
  0xFFE5834F, 0xFFEC6A6A, 0xFFD8588A, 0xFF9B6BFF,
];

class ThemesPage extends StatelessWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) {
        final hue = themes.accent == 0
            ? HSLColor.fromColor(Tg.p.accent).hue
            : HSLColor.fromColor(Color(themes.accent)).hue;
        return TgPage(title: 'Оформление', children: [
          TgSection(title: 'Темы', children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in kPalettes)
                    _PaletteCard(
                      palette: themes.accent == 0 ? p : p.withAccent(Color(themes.accent)),
                      selected: themes.auto
                          ? (p.id == themes.dayId || p.id == themes.nightId)
                          : p.id == themes.id,
                      onTap: () => themes.choose(p.id),
                    ),
                ],
              ),
            ),
          ]),
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => TgSection(
              title: 'Сообщения',
              footer: 'Скругление и ширина пузырей, вид стикеров.',
              children: [
                _SliderRow(
                  label: 'Скругление пузырей',
                  value: settings.bubbleRadius,
                  min: 4,
                  max: 26,
                  onChanged: (v) => settings.change(() => settings.bubbleRadius = v),
                ),
                _SliderRow(
                  label: 'Ширина сообщений',
                  value: settings.bubbleWidth,
                  min: 280,
                  max: 760,
                  onChanged: (v) => settings.change(() => settings.bubbleWidth = v),
                ),
                TgSwitchRow(
                  title: 'Скруглённые стикеры',
                  value: settings.roundStickers,
                  onChanged: (v) => settings.change(() => settings.roundStickers = v),
                ),
                TgSwitchRow(
                  title: 'Показывать ID в профиле',
                  value: settings.showIds,
                  onChanged: (v) => settings.change(() => settings.showIds = v),
                ),
              ],
            ),
          ),
          TgSection(
            title: 'Автоматически',
            footer:
                'Включите, и GenGram сам переключается между дневной и ночной темой вслед за системой. '
                'Дневная и ночная — последние выбранные светлая и тёмная.',
            children: [
              TgSwitchRow(
                title: 'День и ночь по системе',
                value: themes.auto,
                onChanged: themes.setAuto,
              ),
            ],
          ),
          TgSection(
            title: 'Свой цвет акцента',
            footer: 'Цвет кнопок, ссылок, своих сообщений и счётчиков.',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  GestureDetector(
                    onTap: () => themes.setAccent(null),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Tg.panelOver,
                      child: Icon(Icons.restart_alt,
                          size: 18, color: Tg.textSecondary),
                    ),
                  ),
                  for (final c in _accents)
                    GestureDetector(
                      onTap: () => themes.setAccent(c),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(c),
                        child: themes.accent == c
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Slider(
                  min: 0,
                  max: 360,
                  value: hue.clamp(0.0, 360.0),
                  activeColor: Tg.accent,
                  onChanged: (v) => themes.setAccent(
                      HSLColor.fromAHSL(1, v, 0.75, 0.55).toColor().value),
                ),
              ),
            ],
          ),
        ]);
      },
    );
  }
}

class _PaletteCard extends StatelessWidget {
  const _PaletteCard(
      {required this.palette, required this.selected, required this.onTap});

  final TgPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    Widget bubble(Color c, double w, bool right) => Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: w,
            height: 14,
            margin: const EdgeInsets.only(bottom: 5),
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
          ),
        );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(children: [
          Container(
            height: 118,
            decoration: BoxDecoration(
              color: p.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? p.accent : p.outline, width: selected ? 2.5 : 1),
            ),
            child: Column(children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    bubble(p.incoming, 52, false),
                    bubble(p.outgoing, 62, true),
                    bubble(p.incoming, 38, false),
                    bubble(p.outgoing, 44, true),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(p.name,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: Tg.text)),
        ]),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.round()}',
              style: TextStyle(fontSize: 15, color: Tg.text)),
          Slider(
            min: min,
            max: max,
            value: value.clamp(min, max).toDouble(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
