import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  static const String FUSION_MODEL_PATH =
      'assets/models/fusion_model_live.onnx';

  // Label paths
  static const String OBJECT_LABELS_PATH = 'assets/labels/oiv7_labels.txt';
  static const String ACTION_LABELS_PATH = 'assets/labels/action_labels.txt';

  // Model sessions
  OrtSession? _objectSession;
  OrtSession? _actionSession;
  OrtSession? _fusionSession;

  // Model metadata
  late List<String> _objectInputNames;
  late List<String> _actionInputNames;
  late List<String> _fusionInputNames;
  late List<List<int>> _objectInputShapes;
  late List<List<int>> _actionInputShapes;
  late List<List<int>> _fusionInputShapes;

  // Labels
  List<String> _objectLabels = [];
  List<String> _actionLabels = [];

  // State
  bool _isInitialized = false;
  bool _useQuantisedAction = true;

  // Frame buffers for temporal analysis
  List<img.Image> _frameBuffer = [];
  List<Float32List> _processedFrames = [];
  List<Detection> _lastObjectDetections = [];
  List<ActionDetection> _lastActionDetections = [];

  // Configuration
  static const int SEQUENCE_LENGTH = 16;
  static const int OBJECT_INPUT_SIZE = 640;
  static const int ACTION_INPUT_SIZE = 224;
  static const double OBJECT_CONFIDENCE_THRESHOLD = 0.5;
  static const double ACTION_CONFIDENCE_THRESHOLD = 0.6;

  bool get isInitialized => _isInitialized;
  List<String> get objectLabels => _objectLabels;
  List<String> get actionLabels => _actionLabels;

  Future<void> initialize({bool useQuantisedAction = true}) async {
    _useQuantisedAction = useQuantisedAction;

    try {
      print('Starting unified video analysis service initialization...');

      // Load all labels
      await _loadLabels();
      print(
        'Labels loaded - Objects: ${_objectLabels.length}, Actions: ${_actionLabels.length}',
      );

      // Initialize object detection model
      await _initializeObjectModel();
      print('Object detection model initialized');

      // Initialize action recognition model
      await _initializeActionModel();
      print('Action recognition model initialized');

      // Initialize fusion model
      await _initializeFusionModel();
      print('Fusion model initialized');

      _isInitialized = true;
      print('Unified video analysis service initialized successfully');
    } catch (e) {
      print('Error initializing unified service: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _loadLabels() async {
    try {
      // Load object labels
      final objectLabelsData = await rootBundle.loadString(OBJECT_LABELS_PATH);
      _objectLabels = objectLabelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
    } catch (e) {
      print('Using fallback object labels: $e');
      _objectLabels = _getFallbackObjectLabels();
    }

    try {
      // Load action labels
      final actionLabelsData = await rootBundle.loadString(ACTION_LABELS_PATH);
      _actionLabels = actionLabelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
    } catch (e) {
      print('Using fallback action labels: $e');
      _actionLabels = _getFallbackActionLabels();
    }
  }

  Future<void> _initializeObjectModel() async {
    final modelAsset = await rootBundle.load(OBJECT_MODEL_PATH);
    final modelBytes = modelAsset.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(2)
      ..setIntraOpNumThreads(2)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

    _objectSession = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _objectInputNames = _objectSession!.inputNames;
    _objectInputShapes = [
      [1, 3, OBJECT_INPUT_SIZE, OBJECT_INPUT_SIZE],
    ]; // Default YOLO input shape
  }

  Future<void> _initializeActionModel() async {
    final modelPath = _useQuantisedAction
        ? ACTION_MODEL_QUANTISED_PATH
        : ACTION_MODEL_PATH;

    final modelAsset = await rootBundle.load(modelPath);
    final modelBytes = modelAsset.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(1)
      ..setIntraOpNumThreads(1);

    _actionSession = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _actionInputNames = _actionSession!.inputNames;
    _actionInputShapes = [
      [1, SEQUENCE_LENGTH, 3, ACTION_INPUT_SIZE, ACTION_INPUT_SIZE],
    ]; // Default action model input shape
  }

  Future<void> _initializeFusionModel() async {
    final modelAsset = await rootBundle.load(FUSION_MODEL_PATH);
    final modelBytes = modelAsset.buffer.asUint8List();

    final sessionOptions = OrtSessionOptions()
      ..setInterOpNumThreads(2)
      ..setIntraOpNumThreads(2);

    _fusionSession = OrtSession.fromBuffer(modelBytes, sessionOptions);
    _fusionInputNames = _fusionSession!.inputNames;
    _fusionInputShapes = [
      [1, 256],
      [1, 80],
      [1, 15],
      [1, 32],
    ]; // Default fusion model input shapes
  }

  Future<UnifiedAnalysisResult> analyzeFrame(img.Image frame) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Run object detection
      final objectDetections = await _runObjectDetection(frame);

      // Add frame to buffer for action detection
      _addFrameToBuffer(frame);

      // Run action detection if we have enough frames
      List<ActionDetection> actionDetections = [];
      if (_frameBuffer.length >= SEQUENCE_LENGTH) {
        actionDetections = await _runActionDetection();
      }

      // Run fusion model for context generation
      final contextData = await _runFusionModel(
        frame,
        objectDetections,
        actionDetections,
      );

      stopwatch.stop();

      // Store for next iteration
      _lastObjectDetections = objectDetections;
      _lastActionDetections = actionDetections;

      return UnifiedAnalysisResult(
        objectDetections: objectDetections,
        actionDetections: actionDetections,
        contextData: contextData,
        processingTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error in unified analysis: $e');
      rethrow;
    }
  }

  Future<List<Detection>> _runObjectDetection(img.Image frame) async {
    if (_objectSession == null) return [];

    try {
      // Preprocess for YOLO
      final preprocessed = _preprocessForObject(frame);

      // Create input tensor
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        preprocessed['data'] as List<double>,
        [1, 3, OBJECT_INPUT_SIZE, OBJECT_INPUT_SIZE],
      );

      final inputs = <String, OrtValue>{_objectInputNames[0]: inputTensor};
      final outputs = _objectSession!.run(OrtRunOptions(), inputs);

      // Process outputs
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
      print('Object detection error: $e');
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

      // Create input tensor for action model
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
      print('Action detection error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _runFusionModel(
    img.Image frame,
    List<Detection> objects,
    List<ActionDetection> actions,
  ) async {
    if (_fusionSession == null) {
      return {};
    }

    try {
      // Prepare fusion inputs (combines visual features with detection results)
      final fusionInputs = _prepareFusionInputs(frame, objects, actions);

      // Create input tensors based on fusion model requirements
      final inputs = <String, OrtValue>{};
      for (int i = 0; i < _fusionInputNames.length; i++) {
        final inputName = _fusionInputNames[i];
        final inputData = fusionInputs[inputName] as List<double>;
        final inputShape = _fusionInputShapes[i];

        inputs[inputName] = OrtValueTensor.createTensorWithDataList(
          inputData,
          inputShape,
        );
      }

      final outputs = _fusionSession!.run(OrtRunOptions(), inputs);

      // Process fusion outputs to generate context
      final contextData = _processFusionOutputs(outputs);

      // Cleanup
      for (final input in inputs.values) {
        input.release();
      }
      for (final output in outputs) {
        output?.release();
      }

      return contextData;
    } catch (e) {
      print('Fusion model error: $e');
      return {};
    }
  }

  void _addFrameToBuffer(img.Image frame) {
    _frameBuffer.add(frame);

    // Preprocess frame for action detection
    final processedFrame = _preprocessForAction(frame);
    _processedFrames.add(processedFrame);

    // Maintain buffer size
    if (_frameBuffer.length > SEQUENCE_LENGTH) {
      _frameBuffer.removeAt(0);
    }
    if (_processedFrames.length > SEQUENCE_LENGTH) {
      _processedFrames.removeAt(0);
    }
  }

  Map<String, dynamic> _preprocessForObject(img.Image image) {
    // YOLO preprocessing with letterboxing
    final scaleX = OBJECT_INPUT_SIZE / image.width;
    final scaleY = OBJECT_INPUT_SIZE / image.height;
    final scale = math.min(scaleX, scaleY);

    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();
    final padX = (OBJECT_INPUT_SIZE - newWidth) / 2;
    final padY = (OBJECT_INPUT_SIZE - newHeight) / 2;

    final resizedImage = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
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

    // Convert to CHW format
    final inputData = <double>[];

    // RGB channels
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < OBJECT_INPUT_SIZE; y++) {
        for (int x = 0; x < OBJECT_INPUT_SIZE; x++) {
          final pixel = paddedImage.getPixel(x, y);
          switch (c) {
            case 0:
              inputData.add(pixel.r / 255.0);
              break;
            case 1:
              inputData.add(pixel.g / 255.0);
              break;
            case 2:
              inputData.add(pixel.b / 255.0);
              break;
          }
        }
      }
    }

    return {'data': inputData, 'scale': scale, 'pad_x': padX, 'pad_y': padY};
  }

  Float32List _preprocessForAction(img.Image frame) {
    // Resize for action recognition
    final resizedFrame = img.copyResize(
      frame,
      width: ACTION_INPUT_SIZE,
      height: ACTION_INPUT_SIZE,
    );

    // Normalize with ImageNet stats
    final frameData = Float32List(3 * ACTION_INPUT_SIZE * ACTION_INPUT_SIZE);
    int index = 0;

    // CHW format with normalization
    final means = [0.485, 0.456, 0.406];
    final stds = [0.229, 0.224, 0.225];

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < ACTION_INPUT_SIZE; y++) {
        for (int x = 0; x < ACTION_INPUT_SIZE; x++) {
          final pixel = resizedFrame.getPixel(x, y);
          double value;
          switch (c) {
            case 0:
              value = pixel.r / 255.0;
              break;
            case 1:
              value = pixel.g / 255.0;
              break;
            case 2:
              value = pixel.b / 255.0;
              break;
            default:
              value = 0.0;
          }
          frameData[index++] = (value - means[c]) / stds[c];
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

  // Object Detection Output Processing
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
      final predictions = outputTensor.value as List<double>;

      // YOLOv8 output format: [batch_size, num_predictions, 4 + num_classes]
      // For OIv7 dataset: typically [1, 8400, 84] where 84 = 4 bbox + 80 classes
      final numClasses = _objectLabels.length;
      final stride = 4 + numClasses; // bbox coordinates + class probabilities
      final numPredictions = predictions.length ~/ stride;

      final scale = preprocessed['scale'] as double;
      final padX = preprocessed['pad_x'] as double;
      final padY = preprocessed['pad_y'] as double;

      for (int i = 0; i < numPredictions; i++) {
        final baseIndex = i * stride;

        // Extract box coordinates (center format in normalized space)
        final centerX = predictions[baseIndex] * OBJECT_INPUT_SIZE;
        final centerY = predictions[baseIndex + 1] * OBJECT_INPUT_SIZE;
        final width = predictions[baseIndex + 2] * OBJECT_INPUT_SIZE;
        final height = predictions[baseIndex + 3] * OBJECT_INPUT_SIZE;

        // Find the class with highest confidence
        double maxConfidence = 0.0;
        int bestClassId = 0;

        for (int classId = 0; classId < numClasses; classId++) {
          final confidence = predictions[baseIndex + 4 + classId];
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            bestClassId = classId;
          }
        }

        // Filter by confidence threshold
        if (maxConfidence >= OBJECT_CONFIDENCE_THRESHOLD) {
          // Convert from center format to corner format
          final x1 = centerX - width / 2;
          final y1 = centerY - height / 2;
          final x2 = centerX + width / 2;
          final y2 = centerY + height / 2;

          // Adjust coordinates back to original image space
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

          // Skip invalid boxes
          if (adjustedX2 <= adjustedX1 || adjustedY2 <= adjustedY1) continue;

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
    } catch (e) {
      print('Error processing object detection outputs: $e');
    }

    return _applyNMS(detections);
  }

  // Action Recognition Processing
  List<ActionDetection> _processActionOutputs(List<OrtValue?> outputs) {
    final detections = <ActionDetection>[];

    try {
      if (outputs.isEmpty || outputs[0] == null) {
        return detections;
      }

      final outputTensor = outputs[0] as OrtValueTensor;
      final predictions = outputTensor.value as List<double>;

      // Apply softmax to get probabilities
      final probabilities = _applySoftmax(predictions);

      // Get top-k predictions (top 5 most confident actions)
      final topPredictions = _getTopKPredictions(probabilities, k: 5);

      for (final prediction in topPredictions) {
        final actionId = prediction['index'] as int;
        final confidence = prediction['confidence'] as double;

        if (confidence >= ACTION_CONFIDENCE_THRESHOLD &&
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

  Map<String, dynamic> _processFusionOutputs(List<OrtValue?> outputs) {
    final contextData = <String, dynamic>{
      'scene_description': '',
      'activity_context': '',
      'confidence_scores': <String, double>{},
      'temporal_features': <double>[],
    };

    try {
      if (outputs.isEmpty) return contextData;

      // Process each output based on fusion model architecture
      for (int i = 0; i < outputs.length; i++) {
        final output = outputs[i];
        if (output == null) continue;

        final outputTensor = output as OrtValueTensor;
        final outputData = outputTensor.value as List<double>;

        switch (i) {
          case 0: // Scene description embeddings
            contextData['scene_description'] = _generateSceneDescription(
              outputData,
            );
            break;
          case 1: // Activity context embeddings
            contextData['activity_context'] = _generateActivityContext(
              outputData,
            );
            break;
          case 2: // Confidence scores
            contextData['confidence_scores'] = _extractConfidenceScores(
              outputData,
            );
            break;
          case 3: // Temporal features
            contextData['temporal_features'] = outputData;
            break;
        }
      }
    } catch (e) {
      print('Error processing fusion outputs: $e');
    }

    return contextData;
  }

  // Helper methods for fusion model output processing
  String _generateSceneDescription(List<double> embeddings) {
    // This would typically involve looking up the closest scene description
    // based on embedding similarity. For now, return a basic interpretation.

    if (embeddings.isEmpty) return '';

    // Simple heuristic based on embedding values (replace with actual lookup)
    final avgEmbedding = embeddings.reduce((a, b) => a + b) / embeddings.length;

    if (avgEmbedding > 0.7) {
      return 'Indoor scene with multiple objects';
    } else if (avgEmbedding > 0.4) {
      return 'Outdoor environment';
    } else if (avgEmbedding > 0.1) {
      return 'Simple scene with few objects';
    } else {
      return 'Complex scene';
    }
  }

  String _generateActivityContext(List<double> embeddings) {
    if (embeddings.isEmpty) return '';

    // Simple interpretation - replace with proper embedding lookup
    final maxValue = embeddings.reduce(math.max);
    final maxIndex = embeddings.indexOf(maxValue);

    final contexts = [
      'Person interacting with environment',
      'Multiple people present',
      'Object manipulation activity',
      'Movement-based activity',
      'Stationary scene',
      'Dynamic interaction',
    ];

    return contexts[maxIndex % contexts.length];
  }

  Map<String, double> _extractConfidenceScores(List<double> scores) {
    final confidenceMap = <String, double>{};

    if (scores.length >= 4) {
      confidenceMap['scene_confidence'] = scores[0];
      confidenceMap['action_confidence'] = scores[1];
      confidenceMap['object_confidence'] = scores[2];
      confidenceMap['overall_confidence'] = scores[3];
    }

    return confidenceMap;
  }

  // Add these utility methods for action processing
  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];

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

  // Add NMS implementation for object detection
  List<Detection> _applyNMS(
    List<Detection> detections, {
    double nmsThreshold = 0.4,
  }) {
    if (detections.isEmpty) return detections;

    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedDetections = <Detection>[];
    final suppressed = List<bool>.filled(detections.length, false);

    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;

      selectedDetections.add(detections[i]);

      // Suppress overlapping detections
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

      // Limit total detections
      if (selectedDetections.length >= 100) break;
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

  // Enhanced fusion input preparation
  Map<String, List<double>> _prepareFusionInputs(
    img.Image frame,
    List<Detection> objects,
    List<ActionDetection> actions,
  ) {
    final inputs = <String, List<double>>{};

    // Visual features: Extract key visual features from the frame
    if (_fusionInputNames.contains('visual_features')) {
      inputs['visual_features'] = _extractVisualFeatures(frame);
    }

    // Object features: Encode object detection results
    if (_fusionInputNames.contains('object_features')) {
      inputs['object_features'] = _encodeObjectDetections(objects);
    }

    // Action features: Encode action recognition results
    if (_fusionInputNames.contains('action_features')) {
      inputs['action_features'] = _encodeActionDetections(actions);
    }

    // Temporal features: Include previous frame context
    if (_fusionInputNames.contains('temporal_features')) {
      inputs['temporal_features'] = _extractTemporalFeatures();
    }

    return inputs;
  }

  List<double> _extractVisualFeatures(img.Image frame) {
    // Extract basic visual features (color histograms, edge density, etc.)
    final features = <double>[];

    // Resize frame for feature extraction
    final smallFrame = img.copyResize(frame, width: 64, height: 64);

    // Color histogram features (simplified)
    final rHist = List<int>.filled(8, 0);
    final gHist = List<int>.filled(8, 0);
    final bHist = List<int>.filled(8, 0);

    for (int y = 0; y < 64; y++) {
      for (int x = 0; x < 64; x++) {
        final pixel = smallFrame.getPixel(x, y);
        rHist[(pixel.r / 32).floor().clamp(0, 7)]++;
        gHist[(pixel.g / 32).floor().clamp(0, 7)]++;
        bHist[(pixel.b / 32).floor().clamp(0, 7)]++;
      }
    }

    // Normalize and add to features
    final totalPixels = 64 * 64;
    features.addAll(rHist.map((count) => count / totalPixels));
    features.addAll(gHist.map((count) => count / totalPixels));
    features.addAll(bHist.map((count) => count / totalPixels));

    // Pad or truncate to expected size (adjust based on your fusion model)
    while (features.length < 256) {
      features.add(0.0);
    }

    return features.take(256).toList();
  }

  List<double> _encodeObjectDetections(List<Detection> objects) {
    // Encode object detections as feature vector
    const maxObjects = 10; // Limit for fusion model
    const featuresPerObject =
        8; // classId, confidence, bbox(4), area, aspect_ratio

    final features = <double>[];

    for (int i = 0; i < maxObjects; i++) {
      if (i < objects.length) {
        final obj = objects[i];
        features.addAll([
          obj.classId / _objectLabels.length, // Normalized class ID
          obj.confidence,
          obj.boundingBox.left / 640.0, // Normalized coordinates
          obj.boundingBox.top / 640.0,
          obj.boundingBox.right / 640.0,
          obj.boundingBox.bottom / 640.0,
          (obj.boundingBox.width * obj.boundingBox.height) /
              (640.0 * 640.0), // Normalized area
          obj.boundingBox.width / obj.boundingBox.height, // Aspect ratio
        ]);
      } else {
        // Padding for empty slots
        features.addAll(List<double>.filled(featuresPerObject, 0.0));
      }
    }

    return features;
  }

  List<double> _encodeActionDetections(List<ActionDetection> actions) {
    // Encode action detections as feature vector
    const maxActions = 5;
    const featuresPerAction = 3; // actionId, confidence, recency

    final features = <double>[];
    final now = DateTime.now();

    for (int i = 0; i < maxActions; i++) {
      if (i < actions.length) {
        final action = actions[i];
        final recency =
            1.0 -
            (now.difference(action.timestamp).inSeconds / 60.0).clamp(0.0, 1.0);

        features.addAll([
          action.actionId / _actionLabels.length, // Normalized action ID
          action.confidence,
          recency, // How recent the action was detected
        ]);
      } else {
        // Padding for empty slots
        features.addAll(List<double>.filled(featuresPerAction, 0.0));
      }
    }

    return features;
  }

  List<double> _extractTemporalFeatures() {
    // Extract temporal context from previous detections
    final features = <double>[];

    // Object consistency over time
    final objectCounts = <int, int>{};
    for (final obj in _lastObjectDetections) {
      objectCounts[obj.classId] = (objectCounts[obj.classId] ?? 0) + 1;
    }

    // Action consistency over time
    final actionCounts = <int, int>{};
    for (final action in _lastActionDetections) {
      actionCounts[action.actionId] = (actionCounts[action.actionId] ?? 0) + 1;
    }

    // Create feature vector (simplified)
    features.add(
      _lastObjectDetections.length / 10.0,
    ); // Normalized object count
    features.add(_lastActionDetections.length / 5.0); // Normalized action count

    // Add stability metrics
    features.add(
      objectCounts.isNotEmpty
          ? objectCounts.values.reduce(math.max) / 10.0
          : 0.0,
    );
    features.add(
      actionCounts.isNotEmpty
          ? actionCounts.values.reduce(math.max) / 5.0
          : 0.0,
    );

    // Pad to expected size
    while (features.length < 32) {
      features.add(0.0);
    }

    return features.take(32).toList();
  }

  List<String> _getFallbackObjectLabels() {
    return [
      'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train',
      'truck', 'boat', 'traffic light', 'fire hydrant', 'stop sign',
      // Add more fallback labels as needed
    ];
  }

  List<String> _getFallbackActionLabels() {
    return [
      'walking', 'running', 'sitting', 'standing', 'jumping', 'waving',
      'clapping', 'dancing', 'eating', 'drinking', 'reading', 'writing',
      // Add more fallback action labels as needed
    ];
  }

  void clearBuffers() {
    _frameBuffer.clear();
    _processedFrames.clear();
  }

  void dispose() {
    clearBuffers();
    _objectSession?.release();
    _actionSession?.release();
    _fusionSession?.release();
    _isInitialized = false;
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
