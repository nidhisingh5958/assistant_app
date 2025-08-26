import 'dart:math' as math;
import 'package:flutter/material.dart';

// Enhanced 3D Mesh Painter for sophisticated visualization
class Optimized3DMeshPainter extends CustomPainter {
  final double waveTime;
  final double particleTime;
  final double meshTime;
  final double level;
  final bool isActive;

  // Cache paint objects (avoid recreating per frame)
  final Paint meshPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint particlePaint = Paint()..style = PaintingStyle.fill;

  Optimized3DMeshPainter({
    required this.waveTime,
    required this.particleTime,
    required this.meshTime,
    required this.level,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    _draw3DMesh(canvas, size, center);

    if (isActive) {
      _drawParticles(canvas, center);
    }
  }

  void _draw3DMesh(Canvas canvas, Size size, Offset center) {
    const gridSize = 10; // reduced from 15
    const layers = 2; // reduced from 3

    for (int layer = 0; layer < layers; layer++) {
      final layerDepth = layer / layers;
      final layerScale = 0.6 + layerDepth * 0.4 + level * 0.2;
      final layerOpacity = 0.8 - layerDepth * 0.3;

      final points = <List<Offset>>[];

      for (int i = 0; i <= gridSize; i++) {
        final row = <Offset>[];
        for (int j = 0; j <= gridSize; j++) {
          final x = (i / gridSize - 0.5) * 180 * layerScale;
          final y = (j / gridSize - 0.5) * 180 * layerScale;

          final waveX =
              math.sin((i + j) * 0.3 + meshTime * 2 * math.pi) * 10 * level;
          final waveY =
              math.cos((i - j) * 0.4 + meshTime * 1.5 * math.pi) * 8 * level;
          final waveZ =
              math.sin(i * 0.2 + j * 0.3 + meshTime * math.pi) * 6 * level;

          final projectedX = center.dx + x + waveX + waveZ * 0.4;
          final projectedY = center.dy + y + waveY + waveZ * 0.25;

          row.add(Offset(projectedX, projectedY));
        }
        points.add(row);
      }

      final baseOpacity = layerOpacity * (0.4 + level * 0.6);

      // Horizontal lines
      for (int i = 0; i < points.length; i++) {
        final path = Path()..addPolygon(points[i], false);

        final hue = (meshTime * 25 + layer * 50 + i * 4) % 360;
        meshPaint.color = HSVColor.fromAHSV(
          baseOpacity,
          hue,
          0.6 + level * 0.3,
          0.8,
        ).toColor();

        canvas.drawPath(path, meshPaint);
      }

      // Vertical lines
      for (int j = 0; j <= gridSize; j++) {
        final path = Path();
        for (int i = 0; i < points.length; i++) {
          if (i == 0) {
            path.moveTo(points[i][j].dx, points[i][j].dy);
          } else {
            path.lineTo(points[i][j].dx, points[i][j].dy);
          }
        }

        final hue = (meshTime * 25 + j * 6 + layer * 50 + 120) % 360;
        meshPaint.color = HSVColor.fromAHSV(
          baseOpacity,
          hue,
          0.6 + level * 0.4,
          0.7,
        ).toColor();

        canvas.drawPath(path, meshPaint);
      }
    }
  }

  void _drawParticles(Canvas canvas, Offset center) {
    const particleCount = 12; // reduced from 20
    const trailLength = 3; // reduced from 5

    final colors = [
      const Color(0xFFd4145a), // Pink
      const Color(0xFF662d8c), // Purple
      const Color(0xFFfbb03b), // Yellow
    ];

    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi + particleTime * math.pi;
      final distance =
          70 + math.sin(particleTime * 2 * math.pi + i) * 30 * level;

      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      final particleOpacity = (0.3 + level * 0.5);

      particlePaint.color = colors[i % 3].withOpacity(particleOpacity);
      canvas.drawCircle(Offset(x, y), 2 + level * 3, particlePaint);

      // Shorter trail
      for (int t = 1; t <= trailLength; t++) {
        final trailAngle = angle - (t * 0.12);
        final trailX = center.dx + math.cos(trailAngle) * distance;
        final trailY = center.dy + math.sin(trailAngle) * distance;

        particlePaint.color = colors[i % 3].withOpacity(
          particleOpacity * (1 - t / trailLength),
        );
        canvas.drawCircle(
          Offset(trailX, trailY),
          (2 + level * 3) * (1 - t / trailLength * 0.6),
          particlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant Optimized3DMeshPainter oldDelegate) =>
      oldDelegate.waveTime != waveTime ||
      oldDelegate.particleTime != particleTime ||
      oldDelegate.meshTime != meshTime ||
      oldDelegate.level != level ||
      oldDelegate.isActive != isActive;
}
