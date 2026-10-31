import 'dart:math' as math;

import 'package:flutter/material.dart';

class GhostMark extends StatefulWidget {
  const GhostMark({
    super.key,
    this.size = 160,
    this.gaze = Offset.zero,
    this.closed = 0,
  });

  final double size;

  final Offset gaze;

  final double closed;

  @override
  State<GhostMark> createState() => _GhostMarkState();
}

class _GhostMarkState extends State<GhostMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: widget.gaze, end: widget.gaze),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
      builder: (context, gaze, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: widget.closed, end: widget.closed),
        duration: const Duration(milliseconds: 260),
        builder: (context, closed, _) => AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_c.value);
            return Transform.translate(
              offset: Offset(0, (t - 0.5) * widget.size * 0.08),
              child: CustomPaint(
                size: Size(widget.size, widget.size * 1.1),
                painter: _GhostPainter(
                  gaze: gaze,
                  closed: closed,
                  glow: 0.32 + 0.22 * t,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter({required this.gaze, required this.closed, required this.glow});

  final Offset gaze;
  final double closed;
  final double glow;

  Path _body(Size s) {
    final w = s.width, h = s.height;
    final cy = 0.06 * h + 0.4 * w;
    final path = Path()..moveTo(0.1 * w, cy);
    path.arcTo(
        Rect.fromLTWH(0.1 * w, 0.06 * h, 0.8 * w, 0.8 * w), math.pi, math.pi, false);
    final y0 = 0.9 * h;
    path.lineTo(0.9 * w, y0);
    final seg = 0.8 * w / 3;
    final d = 0.07 * h;
    for (var i = 0; i < 3; i++) {
      final x1 = 0.9 * w - (i + 1) * seg;
      final cx = 0.9 * w - (i + 0.5) * seg;
      path.quadraticBezierTo(cx, i.isEven ? y0 + 2 * d : y0 - 2 * d, x1, y0);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final body = _body(s);

    // Свечение
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFFA593FF).withOpacity(glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.09),
    );

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFD9D0FF), Color(0x99B7A6FF)],
          stops: [0, 0.6, 1],
        ).createShader(Offset.zero & s),
    );

    // Лицо
    final ink = Paint()..color = const Color(0xFF241A5C);
    final eyeY = 0.06 * h + 0.4 * w + 0.03 * w;
    final ryOpen = 0.075 * w;
    final ry = ryOpen * (1 - closed) + 0.012 * w * closed;
    for (final ex in [0.36 * w, 0.64 * w]) {
      final c = Offset(ex, eyeY) + gaze * (0.035 * w);
      canvas.drawOval(
          Rect.fromCenter(center: c, width: 0.11 * w, height: 2 * ry), ink);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * w + gaze.dx * 0.02 * w, eyeY + 0.17 * w),
        width: 0.06 * w,
        height: 0.07 * w * (1 - 0.4 * closed),
      ),
      ink,
    );
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.gaze != gaze || old.closed != closed || old.glow != glow;
}
