import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MicWaves extends StatefulWidget {
  const MicWaves({
    Key? key,
    required this.levelStream,
    this.size = 160,
    this.ringCount = 4,
  }) : super(key: key);

  final Stream<double> levelStream; // 0..1
  final double size;
  final int ringCount;

  @override
  State<MicWaves> createState() => _MicWavesState();
}

class _MicWavesState extends State<MicWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _level = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    widget.levelStream.listen((v) {
      setState(() => _level = v); // Throttled by the stream interval (60ms)
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(
            painter: _RadialWavesPainter(
              t: _ctrl.value, // 0..1 time phase
              level: _level, // 0..1 intensity
              ringCount: widget.ringCount,
            ),
            child: Center(
              child: Container(
                width: widget.size * 0.35,
                height: widget.size * 0.35,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 36),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RadialWavesPainter extends CustomPainter {
  _RadialWavesPainter({
    required this.t,
    required this.level,
    required this.ringCount,
  });

  final double t; // animation phase [0..1]
  final double level; // normalized intensity [0..1]
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.48;

    final baseStroke = ui.lerpDouble(2, 4, level) ?? 3;
    final baseAlpha = ui.lerpDouble(50, 160, level)!.toInt();

    for (int i = 1; i <= ringCount; i++) {
      // Each ring gets a small phase offset for a ripple effect
      final phase = (t + i * 0.17) % 1.0;

      // Amplitude scales with level; also expand/shrink subtly with phase
      final amp = (level * 0.35 + 0.05); // radial growth factor
      final radius =
          maxR * (i / ringCount) * (1.0 + amp * (0.6 * (1.0 - phase)));

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseStroke
        ..color = Colors.blue.withAlpha(
          (baseAlpha * (1 - i / (ringCount + 0.5))).toInt(),
        );

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RadialWavesPainter old) =>
      old.t != t || old.level != level || old.ringCount != ringCount;
}
