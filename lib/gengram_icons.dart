import 'package:flutter/material.dart';

enum GIcon {
  ghost, ghostVisible, eye, eyeOff, trash, chat, hiddenChat, lock, unlock, translate, globe, moon, sliders, user, group, channel, bot, idBadge, qr, copy, send, check, doubleCheck, checkCircle, timer, refresh, volume, info, search, chevron, phone, mail, alert, edit, menu, back, close, pin, muted, clock, star, coin, gift, plus, logout,
}

class GenIcon extends StatelessWidget {
  const GenIcon(this.icon, {super.key, this.size, this.color, this.accent});

  final GIcon icon;
  final double? size;
  final Color? color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24.0;
    return SizedBox.square(
      dimension: s,
      child: CustomPaint(
        painter: _IconPainter(
            icon, color ?? theme.color ?? Colors.white, accent ?? const Color(0xFFA593FF)),
      ),
    );
  }
}

class _Shape {
  const _Shape(this.d, {this.accent = false, this.fill = false});
  final String d;
  final bool accent;
  final bool fill;
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.base, this.accent);

  final GIcon icon;
  final Color base;
  final Color accent;

  static final _cache = <String, Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final shape in _shapes[icon]!) {
      final path = _cache.putIfAbsent(shape.d, () => _parse(shape.d));
      final paint = Paint()
        ..isAntiAlias = true
        ..color = shape.accent ? accent : base
        ..style = shape.fill ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.base != base || old.accent != accent;
}

Path _parse(String d) {
  final path = Path();
  final tokens = RegExp(r'[MLHVCQZ]|-?\d*\.?\d+')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0;
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'[A-Z]').hasMatch(t)) {
      cmd = t;
      i++;
      if (cmd == 'Z') {
        path.close();
        continue;
      }
    }
    switch (cmd) {
      case 'M':
        x = n();
        y = n();
        path.moveTo(x, y);
        cmd = 'L';
      case 'L':
        x = n();
        y = n();
        path.lineTo(x, y);
      case 'H':
        x = n();
        path.lineTo(x, y);
      case 'V':
        y = n();
        path.lineTo(x, y);
      case 'C':
        {
          final x1 = n(), y1 = n(), x2 = n(), y2 = n();
          x = n();
          y = n();
          path.cubicTo(x1, y1, x2, y2, x, y);
        }
      case 'Q':
        {
          final x1 = n(), y1 = n();
          x = n();
          y = n();
          path.quadraticBezierTo(x1, y1, x, y);
        }
      default:
        i++;
    }
  }
  return path;
}

const _shapes = <GIcon, List<_Shape>>{
  GIcon.ghost: [
    _Shape('M5 19.5 V11 C5 7 8 4 12 4 C16 4 19 7 19 11 V19.5 Q16.67 23 14.33 19.5 Q12 23 9.67 19.5 Q7.33 23 5 19.5 Z'),
    _Shape('M10.7 11 C10.7 11.66 10.16 12.2 9.5 12.2 C8.84 12.2 8.3 11.66 8.3 11 C8.3 10.34 8.84 9.8 9.5 9.8 C10.16 9.8 10.7 10.34 10.7 11 Z', accent: true, fill: true),
    _Shape('M15.7 11 C15.7 11.66 15.16 12.2 14.5 12.2 C13.84 12.2 13.3 11.66 13.3 11 C13.3 10.34 13.84 9.8 14.5 9.8 C15.16 9.8 15.7 10.34 15.7 11 Z', accent: true, fill: true),
  ],
  GIcon.ghostVisible: [
    _Shape('M5 19.5 V11 C5 7 8 4 12 4 C16 4 19 7 19 11 V19.5 Q16.67 23 14.33 19.5 Q12 23 9.67 19.5 Q7.33 23 5 19.5 Z'),
    _Shape('M10.7 11 C10.7 11.66 10.16 12.2 9.5 12.2 C8.84 12.2 8.3 11.66 8.3 11 C8.3 10.34 8.84 9.8 9.5 9.8 C10.16 9.8 10.7 10.34 10.7 11 Z', fill: true),
    _Shape('M15.7 11 C15.7 11.66 15.16 12.2 14.5 12.2 C13.84 12.2 13.3 11.66 13.3 11 C13.3 10.34 13.84 9.8 14.5 9.8 C15.16 9.8 15.7 10.34 15.7 11 Z', fill: true),
    _Shape('M21.7 4.4 C21.7 5.56 20.76 6.5 19.6 6.5 C18.44 6.5 17.5 5.56 17.5 4.4 C17.5 3.24 18.44 2.3 19.6 2.3 C20.76 2.3 21.7 3.24 21.7 4.4 Z', accent: true, fill: true),
  ],
  GIcon.eye: [
    _Shape('M2.5 12 C5 7.5 8.3 5.5 12 5.5 C15.7 5.5 19 7.5 21.5 12 C19 16.5 15.7 18.5 12 18.5 C8.3 18.5 5 16.5 2.5 12 Z'),
    _Shape('M15 12 C15 13.66 13.66 15 12 15 C10.34 15 9 13.66 9 12 C9 10.34 10.34 9 12 9 C13.66 9 15 10.34 15 12 Z', accent: true),
  ],
  GIcon.eyeOff: [
    _Shape('M2.5 12 C5 7.5 8.3 5.5 12 5.5 C15.7 5.5 19 7.5 21.5 12 C19 16.5 15.7 18.5 12 18.5 C8.3 18.5 5 16.5 2.5 12 Z'),
    _Shape('M15 12 C15 13.66 13.66 15 12 15 C10.34 15 9 13.66 9 12 C9 10.34 10.34 9 12 9 C13.66 9 15 10.34 15 12 Z', accent: true),
    _Shape('M4.5 4.5 L19.5 19.5'),
  ],
  GIcon.trash: [
    _Shape('M4 7 L20 7'),
    _Shape('M9.5 7 L9.5 4.5 L14.5 4.5 L14.5 7'),
    _Shape('M6 7 L7 19.5 Q7.1 21 8.6 21 H15.4 Q16.9 21 17 19.5 L18 7'),
    _Shape('M10 11 L10.3 17', accent: true),
    _Shape('M14 11 L13.7 17', accent: true),
  ],
  GIcon.chat: [
    _Shape('M5 4.5 H19 Q21 4.5 21 6.5 V14.5 Q21 16.5 19 16.5 H11 L6.5 20.5 V16.5 H5 Q3 16.5 3 14.5 V6.5 Q3 4.5 5 4.5 Z'),
    _Shape('M9.55 10.5 C9.55 11.08 9.08 11.55 8.5 11.55 C7.92 11.55 7.45 11.08 7.45 10.5 C7.45 9.92 7.92 9.45 8.5 9.45 C9.08 9.45 9.55 9.92 9.55 10.5 Z', accent: true, fill: true),
    _Shape('M13.05 10.5 C13.05 11.08 12.58 11.55 12 11.55 C11.42 11.55 10.95 11.08 10.95 10.5 C10.95 9.92 11.42 9.45 12 9.45 C12.58 9.45 13.05 9.92 13.05 10.5 Z', accent: true, fill: true),
    _Shape('M16.55 10.5 C16.55 11.08 16.08 11.55 15.5 11.55 C14.92 11.55 14.45 11.08 14.45 10.5 C14.45 9.92 14.92 9.45 15.5 9.45 C16.08 9.45 16.55 9.92 16.55 10.5 Z', accent: true, fill: true),
  ],
  GIcon.hiddenChat: [
    _Shape('M5 4.5 H19 Q21 4.5 21 6.5 V14.5 Q21 16.5 19 16.5 H11 L6.5 20.5 V16.5 H5 Q3 16.5 3 14.5 V6.5 Q3 4.5 5 4.5 Z'),
    _Shape('M10.2 10.3 C10.2 10.96 9.66 11.5 9 11.5 C8.34 11.5 7.8 10.96 7.8 10.3 C7.8 9.64 8.34 9.1 9 9.1 C9.66 9.1 10.2 9.64 10.2 10.3 Z', accent: true, fill: true),
    _Shape('M16.2 10.3 C16.2 10.96 15.66 11.5 15 11.5 C14.34 11.5 13.8 10.96 13.8 10.3 C13.8 9.64 14.34 9.1 15 9.1 C15.66 9.1 16.2 9.64 16.2 10.3 Z', accent: true, fill: true),
  ],
  GIcon.lock: [
    _Shape('M7.5 10.5 H16.5 C17.88 10.5 19 11.62 19 13 V18.5 C19 19.88 17.88 21 16.5 21 H7.5 C6.12 21 5 19.88 5 18.5 V13 C5 11.62 6.12 10.5 7.5 10.5 Z'),
    _Shape('M8 10.5 V8 C8 5.8 9.8 4 12 4 C14.2 4 16 5.8 16 8 V10.5'),
    _Shape('M13.3 15 C13.3 15.72 12.72 16.3 12 16.3 C11.28 16.3 10.7 15.72 10.7 15 C10.7 14.28 11.28 13.7 12 13.7 C12.72 13.7 13.3 14.28 13.3 15 Z', accent: true, fill: true),
    _Shape('M12 16.2 L12 18', accent: true),
  ],
  GIcon.unlock: [
    _Shape('M7.5 10.5 H16.5 C17.88 10.5 19 11.62 19 13 V18.5 C19 19.88 17.88 21 16.5 21 H7.5 C6.12 21 5 19.88 5 18.5 V13 C5 11.62 6.12 10.5 7.5 10.5 Z'),
    _Shape('M8 10.5 V8 C8 5.8 9.8 4 12 4 C14 4 15.6 5.3 15.9 7.2'),
    _Shape('M13.3 15 C13.3 15.72 12.72 16.3 12 16.3 C11.28 16.3 10.7 15.72 10.7 15 C10.7 14.28 11.28 13.7 12 13.7 C12.72 13.7 13.3 14.28 13.3 15 Z', accent: true, fill: true),
    _Shape('M12 16.2 L12 18', accent: true),
  ],
  GIcon.translate: [
    _Shape('M3.5 18 L8.5 6 L13.5 18'),
    _Shape('M5.2 14 L11.8 14'),
    _Shape('M14.8 7.5 L20.5 7.5', accent: true),
    _Shape('M18 5 L20.5 7.5 L18 10', accent: true),
    _Shape('M20.5 16.5 L15 16.5', accent: true),
    _Shape('M17.5 14 L15 16.5 L17.5 19', accent: true),
  ],
  GIcon.globe: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M15.8 12 C15.8 16.69 14.1 20.5 12 20.5 C9.9 20.5 8.2 16.69 8.2 12 C8.2 7.31 9.9 3.5 12 3.5 C14.1 3.5 15.8 7.31 15.8 12 Z', accent: true),
    _Shape('M3.5 12 L20.5 12'),
  ],
  GIcon.moon: [
    _Shape('M11.97 3.5 C7.48 3.51 3.78 7.02 3.51 11.5 C3.25 15.98 6.51 19.89 10.97 20.44 C15.42 20.98 19.53 17.97 20.36 13.56 C17.55 15.35 13.86 14.78 11.73 12.23 C9.6 9.67 9.7 5.93 11.97 3.5 Z'),
    _Shape('M18.2 4.4 L19 6.6 L21.2 7.4 L19 8.2 L18.2 10.4 L17.4 8.2 L15.2 7.4 L17.4 6.6 Z', accent: true, fill: true),
  ],
  GIcon.sliders: [
    _Shape('M3.5 6 L5.9 6'),
    _Shape('M12.1 6 L20.5 6'),
    _Shape('M11.5 6 C11.5 7.38 10.38 8.5 9 8.5 C7.62 8.5 6.5 7.38 6.5 6 C6.5 4.62 7.62 3.5 9 3.5 C10.38 3.5 11.5 4.62 11.5 6 Z', accent: true),
    _Shape('M3.5 12 L11.9 12'),
    _Shape('M18.1 12 L20.5 12'),
    _Shape('M17.5 12 C17.5 13.38 16.38 14.5 15 14.5 C13.62 14.5 12.5 13.38 12.5 12 C12.5 10.62 13.62 9.5 15 9.5 C16.38 9.5 17.5 10.62 17.5 12 Z', accent: true),
    _Shape('M3.5 18 L4.9 18'),
    _Shape('M11.1 18 L20.5 18'),
    _Shape('M10.5 18 C10.5 19.38 9.38 20.5 8 20.5 C6.62 20.5 5.5 19.38 5.5 18 C5.5 16.62 6.62 15.5 8 15.5 C9.38 15.5 10.5 16.62 10.5 18 Z', accent: true),
  ],
  GIcon.user: [
    _Shape('M15.6 8 C15.6 9.99 13.99 11.6 12 11.6 C10.01 11.6 8.4 9.99 8.4 8 C8.4 6.01 10.01 4.4 12 4.4 C13.99 4.4 15.6 6.01 15.6 8 Z', accent: true),
    _Shape('M4.5 20 C4.5 15.8 7.8 13.5 12 13.5 C16.2 13.5 19.5 15.8 19.5 20'),
  ],
  GIcon.group: [
    _Shape('M19.2 8.5 C19.2 9.94 18.04 11.1 16.6 11.1 C15.16 11.1 14 9.94 14 8.5 C14 7.06 15.16 5.9 16.6 5.9 C18.04 5.9 19.2 7.06 19.2 8.5 Z', accent: true),
    _Shape('M16.8 13.4 C19.3 13.7 21 15.5 21 18.5', accent: true),
    _Shape('M12.2 8.5 C12.2 10.27 10.77 11.7 9 11.7 C7.23 11.7 5.8 10.27 5.8 8.5 C5.8 6.73 7.23 5.3 9 5.3 C10.77 5.3 12.2 6.73 12.2 8.5 Z'),
    _Shape('M3 20 C3 16.2 5.6 14 9 14 C12.4 14 15 16.2 15 20'),
  ],
  GIcon.channel: [
    _Shape('M4 10 L4 14 L7 14 L15.5 18.5 L15.5 5.5 L7 10 Z'),
    _Shape('M7 14 L8.4 19.5'),
    _Shape('M18.77 9.06 C20.28 10.73 20.28 13.27 18.77 14.94', accent: true),
    _Shape('M21.32 7.77 C23.16 10.29 23.16 13.71 21.32 16.23', accent: true),
  ],
  GIcon.bot: [
    _Shape('M8 8.5 H16 C17.93 8.5 19.5 10.07 19.5 12 V16 C19.5 17.93 17.93 19.5 16 19.5 H8 C6.07 19.5 4.5 17.93 4.5 16 V12 C4.5 10.07 6.07 8.5 8 8.5 Z'),
    _Shape('M12 8.5 L12 5.2'),
    _Shape('M13.3 3.9 C13.3 4.62 12.72 5.2 12 5.2 C11.28 5.2 10.7 4.62 10.7 3.9 C10.7 3.18 11.28 2.6 12 2.6 C12.72 2.6 13.3 3.18 13.3 3.9 Z', accent: true, fill: true),
    _Shape('M10.3 13.5 C10.3 14.22 9.72 14.8 9 14.8 C8.28 14.8 7.7 14.22 7.7 13.5 C7.7 12.78 8.28 12.2 9 12.2 C9.72 12.2 10.3 12.78 10.3 13.5 Z', accent: true, fill: true),
    _Shape('M16.3 13.5 C16.3 14.22 15.72 14.8 15 14.8 C14.28 14.8 13.7 14.22 13.7 13.5 C13.7 12.78 14.28 12.2 15 12.2 C15.72 12.2 16.3 12.78 16.3 13.5 Z', accent: true, fill: true),
    _Shape('M9.5 17 L14.5 17'),
    _Shape('M2.5 12.5 L2.5 16'),
    _Shape('M21.5 12.5 L21.5 16'),
  ],
  GIcon.idBadge: [
    _Shape('M6 5.5 H18 C19.66 5.5 21 6.84 21 8.5 V15.5 C21 17.16 19.66 18.5 18 18.5 H6 C4.34 18.5 3 17.16 3 15.5 V8.5 C3 6.84 4.34 5.5 6 5.5 Z'),
    _Shape('M8.2 9.8 L8.2 14.2', accent: true),
    _Shape('M11.2 9.8 V14.2 H12.3 C14.5 14.2 16.2 13.3 16.2 12 C16.2 10.7 14.5 9.8 12.3 9.8 Z', accent: true),
  ],
  GIcon.qr: [
    _Shape('M5.3 3.5 H8.7 C9.69 3.5 10.5 4.31 10.5 5.3 V8.7 C10.5 9.69 9.69 10.5 8.7 10.5 H5.3 C4.31 10.5 3.5 9.69 3.5 8.7 V5.3 C3.5 4.31 4.31 3.5 5.3 3.5 Z'),
    _Shape('M15.3 3.5 H18.7 C19.69 3.5 20.5 4.31 20.5 5.3 V8.7 C20.5 9.69 19.69 10.5 18.7 10.5 H15.3 C14.31 10.5 13.5 9.69 13.5 8.7 V5.3 C13.5 4.31 14.31 3.5 15.3 3.5 Z'),
    _Shape('M5.3 13.5 H8.7 C9.69 13.5 10.5 14.31 10.5 15.3 V18.7 C10.5 19.69 9.69 20.5 8.7 20.5 H5.3 C4.31 20.5 3.5 19.69 3.5 18.7 V15.3 C3.5 14.31 4.31 13.5 5.3 13.5 Z'),
    _Shape('M5.9 5.9 L8.1 5.9 L8.1 8.1 L5.9 8.1 Z', accent: true, fill: true),
    _Shape('M15.9 5.9 L18.1 5.9 L18.1 8.1 L15.9 8.1 Z', accent: true, fill: true),
    _Shape('M5.9 15.9 L8.1 15.9 L8.1 18.1 L5.9 18.1 Z', accent: true, fill: true),
    _Shape('M13.8 13.8 L16.2 13.8 L16.2 16.2 L13.8 16.2 Z', accent: true, fill: true),
    _Shape('M18.1 13.8 L20.5 13.8 L20.5 16.2 L18.1 16.2 Z', accent: true, fill: true),
    _Shape('M13.8 18.1 L16.2 18.1 L16.2 20.5 L13.8 20.5 Z', accent: true, fill: true),
    _Shape('M18.1 18.1 L20.5 18.1 L20.5 20.5 L18.1 20.5 Z', accent: true, fill: true),
  ],
  GIcon.copy: [
    _Shape('M11 8.5 H18 C19.38 8.5 20.5 9.62 20.5 11 V18 C20.5 19.38 19.38 20.5 18 20.5 H11 C9.62 20.5 8.5 19.38 8.5 18 V11 C8.5 9.62 9.62 8.5 11 8.5 Z'),
    _Shape('M8.5 15.5 H6 Q3.5 15.5 3.5 13 V6 Q3.5 3.5 6 3.5 H13 Q15.5 3.5 15.5 6 V8.5', accent: true),
  ],
  GIcon.send: [
    _Shape('M3.5 11.2 L20.5 3.8 L15.8 20.2 L11.2 13.2 Z'),
    _Shape('M20.5 3.8 L11.2 13.2', accent: true),
  ],
  GIcon.check: [
    _Shape('M5 12.5 L10 17.5 L19.5 7', accent: true),
  ],
  GIcon.doubleCheck: [
    _Shape('M2 12.5 L6 16.5 L14 7.5'),
    _Shape('M10.2 15.8 L11.5 17 L21.8 7.5', accent: true),
  ],
  GIcon.checkCircle: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M8 12.3 L10.8 15 L16.2 9.2', accent: true),
  ],
  GIcon.timer: [
    _Shape('M19.5 13.5 C19.5 17.64 16.14 21 12 21 C7.86 21 4.5 17.64 4.5 13.5 C4.5 9.36 7.86 6 12 6 C16.14 6 19.5 9.36 19.5 13.5 Z'),
    _Shape('M10 3.2 L14 3.2'),
    _Shape('M12 3.2 L12 6'),
    _Shape('M12 13.5 L12 9.4', accent: true),
    _Shape('M13 13.5 C13 14.05 12.55 14.5 12 14.5 C11.45 14.5 11 14.05 11 13.5 C11 12.95 11.45 12.5 12 12.5 C12.55 12.5 13 12.95 13 13.5 Z', accent: true, fill: true),
  ],
  GIcon.refresh: [
    _Shape('M18.8 8.83 C20.48 12.43 19.06 16.72 15.56 18.6 C12.06 20.49 7.7 19.32 5.62 15.94 C3.53 12.56 4.44 8.14 7.7 5.86'),
    _Shape('M7.2 9.5 L8.35 5.4 L4.1 5.08', accent: true),
  ],
  GIcon.volume: [
    _Shape('M4 9.5 H7.5 L12 5.5 V18.5 L7.5 14.5 H4 Z'),
    _Shape('M15.57 8.79 C17.21 10.61 17.21 13.39 15.57 15.21', accent: true),
    _Shape('M18.3 7.07 C20.57 9.97 20.57 14.03 18.3 16.93', accent: true),
  ],
  GIcon.info: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M13.05 8.3 C13.05 8.88 12.58 9.35 12 9.35 C11.42 9.35 10.95 8.88 10.95 8.3 C10.95 7.72 11.42 7.25 12 7.25 C12.58 7.25 13.05 7.72 13.05 8.3 Z', accent: true, fill: true),
    _Shape('M12 11.4 L12 16.4', accent: true),
  ],
  GIcon.search: [
    _Shape('M16.5 10.5 C16.5 13.81 13.81 16.5 10.5 16.5 C7.19 16.5 4.5 13.81 4.5 10.5 C4.5 7.19 7.19 4.5 10.5 4.5 C13.81 4.5 16.5 7.19 16.5 10.5 Z'),
    _Shape('M15 15 L20.5 20.5', accent: true),
  ],
  GIcon.chevron: [
    _Shape('M9.5 6 L15.5 12 L9.5 18'),
  ],
  GIcon.phone: [
    _Shape('M9.5 3 H14.5 C15.88 3 17 4.12 17 5.5 V18.5 C17 19.88 15.88 21 14.5 21 H9.5 C8.12 21 7 19.88 7 18.5 V5.5 C7 4.12 8.12 3 9.5 3 Z'),
    _Shape('M10.5 6 L13.5 6', accent: true),
    _Shape('M12.95 17.8 C12.95 18.32 12.52 18.75 12 18.75 C11.48 18.75 11.05 18.32 11.05 17.8 C11.05 17.28 11.48 16.85 12 16.85 C12.52 16.85 12.95 17.28 12.95 17.8 Z', accent: true, fill: true),
  ],
  GIcon.mail: [
    _Shape('M6 5.5 H18 C19.66 5.5 21 6.84 21 8.5 V15.5 C21 17.16 19.66 18.5 18 18.5 H6 C4.34 18.5 3 17.16 3 15.5 V8.5 C3 6.84 4.34 5.5 6 5.5 Z'),
    _Shape('M4 7.5 L12 13 L20 7.5', accent: true),
  ],
  GIcon.alert: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M12 7.7 L12 12.6', accent: true),
    _Shape('M13.05 15.9 C13.05 16.48 12.58 16.95 12 16.95 C11.42 16.95 10.95 16.48 10.95 15.9 C10.95 15.32 11.42 14.85 12 14.85 C12.58 14.85 13.05 15.32 13.05 15.9 Z', accent: true, fill: true),
  ],
  GIcon.edit: [
    _Shape('M4 20 L4.8 15.6 L15.9 4.5 Q17.2 3.2 18.5 4.5 L19.5 5.5 Q20.8 6.8 19.5 8.1 L8.4 19.2 Z'),
    _Shape('M13.6 6.8 L17.2 10.4', accent: true),
  ],
  GIcon.menu: [
    _Shape('M4 7 L20 7'),
    _Shape('M4 12 L20 12'),
    _Shape('M4 17 L20 17'),
  ],
  GIcon.back: [
    _Shape('M19 12 L5 12'),
    _Shape('M11 6 L5 12 L11 18'),
  ],
  GIcon.close: [
    _Shape('M6 6 L18 18'),
    _Shape('M18 6 L6 18'),
  ],
  GIcon.pin: [
    _Shape('M9 4 L15 4 L14.2 10 L17 14 L7 14 L9.8 10 Z'),
    _Shape('M12 14 L12 21'),
  ],
  GIcon.muted: [
    _Shape('M6 16 V11 C6 7.7 8.7 5 12 5 C15.3 5 18 7.7 18 11 V16 L19.5 17.5 H4.5 Z'),
    _Shape('M10 19.5 C10.4 20.5 11.1 21 12 21 C12.9 21 13.6 20.5 14 19.5'),
    _Shape('M4 4 L20 20', accent: true),
  ],
  GIcon.clock: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M12 7.5 L12 12 L15 14', accent: true),
  ],
  GIcon.star: [
    _Shape('M12 3.6 L14.35 9.36 L20.56 9.82 L15.8 13.84 L17.29 19.88 L12 16.6 L6.71 19.88 L8.2 13.84 L3.44 9.82 L9.65 9.36 Z'),
  ],
  GIcon.coin: [
    _Shape('M20.5 12 C20.5 16.69 16.69 20.5 12 20.5 C7.31 20.5 3.5 16.69 3.5 12 C3.5 7.31 7.31 3.5 12 3.5 C16.69 3.5 20.5 7.31 20.5 12 Z'),
    _Shape('M12 7.8 L13.23 10.7 L16.37 10.98 L14 13.05 L14.7 16.12 L12 14.5 L9.3 16.12 L10 13.05 L7.63 10.98 L10.77 10.7 Z', accent: true, fill: true),
  ],
  GIcon.gift: [
    _Shape('M6 10 H18 C19.1 10 20 10.9 20 12 V18.5 C20 19.6 19.1 20.5 18 20.5 H6 C4.9 20.5 4 19.6 4 18.5 V12 C4 10.9 4.9 10 6 10 Z'),
    _Shape('M4.2 7 H19.8 C20.46 7 21 7.54 21 8.2 V9.3 C21 9.96 20.46 10.5 19.8 10.5 H4.2 C3.54 10.5 3 9.96 3 9.3 V8.2 C3 7.54 3.54 7 4.2 7 Z'),
    _Shape('M12 7 L12 20.5', accent: true),
    _Shape('M12 7 C10 7 7.5 6.5 7.5 4.8 C7.5 3.4 9.6 3.2 10.7 4.3 C11.4 5 12 7 12 7 Z', accent: true),
    _Shape('M12 7 C14 7 16.5 6.5 16.5 4.8 C16.5 3.4 14.4 3.2 13.3 4.3 C12.6 5 12 7 12 7 Z', accent: true),
  ],
  GIcon.plus: [
    _Shape('M12 5 L12 19'),
    _Shape('M5 12 L19 12'),
  ],
  GIcon.logout: [
    _Shape('M10 4.5 H6 C4.9 4.5 4 5.4 4 6.5 V17.5 C4 18.6 4.9 19.5 6 19.5 H10'),
    _Shape('M9 12 L20 12', accent: true),
    _Shape('M16 8 L20 12 L16 16', accent: true),
  ],
};
