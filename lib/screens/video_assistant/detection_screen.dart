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

class ActionDetection {
  final int actionId;
  final String actionName;
  final double confidence;
  final DateTime timestamp;
  final Color color;

  ActionDetection({
    required this.actionId,
    required this.actionName,
    required this.confidence,
    required this.timestamp,
    Color? color,
  }) : color = color ?? _getColorForAction(actionId);

  static Color _getColorForAction(int actionId) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
    ];
    return colors[actionId % colors.length];
  }

  @override
  String toString() {
    return 'ActionDetection{actionName: $actionName, confidence: ${confidence.toStringAsFixed(2)}, timestamp: $timestamp}';
  }
}

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

  List<String> get uniqueActions =>
      actionDetections.map((a) => a.actionName).toSet().toList();

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
    return actionDetections
        .where((action) => action.confidence >= threshold)
        .toList();
  }

  @override
  String toString() {
    return 'DetectionResult{objects: ${detections.length}, actions: ${actionDetections.length}, processingTime: ${processingTime.inMilliseconds}ms}';
  }
}
