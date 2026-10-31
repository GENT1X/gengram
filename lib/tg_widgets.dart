import 'package:flutter/material.dart';

import 'app_state.dart';
import 'gengram_icons.dart';
import 'tg_style.dart';

Future<T?> tgPush<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => Theme(data: Tg.theme, child: page)),
  );
}

void tgToast(String text) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> tgConfirm(
  BuildContext context, {
  required String title,
  required String text,
  String yes = 'Да',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => Theme(
      data: Tg.theme,
      child: AlertDialog(
        backgroundColor: Tg.panelOver,
        title: Text(title),
        content: Text(text, style: TextStyle(color: Tg.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(yes,
                  style: TextStyle(color: danger ? Tg.danger : Tg.link))),
        ],
      ),
    ),
  );
  return r == true;
}

class TgPage extends StatelessWidget {
  const TgPage(
      {super.key, required this.title, required this.children, this.actions});

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tg.bg,
      appBar: AppBar(title: Text(title), actions: actions),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

class TgSection extends StatelessWidget {
  const TgSection({super.key, this.title, this.footer, required this.children});

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(title!,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Tg.link)),
          ),
        Container(color: Tg.panel, child: Column(children: children)),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(footer!,
                style: TextStyle(
                    fontSize: 13, height: 1.35, color: Tg.textSecondary)),
          ),
      ],
    );
  }
}

class TgIconBox extends StatelessWidget {
  const TgIconBox(this.icon, {super.key, Color? color, this.size = 30})
      : _color = color;

  final GIcon icon;
  final Color? _color;
  final double size;

  Color get color => _color ?? Tg.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(size * 0.27)),
      child: TgIcon(icon, size: size * 0.66, color: Colors.white),
    );
  }
}

class TgRow extends StatelessWidget {
  const TgRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    Color? iconColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  }) : _iconColor = iconColor;

  final String title;
  final GIcon? icon;

  final Widget? leading;
  final Color? _iconColor;
  Color get iconColor => _iconColor ?? Tg.accent;
  final String? subtitle;

  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 16),
            ] else if (icon != null) ...[
              TgIconBox(icon!, color: iconColor),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16, color: danger ? Tg.danger : Tg.text)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              color: Tg.textSecondary)),
                    ),
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(value!,
                    style: TextStyle(fontSize: 15, color: Tg.link)),
              ),
            if (trailing != null)
              Padding(padding: const EdgeInsets.only(left: 8), child: trailing),
          ],
        ),
      ),
    );
  }
}

class TgSwitchRow extends StatelessWidget {
  const TgSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.iconColor,
    this.subtitle,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final GIcon? icon;
  final Color? iconColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return TgRow(
      title: title,
      icon: icon,
      iconColor: iconColor,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

Future<String?> tgPick(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Tg.panel,
    isScrollControlled: true,
    builder: (_) => Theme(
      data: Tg.theme,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o.$2),
                        trailing: o.$1 == selected
                            ? TgIcon(GIcon.check, color: Tg.link)
                            : null,
                        onTap: () => Navigator.pop(context, o.$1),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> tgAsk(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLength = 64,
  int maxLines = 1,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => Theme(
      data: Tg.theme,
      child: AlertDialog(
        backgroundColor: Tg.panelOver,
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: Text('Сохранить', style: TextStyle(color: Tg.link))),
        ],
      ),
    ),
  );
}
