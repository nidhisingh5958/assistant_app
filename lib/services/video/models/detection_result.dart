import 'package:flutter/material.dart';

class Detection {
  final int classId;
  final String className;
  final double confidence;
  final Rect boundingBox;
  final Color color;

  Detection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.boundingBox,
    Color? color,
  }) : color = color ?? _getColorForClass(classId);

  static Color _getColorForClass(int classId) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.pink,
    ];
    return colors[classId % colors.length];
  }

  @override
  String toString() {
    return 'Detection{className: $className, confidence: ${confidence.toStringAsFixed(2)}, bbox: $boundingBox}';
  }
}

class DetectionResult {
  final List<Detection> detections;
  final Duration processingTime;
  final Size imageSize;
  final DateTime timestamp;

  DetectionResult({
    required this.detections,
    required this.processingTime,
    required this.imageSize,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get detectionCount => detections.length;

  List<String> get uniqueClasses =>
      detections.map((d) => d.className).toSet().toList();
}
