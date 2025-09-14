import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:path/path.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class VideoDetector {
  static const String MODEL_PATH = 'assets/models/video_detection_model.tflite';
  static const String LABELS_PATH = 'assets/labels/labels.txt';
  static const int INPUT_SIZE = 640; // Adjust based on your model

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  // Model input/output shapes - adjust based on your model
  late List<List<int>> _inputShapes;
  late List<List<int>> _outputShapes;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      // Load the TFLite model
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);

      // Get input and output shapes
      _inputShapes = _interpreter!
          .getInputTensors()
          .map((tensor) => tensor.shape)
          .toList();
      _outputShapes = _interpreter!
          .getOutputTensors()
          .map((tensor) => tensor.shape)
          .toList();

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      print('Video detection model initialized successfully');
      print('Input shapes: $_inputShapes');
      print('Output shapes: $_outputShapes');
    } catch (e) {
      print('Error initializing video detector: $e');
      _isInitialized = false;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await DefaultAssetBundle.of(
        context as BuildContext,
      ).loadString(LABELS_PATH);
      _labels = labelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .toList();
      print('Loaded ${_labels.length} labels');
    } catch (e) {
      print('Error loading labels: $e');
      // Fallback labels - adjust based on your model
      _labels = ['person', 'car', 'bicycle', 'dog', 'cat'];
    }
  }

  List<Detection> detectObjects(img.Image image) {
    if (!_isInitialized || _interpreter == null) {
      return [];
    }

    try {
      // Preprocess image
      final input = _preprocessImage(image);

      // Prepare outputs - adjust based on your model architecture
      final outputs = _prepareOutputs();

      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter!.runForMultipleInputs([input], outputs);
      stopwatch.stop();

      print('Inference time: ${stopwatch.elapsedMilliseconds}ms');

      // Post-process results
      return _postProcessOutputs(outputs, image.width, image.height);
    } catch (e) {
      print('Error during detection: $e');
      return [];
    }
  }

  List _preprocessImage(img.Image image) {
    // Resize image to model input size
    final resizedImage = img.copyResize(
      image,
      width: INPUT_SIZE,
      height: INPUT_SIZE,
    );

    // Convert to Float32List with normalization
    final input = Float32List(1 * INPUT_SIZE * INPUT_SIZE * 3);
    int pixelIndex = 0;

    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = resizedImage.getPixel(x, y);

        // Extract RGB components from the Pixel object
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Normalize pixel values to [0, 1] or [-1, 1] based on your model
        input[pixelIndex++] = r / 255.0;
        input[pixelIndex++] = g / 255.0;
        input[pixelIndex++] = b / 255.0;
      }
    }

    return input.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);
  }

  Map<int, Object> _prepareOutputs() {
    // Adjust based on your model's output structure
    // Common YOLO-style outputs: [boxes, scores, classes]
    return {
      0: Float32List(_outputShapes[0].reduce((a, b) => a * b)), // boxes
      1: Float32List(_outputShapes[1].reduce((a, b) => a * b)), // scores
      2: Float32List(_outputShapes[2].reduce((a, b) => a * b)), // classes
    };
  }

  List<Detection> _postProcessOutputs(
    Map<int, Object> outputs,
    int imageWidth,
    int imageHeight,
  ) {
    final boxes = outputs[0] as Float32List;
    final scores = outputs[1] as Float32List;
    final classes = outputs[2] as Float32List;

    final detections = <Detection>[];
    final confidenceThreshold = 0.5;

    // Process each detection - adjust based on your model's output format
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > confidenceThreshold) {
        // Extract bounding box coordinates (normalized 0-1)
        final x1 = boxes[i * 4];
        final y1 = boxes[i * 4 + 1];
        final x2 = boxes[i * 4 + 2];
        final y2 = boxes[i * 4 + 3];

        // Convert to pixel coordinates
        final left = (x1 * imageWidth).clamp(0.0, imageWidth.toDouble());
        final top = (y1 * imageHeight).clamp(0.0, imageHeight.toDouble());
        final right = (x2 * imageWidth).clamp(0.0, imageWidth.toDouble());
        final bottom = (y2 * imageHeight).clamp(0.0, imageHeight.toDouble());

        final classId = classes[i].toInt();
        final className = classId < _labels.length
            ? _labels[classId]
            : 'Unknown';

        detections.add(
          Detection(
            classId: classId,
            className: className,
            confidence: scores[i],
            boundingBox: Rect.fromLTRB(left, top, right, bottom),
          ),
        );
      }
    }

    // Apply Non-Maximum Suppression if needed
    return _applyNMS(detections);
  }

  List<Detection> _applyNMS(
    List<Detection> detections, {
    double nmsThreshold = 0.4,
  }) {
    if (detections.isEmpty) return detections;

    // Sort by confidence
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedDetections = <Detection>[];
    final suppressed = <bool>[];

    for (int i = 0; i < detections.length; i++) {
      suppressed.add(false);
    }

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

    return intersectionArea / unionArea;
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
