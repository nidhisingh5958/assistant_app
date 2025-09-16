import 'package:flutter/material.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';

class DetectionOverlay extends StatefulWidget {
  final List<Detection> detections;
  final Size imageSize;
  final Size previewSize;

  const DetectionOverlay({
    Key? key,
    required this.detections,
    required this.imageSize,
    required this.previewSize,
  }) : super(key: key);

  @override
  _DetectionOverlayState createState() => _DetectionOverlayState();
}

class _DetectionOverlayState extends State<DetectionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(DetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detections.length != oldWidget.detections.length) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DetectionPainter(
        detections: widget.detections,
        imageSize: widget.imageSize,
        previewSize: widget.previewSize,
        animationValue: _scaleAnimation.value,
      ),
      size: Size.infinite,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final Size previewSize;
  final double animationValue;

  DetectionPainter({
    required this.detections,
    required this.imageSize,
    required this.previewSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    // Calculate scale factors
    final scaleX = previewSize.width / imageSize.width;
    final scaleY = previewSize.height / imageSize.height;

    for (final detection in detections) {
      _drawDetection(canvas, detection, scaleX, scaleY);
    }
  }

  void _drawDetection(
    Canvas canvas,
    Detection detection,
    double scaleX,
    double scaleY,
  ) {
    // Scale bounding box to preview size
    final scaledBox = Rect.fromLTWH(
      detection.boundingBox.left * scaleX,
      detection.boundingBox.top * scaleY,
      detection.boundingBox.width * scaleX,
      detection.boundingBox.height * scaleY,
    );

    // Apply animation scaling
    final center = scaledBox.center;
    final animatedBox = Rect.fromCenter(
      center: center,
      width: scaledBox.width * animationValue,
      height: scaledBox.height * animationValue,
    );

    // Draw bounding box
    final boxPaint = Paint()
      ..color = _getDetectionColor(detection)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(animatedBox, boxPaint);

    // Draw filled corner indicators
    final cornerSize = 12.0;
    final cornerPaint = Paint()
      ..color = _getDetectionColor(detection)
      ..style = PaintingStyle.fill;

    // Top-left corner
    canvas.drawRect(
      Rect.fromLTWH(animatedBox.left, animatedBox.top, cornerSize, 3),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(animatedBox.left, animatedBox.top, 3, cornerSize),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawRect(
      Rect.fromLTWH(
        animatedBox.right - cornerSize,
        animatedBox.top,
        cornerSize,
        3,
      ),
      cornerPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(animatedBox.right - 3, animatedBox.top, 3, cornerSize),
      cornerPaint,
    );

    // Draw label background
    final confidencePercent = (detection.confidence * 100);
    final safePercent = confidencePercent.isFinite
        ? confidencePercent.toInt()
        : 0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${detection.className} ${safePercent}%',
        style: TextStyle(color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      animatedBox.left,
      animatedBox.top - textPainter.height - 8,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    final labelPaint = Paint()
      ..color = _getDetectionColor(detection).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final confidencePaint = Paint()
      ..color = _getDetectionColor(detection).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Draw label text
    textPainter.paint(
      canvas,
      Offset(animatedBox.left + 8, animatedBox.top - textPainter.height - 4),
    );

    // Draw confidence indicator
    final confidenceWidth = (animatedBox.width * detection.confidence).clamp(
      0.0,
      animatedBox.width,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        animatedBox.left,
        animatedBox.bottom - 4,
        confidenceWidth,
        4,
      ),
      confidencePaint,
    );
  }

  Color _getDetectionColor(Detection detection) {
    // Generate color based on class name hash for consistency
    final hash = detection.className.hashCode;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
