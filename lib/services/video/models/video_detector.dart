import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;

class VideoDetector {
  static const String YOLO_MODEL_PATH = 'assets/models/yolov8s-oiv7.onnx';
  static const String LABELS_PATH = 'assets/labels/oiv7_labels.txt';
  static const int INPUT_SIZE = 640; // YOLOv8 standard input size

  // ONNX Runtime components
  OrtSession? _session;
  late List<String> _inputNames;
  late List<String> _outputNames;

  List<String> _labels = [];
  bool _isInitialized = false;

  // Detection parameters
  static const double CONFIDENCE_THRESHOLD = 0.5;
  static const double NMS_THRESHOLD = 0.4;
  static const int MAX_DETECTIONS = 100;

  bool get isInitialized => _isInitialized;
  bool get isUsingOnnx => true; // Always using ONNX now

  Future<void> initialize({bool preferOnnx = true}) async {
    try {
      print('Initializing YOLOv8 ONNX model...');

      // Load ONNX model
      await _loadOnnxModel();

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      print('Video detection model initialized successfully with YOLOv8 ONNX');
      print('Model inputs: $_inputNames');
      print('Model outputs: $_outputNames');
      print('Loaded ${_labels.length} object classes');
    } catch (e) {
      print('Error initializing video detection model: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _loadOnnxModel() async {
    try {
      // Load the YOLOv8 ONNX model
      final modelAsset = await rootBundle.load(YOLO_MODEL_PATH);
      final modelBytes = modelAsset.buffer.asUint8List();

      // Create ONNX Runtime session with optimization
      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(1)
        ..setIntraOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);

      // Get model metadata
      _inputNames = _session!.inputNames;
      _outputNames = _session!.outputNames;
    } catch (e) {
      throw Exception('Failed to load YOLOv8 model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(LABELS_PATH);
      _labels = labelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim())
          .toList();
      print('Loaded ${_labels.length} OIv7 labels from file');
    } catch (e) {
      print('Error loading labels from file: $e');
      print('Using fallback Open Images v7 labels');
      // Fallback to common Open Images v7 labels
      _labels = [
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
        'banner',
        'blanket',
        'bridge',
        'cardboard',
        'counter',
        'curtain',
        'door-stuff',
        'floor-wood',
        'flower',
        'fruit',
        'gravel',
        'house',
        'light',
        'mirror-stuff',
        'net',
        'pillow',
        'platform',
        'playingfield',
        'railroad',
        'river',
        'road',
        'roof',
        'sand',
        'sea',
        'shelf',
        'snow',
        'stairs',
        'tent',
        'towel',
        'wall-brick',
        'wall-stone',
        'wall-tile',
        'wall-wood',
        'water-other',
        'window-blind',
        'window-other',
        'tree-merged',
        'fence-merged',
        'ceiling-merged',
        'sky-other-merged',
        'cabinet-merged',
        'table-merged',
        'floor-other-merged',
        'pavement-merged',
        'mountain-merged',
        'grass-merged',
        'dirt-merged',
        'paper-merged',
        'food-other-merged',
        'building-other-merged',
        'rock-merged',
        'wall-other-merged',
      ];
    }
  }

  List<Detection> detectObjects(img.Image image) {
    if (!_isInitialized || _session == null) {
      return [];
    }

    try {
      // Preprocess image
      final preprocessed = _preprocessImage(image);

      // Create input tensor
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        preprocessed['data'] as List<double>,
        [1, 3, INPUT_SIZE, INPUT_SIZE], // NCHW format
      );

      // Prepare inputs
      final inputs = <String, OrtValue>{_inputNames[0]: inputTensor};

      // Run inference
      final stopwatch = Stopwatch()..start();
      final outputs = _session!.run(OrtRunOptions(), inputs);
      stopwatch.stop();

      print('YOLOv8 inference time: ${stopwatch.elapsedMilliseconds}ms');

      // Process outputs
      final detections = _processYoloOutputs(
        outputs,
        image.width,
        image.height,
        preprocessed['scale_x'] as double,
        preprocessed['scale_y'] as double,
        preprocessed['pad_x'] as double,
        preprocessed['pad_y'] as double,
      );

      // Clean up
      inputTensor.release();
      for (final output in outputs) {
        output?.release();
      }

      return detections;
    } catch (e) {
      print('Error during YOLOv8 detection: $e');
      return [];
    }
  }

  Map<String, dynamic> _preprocessImage(img.Image image) {
    // Calculate scaling factors to maintain aspect ratio
    final scaleX = INPUT_SIZE / image.width;
    final scaleY = INPUT_SIZE / image.height;
    final scale = math.min(scaleX, scaleY);

    // Calculate new dimensions and padding
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();
    final padX = (INPUT_SIZE - newWidth) / 2;
    final padY = (INPUT_SIZE - newHeight) / 2;

    // Resize image maintaining aspect ratio
    final resizedImage = img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    // Create padded image
    final paddedImage = img.Image(width: INPUT_SIZE, height: INPUT_SIZE);
    img.fill(paddedImage, color: img.ColorRgb8(114, 114, 114)); // Gray padding

    // Copy resized image to center of padded image
    img.compositeImage(
      paddedImage,
      resizedImage,
      dstX: padX.round(),
      dstY: padY.round(),
    );

    // Convert to float32 normalized array in CHW format
    final inputData = <double>[];

    // Red channel
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = paddedImage.getPixel(x, y);
        inputData.add(pixel.r / 255.0);
      }
    }

    // Green channel
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = paddedImage.getPixel(x, y);
        inputData.add(pixel.g / 255.0);
      }
    }

    // Blue channel
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = paddedImage.getPixel(x, y);
        inputData.add(pixel.b / 255.0);
      }
    }

    return {
      'data': inputData,
      'scale_x': scaleX,
      'scale_y': scaleY,
      'scale': scale,
      'pad_x': padX,
      'pad_y': padY,
    };
  }

  List<Detection> _processYoloOutputs(
    List<OrtValue?> outputs,
    int originalWidth,
    int originalHeight,
    double scaleX,
    double scaleY,
    double padX,
    double padY,
  ) {
    final detections = <Detection>[];

    try {
      if (outputs.isEmpty || outputs[0] == null) {
        return detections;
      }

      final outputTensor = outputs[0] as OrtValueTensor;
      final predictions = outputTensor.value as List<double>;

      // YOLOv8 output format: [1, 84, 8400] or similar
      // 84 = 4 (bbox) + 80 (classes) for COCO, adjust for OIv7
      final numClasses = _labels.length;
      final numPredictions = predictions.length ~/ (4 + numClasses);
      final stride = 4 + numClasses;

      for (int i = 0; i < numPredictions; i++) {
        final baseIndex = i * stride;

        // Extract box coordinates (center format)
        final centerX = predictions[baseIndex];
        final centerY = predictions[baseIndex + 1];
        final width = predictions[baseIndex + 2];
        final height = predictions[baseIndex + 3];

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
        if (maxConfidence >= CONFIDENCE_THRESHOLD) {
          // Convert from center format to corner format
          final x1 = centerX - width / 2;
          final y1 = centerY - height / 2;
          final x2 = centerX + width / 2;
          final y2 = centerY + height / 2;

          // Adjust coordinates back to original image space
          final scale = math.min(scaleX, scaleY);
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

          final className = bestClassId < _labels.length
              ? _labels[bestClassId]
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
      print('Error processing YOLOv8 outputs: $e');
    }

    return _applyNMS(detections);
  }

  List<Detection> _applyNMS(
    List<Detection> detections, {
    double nmsThreshold = NMS_THRESHOLD,
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
      if (selectedDetections.length >= MAX_DETECTIONS) {
        break;
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

    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  void dispose() {
    _session?.release();
    _isInitialized = false;
  }
}
