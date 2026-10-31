import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'tg_style.dart';

const wallpapers = <(String, List<Color>)>[
  ('Ночь', [Color(0xFF0E1621), Color(0xFF0E1621)]),
  ('Фиалка', [Color(0xFF1B1030), Color(0xFF3A1F5E)]),
  ('Океан', [Color(0xFF0B1F33), Color(0xFF1B4A6B)]),
  ('Хвоя', [Color(0xFF0B2A22), Color(0xFF1C5A45)]),
  ('Вино', [Color(0xFF2A0F1A), Color(0xFF5C1F36)]),
  ('Уголь', [Color(0xFF000000), Color(0xFF15181C)]),
];

class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final w = wallpapers[settings.wallpaper < 0 || settings.wallpaper >= wallpapers.length ? 0 : settings.wallpaper];
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: w.$2,
                  ),
                ),
              ),
            ),
            if (settings.doodles)
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _DoodlePainter()),
                ),
              ),
            Positioned.fill(child: child),
          ],
        );
      },
    );
  }
}

class _DoodlePainter extends CustomPainter {
  const _DoodlePainter();

  static const _tile = 300.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final items = <(double, double, double, int, double)>[
      for (var i = 0; i < 12; i++)
        (
          rnd.nextDouble() * _tile,
          rnd.nextDouble() * _tile,
          rnd.nextDouble() * math.pi * 2,
          rnd.nextInt(5),
          9 + rnd.nextDouble() * 8,
        ),
    ];
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var ty = 0.0; ty < size.height + _tile; ty += _tile) {
      for (var tx = 0.0; tx < size.width + _tile; tx += _tile) {
        for (final it in items) {
          canvas.save();
          canvas.translate(tx + it.$1, ty + it.$2);
          canvas.rotate(it.$3);
          _shape(canvas, paint, it.$4, it.$5);
          canvas.restore();
        }
      }
    }
  }

  void _shape(Canvas canvas, Paint paint, int kind, double r) {
    switch (kind) {
      case 0: // звезда
        {
          final p = Path();
          for (var k = 0; k < 10; k++) {
            final rr = k.isEven ? r : r * 0.45;
            final a = -math.pi / 2 + k * math.pi / 5;
            final pt = Offset(rr * math.cos(a), rr * math.sin(a));
            if (k == 0) {
              p.moveTo(pt.dx, pt.dy);
            } else {
              p.lineTo(pt.dx, pt.dy);
            }
          }
          p.close();
          canvas.drawPath(p, paint);
        }
      case 1: // кольцо
        canvas.drawCircle(Offset.zero, r * 0.7, paint);
      case 2: // сердечко
        {
          final p = Path()
            ..moveTo(0, r * 0.8)
            ..cubicTo(-r * 1.4, -r * 0.1, -r * 0.5, -r * 1.0, 0, -r * 0.3)
            ..cubicTo(r * 0.5, -r * 1.0, r * 1.4, -r * 0.1, 0, r * 0.8);
          canvas.drawPath(p, paint);
        }
      case 3: // плюс
        canvas.drawLine(Offset(-r * 0.6, 0), Offset(r * 0.6, 0), paint);
        canvas.drawLine(Offset(0, -r * 0.6), Offset(0, r * 0.6), paint);
      default: // волна
        {
          final p = Path()
            ..moveTo(-r, 0)
            ..quadraticBezierTo(-r / 2, -r * 0.8, 0, 0)
            ..quadraticBezierTo(r / 2, r * 0.8, r, 0);
          canvas.drawPath(p, paint);
        }
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => false;
}

class WallpaperPicker extends StatelessWidget {
  const WallpaperPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < wallpapers.length; i++)
            GestureDetector(
              onTap: () => settings.change(() => settings.wallpaper = i),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: wallpapers[i].$2),
                      border: Border.all(
                          color: settings.wallpaper == i
                              ? Tg.link
                              : Tg.outline,
                          width: settings.wallpaper == i ? 3 : 1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(wallpapers[i].$1,
                      style: TextStyle(
                          fontSize: 12, color: Tg.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
