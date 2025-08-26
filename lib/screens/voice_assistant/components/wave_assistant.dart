import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double t; // animation phase 0..1
  final double level; // audio intensity 0..1

  WavePainter({required this.t, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final midY = size.height / 2;
    final width = size.width;

    final amplitude = (20 + 60 * level); // scale with mic level
    final phase = 2 * math.pi * t;

    for (int i = 0; i < 3; i++) {
      final color = Colors.blueAccent.withOpacity(0.6 - i * 0.2);
      paint.color = color;

      final path = Path();
      for (double x = 0; x <= width; x++) {
        final y =
            midY +
            math.sin((x / width * 2 * math.pi) * 2 + phase + i) *
                (amplitude - i * 10);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter old) => old.t != t || old.level != level;
}
