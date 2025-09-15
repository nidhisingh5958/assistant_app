import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class ActionDetector {
  static const String ACTION_MODEL_PATH = 'assets/models/action_model.onnx';
  static const String ACTION_MODEL_QUANTISED_PATH =
      'assets/models/action_model_quantised.onnx';
  static const String LABELS_PATH = 'assets/labels/action_labels.txt';

  // Model configurations for action detection
  static const int INPUT_WIDTH = 112;
  static const int INPUT_HEIGHT = 112;
  static const int SEQUENCE_LENGTH = 16;
  static const double CONFIDENCE_THRESHOLD = 0.6;
  static const int NUM_CLASSES =
      400; // Kinetics-400 dataset has 400 action classes

  List<String> _actionLabels = [];
  bool _isInitialized = false;
  bool _useQuantisedModel = false;

  // ONNX Runtime components
  OrtSession? _session;
  late List<String> _inputNames;
  late List<List<int>> _inputShapes;
  late List<String> _outputNames;
  late List<List<int>> _outputShapes;

  // Frame buffer for temporal action detection
  List<img.Image> _frameBuffer = [];
  List<Float32List> _processedFrames = [];

  bool get isInitialized => _isInitialized;
  List<String> get actionLabels => _actionLabels;

  Future<void> initialize({bool useQuantisedModel = false}) async {
    _useQuantisedModel = useQuantisedModel;

    try {
      print('Starting action detector initialization...');

      // Load action labels first
      await _loadActionLabels();
      print('Action labels loaded: ${_actionLabels.length}');

      // Load ONNX model
      await _loadOnnxModel();
      print('Action detection ONNX model loaded successfully');

      _isInitialized = true;
      print('Action detection model initialized successfully');
      print(
        'Using ${_useQuantisedModel ? 'quantised' : 'full precision'} model',
      );
      print('Loaded ${_actionLabels.length} action classes');
      print('Model expects sequence of ${SEQUENCE_LENGTH} frames');
    } catch (e) {
      print('Error initializing action detector: $e');
      _isInitialized = false;
      rethrow;
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
      print('Using fallback Kinetics-400 action labels');
      // Fallback to common Kinetics-400 action labels
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
        'playing',
        'swimming',
        'cycling',
        'driving',
        'laughing',
        'crying',
        'hugging',
        'kissing',
        'shaking hands',
        'applauding',
        'stretching',
        'yawning',
        'pointing',
        'nodding',
        'shaking head',
        'looking',
        'listening',
        'thinking',
        'working',
        'studying',
        'teaching',
        'cleaning',
        'washing',
        'dressing',
        'undressing',
      ];
    }
  }

  Future<void> _loadOnnxModel() async {
    try {
      final modelPath = _useQuantisedModel
          ? ACTION_MODEL_QUANTISED_PATH
          : ACTION_MODEL_PATH;

      final modelAsset = await rootBundle.load(modelPath);
      final modelBytes = modelAsset.buffer.asUint8List();

      // Create ONNX session
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      // Get model metadata
      _inputNames = _session!.inputNames;
      _outputNames = _session!.outputNames;

      print('Model inputs: $_inputNames');
      print('Model outputs: $_outputNames');
    } catch (e) {
      print('Failed to load ONNX model: $e');
      throw Exception('Failed to load action detection model: $e');
    }
  }

  List<ActionDetection> detectActions(img.Image frame) {
    if (!_isInitialized || _session == null) {
      return [];
    }

    try {
      // Preprocess and add frame to buffer
      final preprocessedFrame = _preprocessFrame(frame);
      _processedFrames.add(preprocessedFrame);

      // Keep only the required number of frames
      if (_processedFrames.length > SEQUENCE_LENGTH) {
        _processedFrames.removeAt(0);
      }
      if (_frameBuffer.length >= SEQUENCE_LENGTH) {
        _frameBuffer.removeAt(0);
      }
      _frameBuffer.add(frame);

      // Need minimum frames for action detection
      if (_processedFrames.length < SEQUENCE_LENGTH) {
        return [];
      }

      // Prepare input tensor: [1, sequence_length, channels, height, width]
      final inputData = _prepareSequenceInput();

      // Create input tensor
      final inputShape = [1, SEQUENCE_LENGTH, 3, INPUT_HEIGHT, INPUT_WIDTH];
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        inputShape,
      );

      // Prepare inputs map
      final inputs = <String, OrtValue>{_inputNames[0]: inputTensor};

      // Run inference
      final stopwatch = Stopwatch()..start();
      final outputs = _session!.run(OrtRunOptions(), inputs);
      stopwatch.stop();

      print('Action inference time: ${stopwatch.elapsedMilliseconds}ms');

      // Process outputs
      final detections = _processOutputs(outputs);

      // Clean up tensors
      inputTensor.release();
      for (final output in outputs) {
        output?.release();
      }

      return detections;
    } catch (e) {
      print('Error during action detection: $e');
      return [];
    }
  }

  Float32List _preprocessFrame(img.Image frame) {
    final resizedFrame = img.copyResize(
      frame,
      width: INPUT_WIDTH, // Now 112
      height: INPUT_HEIGHT, // Now 112
    );

    final frameData = Float32List(3 * INPUT_HEIGHT * INPUT_WIDTH);
    int index = 0;

    // ImageNet normalization
    final means = [0.485, 0.456, 0.406];
    final stds = [0.229, 0.224, 0.225];

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < INPUT_HEIGHT; y++) {
        for (int x = 0; x < INPUT_WIDTH; x++) {
          final pixel = resizedFrame.getPixel(x, y);
          final normalizedValue = switch (c) {
            0 => (pixel.r / 255.0 - means[0]) / stds[0],
            1 => (pixel.g / 255.0 - means[1]) / stds[1],
            2 => (pixel.b / 255.0 - means[2]) / stds[2],
            _ => 0.0,
          };
          frameData[index++] = normalizedValue;
        }
      }
    }

    return frameData;
  }

  Float32List _prepareSequenceInput() {
    final totalSize = SEQUENCE_LENGTH * 3 * INPUT_HEIGHT * INPUT_WIDTH;
    final sequenceData = Float32List(totalSize);

    int globalIndex = 0;
    for (int frameIdx = 0; frameIdx < SEQUENCE_LENGTH; frameIdx++) {
      final frameData = _processedFrames[frameIdx];
      for (int i = 0; i < frameData.length; i++) {
        sequenceData[globalIndex++] = frameData[i];
      }
    }

    return sequenceData;
  }

  List<ActionDetection> _processOutputs(List<OrtValue?> outputs) {
    final detections = <ActionDetection>[];

    try {
      if (outputs.isEmpty || outputs[0] == null) {
        return detections;
      }

      final outputTensor = outputs[0] as OrtValueTensor;
      final predictions = outputTensor.value as List<double>;

      // Apply softmax to get probabilities
      final probabilities = _applySoftmax(predictions);

      // Find top-k predictions
      final topK = _getTopKPredictions(probabilities, k: 5);

      for (final prediction in topK) {
        final actionId = prediction['index'] as int;
        final confidence = prediction['confidence'] as double;

        if (confidence >= CONFIDENCE_THRESHOLD &&
            actionId < _actionLabels.length) {
          detections.add(
            ActionDetection(
              actionId: actionId,
              actionName: _actionLabels[actionId],
              confidence: confidence,
              timestamp: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      print('Error processing action detection outputs: $e');
    }

    return detections;
  }

  List<double> _applySoftmax(List<double> logits) {
    // Find max for numerical stability
    final maxLogit = logits.reduce(math.max);

    // Compute exponentials
    final expLogits = logits.map((x) => math.exp(x - maxLogit)).toList();

    // Compute sum
    final sumExp = expLogits.reduce((a, b) => a + b);

    // Normalize
    return expLogits.map((x) => x / sumExp).toList();
  }

  List<Map<String, dynamic>> _getTopKPredictions(
    List<double> probabilities, {
    int k = 5,
  }) {
    final predictions = <Map<String, dynamic>>[];

    for (int i = 0; i < probabilities.length; i++) {
      predictions.add({'index': i, 'confidence': probabilities[i]});
    }

    // Sort by confidence descending
    predictions.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    return predictions.take(k).toList();
  }

  void clearFrameBuffer() {
    _frameBuffer.clear();
    _processedFrames.clear();
  }

  void dispose() {
    _frameBuffer.clear();
    _processedFrames.clear();
    _session?.release();
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
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.lime,
      Colors.deepPurple,
      Colors.brown,
    ];
    return colors[actionId % colors.length];
  }

  @override
  String toString() {
    return 'ActionDetection{actionName: $actionName, confidence: ${confidence.toStringAsFixed(3)}, timestamp: $timestamp}';
  }
}
