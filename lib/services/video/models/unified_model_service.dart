import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:listen_iq/services/video/models/action_detector.dart';

class UnifiedVideoAnalysisService {
  // Model paths
  static const String OBJECT_MODEL_PATH = 'assets/models/yolov8s-oiv7.onnx';
  static const String ACTION_MODEL_PATH = 'assets/models/action_model.onnx';
  static const String ACTION_MODEL_QUANTISED_PATH =
      'assets/models/action_model_quantised.onnx';

  // Label paths
  static const String OBJECT_LABELS_PATH = 'assets/labels/oiv7_labels.txt';
  static const String ACTION_LABELS_PATH = 'assets/labels/action_labels.txt';

  // Model sessions - prioritize object detection
  OrtSession? _objectSession;
  OrtSession? _actionSession;

  // Model metadata
  late List<String> _objectInputNames;
  late List<String> _actionInputNames;

  // Labels
  List<String> _objectLabels = [];
  List<String> _actionLabels = [];

  // State
  bool _isInitialized = false;
  bool _objectModelReady = false;
  bool _actionModelReady = false;
  bool _useQuantisedAction = true;

  // Optimized frame buffers
  List<Float32List> _processedFrames = [];

  // Performance tracking
  int _frameProcessingCount = 0;
  DateTime _lastActionProcessTime = DateTime.now();

  // Configuration - Optimized for performance
  static const int SEQUENCE_LENGTH = 8; // Reduced from 16
  static const int OBJECT_INPUT_SIZE = 320; // Reduced from 640
  static const int ACTION_INPUT_SIZE = 112; // Reduced from 224
  static const double OBJECT_CONFIDENCE_THRESHOLD = 0.4; // Reduced from 0.5
  static const double ACTION_CONFIDENCE_THRESHOLD = 0.5; // Reduced from 0.6
  static const Duration ACTION_PROCESS_INTERVAL = Duration(
    milliseconds: 500,
  ); // Process actions less frequently

  bool get isInitialized => _isInitialized;
  bool get objectModelReady => _objectModelReady;
  bool get actionModelReady => _actionModelReady;
  List<String> get objectLabels => _objectLabels;
  List<String> get actionLabels => _actionLabels;

  // Processing queue with strict limits
  bool _isProcessing = false;
  static const int MAX_CONCURRENT_PROCESSES = 1;

  Future<void> initialize({bool useQuantisedAction = true}) async {
    _useQuantisedAction = useQuantisedAction;

    try {
      print(
        '🚀 Starting optimized unified video analysis service initialization...',
      );

      // Step 1: Load labels first (fastest)
      await _loadLabels();
      print(
        '✅ Labels loaded - Objects: ${_objectLabels.length}, Actions: ${_actionLabels.length}',
      );

      // Step 2: Initialize object detection model (priority)
      try {
        await _initializeObjectModel();
        _objectModelReady = true;
        print('✅ Object detection model ready');
      } catch (e) {
        print('❌ Object model failed: $e');
        // Continue without object detection
      }

      // Step 3: Initialize action model (optional)
      try {
        await _initializeActionModel();
        _actionModelReady = true;
        print('✅ Action recognition model ready');
      } catch (e) {
        print('⚠️ Action model failed, continuing without actions: $e');
        // Continue without action detection
      }

      // Service is ready if at least object detection works
      _isInitialized = _objectModelReady;

      if (_isInitialized) {
        print('✅ Unified video analysis service initialized successfully');
        print(
          '📊 Available features: Objects=${_objectModelReady}, Actions=${_actionModelReady}',
        );
      } else {
        throw Exception('Failed to initialize any detection models');
      }
    } catch (e) {
      print('❌ Error initializing unified service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _loadLabels() async {
    // Load object labels with fallback
    try {
      final objectLabelsData = await rootBundle.loadString(OBJECT_LABELS_PATH);
      _objectLabels = objectLabelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
      print('📋 Loaded ${_objectLabels.length} object labels from file');
    } catch (e) {
      print('⚠️ Using fallback object labels: $e');
      _objectLabels = _getFallbackObjectLabels();
    }

    // Load action labels with fallback
    try {
      final actionLabelsData = await rootBundle.loadString(ACTION_LABELS_PATH);
      _actionLabels = actionLabelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
      print('📋 Loaded ${_actionLabels.length} action labels from file');
    } catch (e) {
      print('⚠️ Using fallback action labels: $e');
      _actionLabels = _getFallbackActionLabels();
    }
  }

  Future<void> _initializeObjectModel() async {
    print('🔧 Loading object detection model...');

    final modelAsset = await rootBundle.load(OBJECT_MODEL_PATH);
    final modelBytes = modelAsset.buffer.asUint8List();

    // Optimized session options for object detection
    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(2)
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableBasic,
      ); // Reduced optimization

    _objectSession = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _objectInputNames = _objectSession!.inputNames;

    print('📝 Object model input names: $_objectInputNames');
  }

  Future<void> _initializeActionModel() async {
    print('🔧 Loading action recognition model...');

    String modelPath = ACTION_MODEL_PATH;

    // Try quantized model first for better performance
    if (_useQuantisedAction) {
      try {
        await rootBundle.load(ACTION_MODEL_QUANTISED_PATH);
        modelPath = ACTION_MODEL_QUANTISED_PATH;
        print('📦 Using quantized action model');
      } catch (e) {
        print('⚠️ Quantized model not found, using regular model');
        modelPath = ACTION_MODEL_PATH;
        _useQuantisedAction = false;
      }
    }

    final modelAsset = await rootBundle.load(modelPath);
    final modelBytes = modelAsset.buffer.asUint8List();

    // Lighter session options for action model
    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortDisableAll,
      ); // Minimal optimization for speed

    _actionSession = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _actionInputNames = _actionSession!.inputNames;

    print('📝 Action model input names: $_actionInputNames');
  }

  Future<UnifiedAnalysisResult?> analyzeFrame(
    img.Image frame,
    img.Image resizedForAction,
  ) async {
    if (!_isInitialized) {
      return null;
    }

    // Prevent concurrent processing
    if (_isProcessing) {
      print('⚠️ Already processing, skipping frame');
      return null;
    }

    _isProcessing = true;

    try {
      final stopwatch = Stopwatch()..start();

      // Object Detection
      List<Detection> objectDetections = [];
      if (_objectModelReady) {
        try {
          objectDetections = await _runObjectDetection(frame).timeout(
            Duration(milliseconds: 200),
            onTimeout: () {
              print('⚠️ Object detection timeout');
              return <Detection>[];
            },
          );
        } catch (e) {
          print('❌ Object detection error: $e');
        }
      }

      // Validate objectDetections for nulls and type
      // Dart's type system ensures non-null elements in List<Detection>

      // Action Detection
      List<ActionDetection> actionDetections = [];
      if (_actionModelReady && _shouldProcessActions()) {
        try {
          _addFrameToBuffer(resizedForAction);
          if (_processedFrames.length >= SEQUENCE_LENGTH) {
            actionDetections = await _runActionDetection().timeout(
              Duration(milliseconds: 300),
              onTimeout: () {
                print('⚠️ Action detection timeout');
                return <ActionDetection>[];
              },
            );
          }
        } catch (e) {
          print('❌ Action detection error: $e');
        }
      }

      // Validate actionDetections for nulls and type
      // Dart's type system ensures non-null elements in List<ActionDetection>

      stopwatch.stop();

      print(
        '🎯 Detections - Objects: ${objectDetections.length}, Actions: ${actionDetections.length}, Time: ${stopwatch.elapsedMilliseconds}ms',
      );

      return UnifiedAnalysisResult(
        objectDetections: objectDetections,
        actionDetections: actionDetections,
        contextData: {}, // Skip context for performance
        processingTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error in frame analysis: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  bool _shouldProcessActions() {
    final now = DateTime.now();
    if (now.difference(_lastActionProcessTime) > ACTION_PROCESS_INTERVAL) {
      _lastActionProcessTime = now;
      return true;
    }
    return false;
  }

  Future<List<Detection>> _runObjectDetection(img.Image frame) async {
    if (_objectSession == null) return [];

    try {
      // Preprocess with optimized size
      final preprocessed = _preprocessForObject(frame);

      // Create input tensor
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        preprocessed['data'] as List<double>,
        [1, 3, OBJECT_INPUT_SIZE, OBJECT_INPUT_SIZE],
      );

      final inputs = <String, OrtValue>{_objectInputNames[0]: inputTensor};
      final outputs = _objectSession!.run(OrtRunOptions(), inputs);

      // Process outputs with original frame dimensions
      final detections = _processObjectOutputs(
        outputs,
        frame.width,
        frame.height,
        preprocessed,
      );

      // Cleanup
      inputTensor.release();
      for (final output in outputs) {
        output?.release();
      }

      return detections;
    } catch (e) {
      print('❌ Object detection error: $e');
      return [];
    }
  }

  Future<List<ActionDetection>> _runActionDetection() async {
    if (_actionSession == null || _processedFrames.length < SEQUENCE_LENGTH) {
      return [];
    }

    try {
      // Prepare sequence input
      final sequenceData = _prepareActionSequence();

      // Create input tensor
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        sequenceData,
        [1, SEQUENCE_LENGTH, 3, ACTION_INPUT_SIZE, ACTION_INPUT_SIZE],
      );

      final inputs = <String, OrtValue>{_actionInputNames[0]: inputTensor};
      final outputs = _actionSession!.run(OrtRunOptions(), inputs);

      // Process action outputs
      final actionDetections = _processActionOutputs(outputs);

      // Cleanup
      inputTensor.release();
      for (final output in outputs) {
        output?.release();
      }

      return actionDetections;
    } catch (e) {
      print('❌ Action detection error: $e');
      return [];
    }
  }

  void _addFrameToBuffer(img.Image frame) {
    // More aggressive buffer management
    if (_processedFrames.length >= SEQUENCE_LENGTH) {
      _processedFrames.removeAt(0);
    }

    final processedFrame = _preprocessForAction(frame);
    _processedFrames.add(processedFrame);
  }

  Map<String, dynamic> _preprocessForObject(img.Image image) {
    // Optimized YOLO preprocessing with smaller input size
    final scaleX = OBJECT_INPUT_SIZE / image.width;
    final scaleY = OBJECT_INPUT_SIZE / image.height;
    final scale = math.min(scaleX, scaleY);

    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();
    final padX = (OBJECT_INPUT_SIZE - newWidth) / 2;
    final padY = (OBJECT_INPUT_SIZE - newHeight) / 2;

    // Use faster interpolation
    final resizedImage = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.nearest,
    );

    final paddedImage = img.Image(
      width: OBJECT_INPUT_SIZE,
      height: OBJECT_INPUT_SIZE,
    );
    img.fill(paddedImage, color: img.ColorRgb8(114, 114, 114));

    img.compositeImage(
      paddedImage,
      resizedImage,
      dstX: padX.round(),
      dstY: padY.round(),
    );

    // Convert to CHW format - optimized
    final inputData = <double>[];
    inputData.length = 3 * OBJECT_INPUT_SIZE * OBJECT_INPUT_SIZE;

    int index = 0;
    // RGB channels
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < OBJECT_INPUT_SIZE; y++) {
        for (int x = 0; x < OBJECT_INPUT_SIZE; x++) {
          final pixel = paddedImage.getPixel(x, y);
          switch (c) {
            case 0:
              inputData[index++] = pixel.r / 255.0;
              break;
            case 1:
              inputData[index++] = pixel.g / 255.0;
              break;
            case 2:
              inputData[index++] = pixel.b / 255.0;
              break;
          }
        }
      }
    }

    return {'data': inputData, 'scale': scale, 'pad_x': padX, 'pad_y': padY};
  }

  Float32List _preprocessForAction(img.Image frame) {
    // Resize for action recognition with smaller input
    final resizedFrame = img.copyResize(
      frame,
      width: ACTION_INPUT_SIZE,
      height: ACTION_INPUT_SIZE,
      interpolation: img.Interpolation.nearest,
    );

    // Simplified normalization
    final frameData = Float32List(3 * ACTION_INPUT_SIZE * ACTION_INPUT_SIZE);
    int index = 0;

    // Basic normalization without ImageNet stats for speed
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < ACTION_INPUT_SIZE; y++) {
        for (int x = 0; x < ACTION_INPUT_SIZE; x++) {
          final pixel = resizedFrame.getPixel(x, y);
          double value;
          switch (c) {
            case 0:
              value = (pixel.r / 255.0 - 0.5) * 2.0; // Simple normalization
              break;
            case 1:
              value = (pixel.g / 255.0 - 0.5) * 2.0;
              break;
            case 2:
              value = (pixel.b / 255.0 - 0.5) * 2.0;
              break;
            default:
              value = 0.0;
          }
          frameData[index++] = value;
        }
      }
    }

    return frameData;
  }

  Float32List _prepareActionSequence() {
    final totalSize =
        SEQUENCE_LENGTH * 3 * ACTION_INPUT_SIZE * ACTION_INPUT_SIZE;
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

  List<Detection> _processObjectOutputs(
    List<OrtValue?> outputs,
    int originalWidth,
    int originalHeight,
    Map<String, dynamic> preprocessed,
  ) {
    final detections = <Detection>[];

    try {
      if (outputs.isEmpty || outputs[0] == null) {
        return detections;
      }

      final outputTensor = outputs[0] as OrtValueTensor;
      var predictionsRaw = outputTensor.value;
      // Handle nested output (List<List<double>>) or nulls
      List<double> predictions;
      if (predictionsRaw is List<double>) {
        predictions = predictionsRaw
            .where((v) => v != null && v is double && v.isFinite)
            .cast<double>()
            .toList();
      } else if (predictionsRaw is List<List<double>>) {
        predictions = predictionsRaw
            .expand((e) => e)
            .where((v) => v != null && v is double && v.isFinite)
            .cast<double>()
            .toList();
      } else {
        print(
          '❌ Object detection error: output tensor is not List<double> or List<List<double>>',
        );
        return detections;
      }

      // Remove nulls and NaNs
      predictions = predictions.where((v) => v.isFinite).toList();

      // Parse output dimensions
      final numPredictions = predictions.length > 0
          ? (predictions.length / (_objectLabels.length + 5)).floor()
          : 0;
      final stride = _objectLabels.length + 5;
      final numClasses = stride > 4 ? stride - 5 : _objectLabels.length;

      final scale = preprocessed['scale'] as double;
      final padX = preprocessed['pad_x'] as double;
      final padY = preprocessed['pad_y'] as double;

      for (int i = 0; i < numPredictions; i++) {
        final baseIndex = i * stride;

        // Extract box coordinates
        final centerX = predictions[baseIndex] * OBJECT_INPUT_SIZE.toDouble();
        final centerY =
            predictions[baseIndex + 1] * OBJECT_INPUT_SIZE.toDouble();
        final width = predictions[baseIndex + 2] * OBJECT_INPUT_SIZE.toDouble();
        final height =
            predictions[baseIndex + 3] * OBJECT_INPUT_SIZE.toDouble();

        // Find best class
        double maxConfidence = 0.0;
        int bestClassId = 0;

        for (int classId = 0; classId < numClasses; classId++) {
          final index = baseIndex + 4 + classId;
          if (index < predictions.length) {
            final confidence = predictions[index];
            if (confidence > maxConfidence) {
              maxConfidence = confidence;
              bestClassId = classId;
            }
          }
        }

        // Filter by confidence
        if (maxConfidence >= OBJECT_CONFIDENCE_THRESHOLD) {
          // Convert coordinates
          final x1 = centerX - width / 2;
          final y1 = centerY - height / 2;
          final x2 = centerX + width / 2;
          final y2 = centerY + height / 2;

          // Adjust to original image space
          final adjustedX1 = ((x1 - padX) / scale).clamp(
            0.0,
            originalWidth.toDouble(),
          );
          final adjustedY1 = ((y1 - padY) / scale).clamp(
            0.0,
            originalHeight.toDouble(),
          );
          final adjustedX2 = ((x2 - padX) / scale).clamp(
            0.0,
            originalWidth.toDouble(),
          );
          final adjustedY2 = ((y2 - padY) / scale).clamp(
            0.0,
            originalHeight.toDouble(),
          );

          if (adjustedX2 > adjustedX1 && adjustedY2 > adjustedY1) {
            final className = bestClassId < _objectLabels.length
                ? _objectLabels[bestClassId]
                : 'Unknown';

            detections.add(
              Detection(
                classId: bestClassId,
                className: className,
                confidence: maxConfidence,
                boundingBox: Rect.fromLTRB(
                  adjustedX1,
                  adjustedY1,
                  adjustedX2,
                  adjustedY2,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error processing object detection outputs: $e');
    }

    return _applyNMS(detections);
  }

  List<ActionDetection> _processActionOutputs(List<OrtValue?> outputs) {
    final detections = <ActionDetection>[];

    try {
      if (outputs.isEmpty || outputs[0] == null) {
        return detections;
      }

      final outputTensor = outputs[0] as OrtValueTensor;
      var predictionsRaw = outputTensor.value;
      // Handle nested output (List<List<double>>) or nulls
      List<double> predictions;
      if (predictionsRaw is List<double>) {
        predictions = predictionsRaw;
      } else if (predictionsRaw is List<List<double>>) {
        predictions = predictionsRaw
            .expand((e) => e)
            .whereType<double>()
            .toList();
      } else {
        print(
          '❌ Action detection error: output tensor is not List<double> or List<List<double>>',
        );
        return detections;
      }
      // Remove nulls and NaNs
      predictions = predictions.where((v) => v.isFinite).toList();

      // Apply softmax
      final probabilities = _applySoftmax(predictions);

      // Get top predictions
      final topPredictions = _getTopKPredictions(probabilities, k: 3);

      for (final prediction in topPredictions) {
        final actionId = prediction['index'] as int;
        final confidence = prediction['confidence'] as double;

        if (confidence.isFinite &&
            confidence >= ACTION_CONFIDENCE_THRESHOLD &&
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
      print('❌ Error processing action detection outputs: $e');
    }

    return detections;
  }

  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];

    final maxLogit = logits.reduce(math.max);
    final expLogits = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
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

    predictions.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo(a['confidence'] as double),
    );

    return predictions.take(k).toList();
  }

  List<Detection> _applyNMS(
    List<Detection> detections, {
    double nmsThreshold = 0.4,
  }) {
    if (detections.isEmpty) return detections;

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedDetections = <Detection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      selectedDetections.add(detections[i]);

      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;

        final iou = _calculateIOU(
          detections[i].boundingBox,
          detections[j].boundingBox,
        );

        if (iou > nmsThreshold) {
          suppressed[j] = true;
        }
      }

      if (selectedDetections.length >= 50) break; // Limit detections
    }

    return selectedDetections;
  }

  double _calculateIOU(Rect box1, Rect box2) {
    final intersectionLeft = math.max(box1.left, box2.left);
    final intersectionTop = math.max(box1.top, box2.top);
    final intersectionRight = math.min(box1.right, box2.right);
    final intersectionBottom = math.min(box1.bottom, box2.bottom);

    if (intersectionLeft >= intersectionRight ||
        intersectionTop >= intersectionBottom) {
      return 0.0;
    }

    final intersectionArea =
        (intersectionRight - intersectionLeft) *
        (intersectionBottom - intersectionTop);
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  List<String> _getFallbackObjectLabels() {
    return [
      'laptop',
      'person',
      'bicycle',
      'car',
      'motorcycle',
      'airplane',
      'bus',
      'train',
      'truck',
      'boat',
      'traffic light',
      'fire hydrant',
      'stop sign',
      'parking meter',
      'bench',
      'bird',
      'cat',
      'dog',
      'horse',
      'sheep',
      'cow',
      'elephant',
      'bear',
      'zebra',
      'giraffe',
      'backpack',
      'umbrella',
      'handbag',
      'tie',
      'suitcase',
      'frisbee',
      'skis',
      'snowboard',
      'sports ball',
      'kite',
      'baseball bat',
      'baseball glove',
      'skateboard',
      'surfboard',
      'tennis racket',
      'bottle',
      'wine glass',
      'cup',
      'fork',
      'knife',
      'spoon',
      'bowl',
      'banana',
      'apple',
      'sandwich',
      'orange',
      'broccoli',
      'carrot',
      'hot dog',
      'pizza',
      'donut',
      'cake',
      'chair',
      'couch',
      'potted plant',
      'bed',
      'dining table',
      'toilet',
      'tv',
      'laptop',
      'mouse',
      'remote',
      'keyboard',
      'cell phone',
      'microwave',
      'oven',
      'toaster',
      'sink',
      'refrigerator',
      'book',
      'clock',
      'vase',
      'scissors',
      'teddy bear',
      'hair drier',
      'toothbrush',
    ];
  }

  List<String> _getFallbackActionLabels() {
    return [
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
    ];
  }

  void clearBuffers() {
    _processedFrames.clear();
    _frameProcessingCount = 0;
  }

  void dispose() {
    clearBuffers();
    _objectSession?.release();
    _actionSession?.release();
    _isInitialized = false;
    _objectModelReady = false;
    _actionModelReady = false;
  }
}

class UnifiedAnalysisResult {
  final List<Detection> objectDetections;
  final List<ActionDetection> actionDetections;
  final Map<String, dynamic> contextData;
  final Duration processingTime;
  final DateTime timestamp;

  UnifiedAnalysisResult({
    required this.objectDetections,
    required this.actionDetections,
    required this.contextData,
    required this.processingTime,
    required this.timestamp,
  });

  bool get hasObjectDetections => objectDetections.isNotEmpty;
  bool get hasActionDetections => actionDetections.isNotEmpty;
  bool get hasContext => contextData.isNotEmpty;

  String get sceneDescription => contextData['scene_description'] ?? '';
  String get activityContext => contextData['activity_context'] ?? '';
  Map<String, double> get confidenceScores =>
      contextData['confidence_scores'] ?? <String, double>{};
}
