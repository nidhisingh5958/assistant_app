// lib/models/detection_result.dart
import 'package:flutter/material.dart';

class Detection {
  final int classId;
  final String className;
  final double confidence;
  final Rect boundingBox;

  Detection({
    required this.classId,
    this.className = '',
    required this.confidence,
    required this.boundingBox,
  });
}

class DetectionResult {
  final List<Detection> detections;
  final Duration inferenceTime;
  final Size imageSize;

  DetectionResult({
    required this.detections,
    required this.inferenceTime,
    required this.imageSize,
    required Duration processingTime,
  });
}
