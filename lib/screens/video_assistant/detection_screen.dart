import 'package:flutter/material.dart';
import 'package:listen_iq/services/video/models/action_detector.dart';

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

// Use ActionDetection from action_detector.dart

class DetectionResult {
  final List<Detection> detections;
  final List<ActionDetection> actionDetections;
  final Duration processingTime;
  final Size imageSize;
  final DateTime timestamp;
  final Duration? inferenceTime;

  DetectionResult({
    required this.detections,
    this.actionDetections = const [],
    required this.processingTime,
    required this.imageSize,
    DateTime? timestamp,
    this.inferenceTime,
  }) : timestamp = timestamp ?? DateTime.now();

  int get detectionCount => detections.length;
  int get actionCount => actionDetections.length;
  int get totalDetectionCount => detectionCount + actionCount;

  List<String> get uniqueClasses =>
      detections.map((d) => d.className).toSet().toList();

  List<String> get uniqueActions => actionDetections
      .map((a) => a.actionName)
      .whereType<String>()
      .toSet()
      .toList();

  bool get hasDetections =>
      detections.isNotEmpty || actionDetections.isNotEmpty;

  // Get the most confident action detection
  ActionDetection? get primaryAction {
    if (actionDetections.isEmpty) return null;
    return actionDetections.reduce(
      (a, b) => a.confidence > b.confidence ? a : b,
    );
  }

  // Get actions above a confidence threshold
  List<ActionDetection> getActionsAboveThreshold(double threshold) {
    // Use ActionDetection from action_detector.dart
    return actionDetections
        .where((action) => action.confidence >= threshold)
        .toList();
  }
}
