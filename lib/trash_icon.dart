import 'package:flutter/material.dart';

class TrashIcon extends StatelessWidget {
  const TrashIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return CustomPaint(size: Size.square(size), painter: _TrashPainter(c));
  }
}

class _TrashPainter extends CustomPainter {
  _TrashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Крышка
    canvas.drawLine(Offset(w * .14, w * .26), Offset(w * .86, w * .26), p);

    // Ручка крышки
    final handle = Path()
      ..moveTo(w * .38, w * .26)
      ..lineTo(w * .38, w * .13)
      ..lineTo(w * .62, w * .13)
      ..lineTo(w * .62, w * .26);
    canvas.drawPath(handle, p);

    // Корпус с чуть суженным низом
    final body = Path()
      ..moveTo(w * .24, w * .26)
      ..lineTo(w * .29, w * .84)
      ..quadraticBezierTo(w * .30, w * .91, w * .37, w * .91)
      ..lineTo(w * .63, w * .91)
      ..quadraticBezierTo(w * .70, w * .91, w * .71, w * .84)
      ..lineTo(w * .76, w * .26);
    canvas.drawPath(body, p);

    // Рёбра
    canvas.drawLine(Offset(w * .42, w * .42), Offset(w * .43, w * .75), p);
    canvas.drawLine(Offset(w * .58, w * .42), Offset(w * .57, w * .75), p);
  }

  @override
  bool shouldRepaint(_TrashPainter old) => old.color != color;
}
