import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';

class _Particle {
  _Particle(Random r)
      : angle = r.nextDouble() * 2 * pi,
        speed = 180 + r.nextDouble() * 360,
        size = 4 + r.nextDouble() * 6,
        spin = r.nextDouble() * 8 - 4,
        color = _palette[r.nextInt(_palette.length)],
        round = r.nextBool();

  final double angle;
  final double speed;
  final double size;
  final double spin;
  final Color color;
  final bool round;

  static const _palette = [
    Color(0xFFFFC857),
    Color(0xFFFF6B6B),
    Color(0xFF6BCBFF),
    Color(0xFFB794FF),
    Color(0xFF7EE08A),
    Color(0xFFFFFFFF),
  ];
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t, this.origin);

  final List<_Particle> particles;
  final double t;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t * t).clamp(0.0, 1.0);
    for (final p in particles) {
      final d = p.speed * t;
      final pos = origin +
          Offset(cos(p.angle) * d, sin(p.angle) * d + 420 * t * t);
      final paint = Paint()..color = p.color.withOpacity(fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t * 4);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

class _Burst extends StatefulWidget {
  const _Burst({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1700))
    ..forward().whenComplete(widget.onDone);
  final _r = Random();
  late final List<_Particle> _particles =
      List.generate(70, (_) => _Particle(_r));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: size,
          painter: _BurstPainter(
              _particles, _c.value, Offset(size.width / 2, size.height * 0.55)),
        ),
      ),
    );
  }
}

/// Салют из конфетти поверх всего экрана и лёгкая вибрация.
void showGiftBurst() {
  HapticFeedback.mediumImpact();
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Burst(onDone: () => entry.remove()));
  overlay.insert(entry);
}

/// Число, которое плавно меняется до нового значения (баланс звёзд).
class AnimatedCount extends StatelessWidget {
  const AnimatedCount(this.value, {super.key, this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}
