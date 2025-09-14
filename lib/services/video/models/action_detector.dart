import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

class ActionDetector {
  static const String MODEL_PATH = 'assets/models/action_model.onnx';
  static const String QUANTISED_MODEL_PATH =
      'assets/models/action_model_quantised.onnx';
  static const String LABELS_PATH = 'assets/labels/action_labels.txt';

  // Model configurations for action detection
  static const int INPUT_WIDTH = 224;
  static const int INPUT_HEIGHT = 224;
  static const int SEQUENCE_LENGTH =
      16; // Number of frames for action detection
  static const double CONFIDENCE_THRESHOLD = 0.5;

  OrtSession? _session;
  List<String> _actionLabels = [];
  bool _isInitialized = false;
  bool _useQuantisedModel = false;

  // Frame buffer for temporal action detection
  List<img.Image> _frameBuffer = [];

  bool get isInitialized => _isInitialized;
  List<String> get actionLabels => _actionLabels;

  Future<void> initialize({bool useQuantisedModel = false}) async {
    _useQuantisedModel = useQuantisedModel;

    try {
      // Load the ONNX model
      final modelPath = _useQuantisedModel ? QUANTISED_MODEL_PATH : MODEL_PATH;
      final modelBytes = await rootBundle.load(modelPath);

      // Create ONNX Runtime session
      _session = OrtSession.fromBuffer(
        modelBytes.buffer.asUint8List(),
        OrtSessionOptions(),
      );

      // Load action labels
      await _loadActionLabels();

      _isInitialized = true;
      print('Action detection model initialized successfully');
      print(
        'Using ${_useQuantisedModel ? 'quantised' : 'full precision'} model',
      );
      print('Loaded ${_actionLabels.length} action classes');
    } catch (e) {
      print('Error initializing action detector: $e');
      _isInitialized = false;
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
      print('Loaded ${_actionLabels.length} action labels');
    } catch (e) {
      print('Error loading action labels: $e');
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
    if (!_isInitialized || _session == null) {
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

      // Preprocess frame sequence
      final inputTensor = _preprocessFrameSequence(_frameBuffer);

      // Create input for ONNX model
      final inputs = {
        'input': OrtValueTensor.createTensorWithDataList(inputTensor, [
          1,
          SEQUENCE_LENGTH,
          INPUT_HEIGHT,
          INPUT_WIDTH,
          3,
        ]),
      };

      // Run inference
      final stopwatch = Stopwatch()..start();
      final outputs = _session!.run(OrtRunOptions(), inputs);
      stopwatch.stop();

      print('Action inference time: ${stopwatch.elapsedMilliseconds}ms');

      // Process outputs
      final actionDetections = _processActionOutputs({
        'output': outputs.first!,
      });

      // Clean up
      for (final input in inputs.values) {
        input.release();
      }
      for (final output in outputs) {
        output?.release();
      }

      return actionDetections;
    } catch (e) {
      print('Error during action detection: $e');
      return [];
    }
  }

  List<List<List<List<double>>>> _preprocessFrameSequence(
    List<img.Image> frames,
  ) {
    final processedSequence = <List<List<List<double>>>>[];

    for (final frame in frames) {
      // Resize frame to model input size
      final resizedFrame = img.copyResize(
        frame,
        width: INPUT_WIDTH,
        height: INPUT_HEIGHT,
      );

      // Convert to normalized RGB values
      final frameData = <List<List<double>>>[];

      for (int y = 0; y < INPUT_HEIGHT; y++) {
        final row = <List<double>>[];
        for (int x = 0; x < INPUT_WIDTH; x++) {
          final pixel = resizedFrame.getPixel(x, y);

          // Normalize pixel values to [0, 1]
          row.add([pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0]);
        }
        frameData.add(row);
      }

      processedSequence.add(frameData);
    }

    return processedSequence;
  }

  List<ActionDetection> _processActionOutputs(Map<String, OrtValue> outputs) {
    final actionDetections = <ActionDetection>[];

    try {
      // Get action probabilities (adjust key based on your model)
      final outputData =
          (outputs['output'] ?? outputs.values.first) as OrtValueTensor;
      final probabilities = outputData.value as List<double>;

      // Find actions above confidence threshold
      for (
        int i = 0;
        i < probabilities.length && i < _actionLabels.length;
        i++
      ) {
        final confidence = probabilities[i];

        if (confidence > CONFIDENCE_THRESHOLD) {
          actionDetections.add(
            ActionDetection(
              actionId: i,
              actionName: _actionLabels[i],
              confidence: confidence,
              timestamp: DateTime.now(),
            ),
          );
        }
      }

      // Sort by confidence
      actionDetections.sort((a, b) => b.confidence.compareTo(a.confidence));
    } catch (e) {
      print('Error processing action outputs: $e');
    }

    return actionDetections;
  }

  void clearFrameBuffer() {
    _frameBuffer.clear();
  }

  void dispose() {
    _session?.release();
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
