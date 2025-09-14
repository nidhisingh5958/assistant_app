import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:image/image.dart' as img;

// Simplified version without ONNX dependency for troubleshooting
class ActionDetector {
  static const String LABELS_PATH = 'assets/labels/action_labels.txt';

  // Model configurations for action detection
  static const int INPUT_WIDTH = 224;
  static const int INPUT_HEIGHT = 224;
  static const int SEQUENCE_LENGTH = 8; // Reduced for testing
  static const double CONFIDENCE_THRESHOLD = 0.5;

  List<String> _actionLabels = [];
  bool _isInitialized = false;
  bool _useQuantisedModel = false;

  // Frame buffer for temporal action detection
  List<img.Image> _frameBuffer = [];

  // Mock detection for testing
  bool _enableMockDetection = true;
  int _mockDetectionCounter = 0;

  bool get isInitialized => _isInitialized;
  List<String> get actionLabels => _actionLabels;

  Future<void> initialize({bool useQuantisedModel = false}) async {
    _useQuantisedModel = useQuantisedModel;

    try {
      print('Starting action detector initialization...');

      // Load action labels first
      await _loadActionLabels();
      print('Action labels loaded: ${_actionLabels.length}');

      // For now, just use mock detection to test the UI
      // Later we can add ONNX model loading
      _enableMockDetection = true;

      _isInitialized = true;
      print('Action detection model initialized successfully (mock mode)');
      print(
        'Using ${_useQuantisedModel ? 'quantised' : 'full precision'} model (simulated)',
      );
      print('Loaded ${_actionLabels.length} action classes');
    } catch (e) {
      print('Error initializing action detector: $e');
      _isInitialized = false;
      rethrow; // Re-throw to let caller handle the error
    }
  }

  Future<void> _loadActionLabels() async {
    try {
      final labelsData = await rootBundle.loadString(LABELS_PATH);
      _actionLabels = labelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
      print('Loaded ${_actionLabels.length} action labels from file');
    } catch (e) {
      print('Error loading action labels from file: $e');
      print('Using fallback action labels');
      // Fallback action labels for common human actions
      _actionLabels = [
        'walking',
        'running',
        'sitting',
        'standing',
        'jumping',
        'waving',
        'clapping',
        'dancing',
        'eating',
        'drinking',
        'reading',
        'writing',
        'talking',
        'sleeping',
        'exercising',
        'cooking',
      ];
    }
  }

  List<ActionDetection> detectActions(img.Image frame) {
    if (!_isInitialized) {
      return [];
    }

    try {
      // Add frame to buffer
      _frameBuffer.add(frame);

      // Keep only the required number of frames
      if (_frameBuffer.length > SEQUENCE_LENGTH) {
        _frameBuffer.removeAt(0);
      }

      // Need minimum frames for action detection
      if (_frameBuffer.length < SEQUENCE_LENGTH) {
        return [];
      }

      // For testing purposes, use mock detection
      if (_enableMockDetection) {
        return _generateMockDetections();
      }

      // TODO: Implement actual ONNX inference here
      return [];
    } catch (e) {
      print('Error during action detection: $e');
      return [];
    }
  }

  List<ActionDetection> _generateMockDetections() {
    _mockDetectionCounter++;

    // Generate mock detections every few frames
    if (_mockDetectionCounter % 30 != 0) {
      return [];
    }

    final random = math.Random();
    final detections = <ActionDetection>[];

    // Randomly generate 1-3 action detections
    final numDetections = 1 + random.nextInt(3);

    for (int i = 0; i < numDetections; i++) {
      final actionIndex = random.nextInt(_actionLabels.length);
      final confidence = 0.5 + random.nextDouble() * 0.4; // 0.5 to 0.9

      detections.add(
        ActionDetection(
          actionId: actionIndex,
          actionName: _actionLabels[actionIndex],
          confidence: confidence,
          timestamp: DateTime.now(),
        ),
      );
    }

    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    return detections;
  }

  void clearFrameBuffer() {
    _frameBuffer.clear();
    _mockDetectionCounter = 0;
  }

  void dispose() {
    _frameBuffer.clear();
    _isInitialized = false;
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
