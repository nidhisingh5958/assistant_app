// can serve as backup TFLite service

import 'dart:ui';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class InferenceService {
  static const String modelPath = 'assets/models/video_detection_model.tflite';
  late Interpreter _interpreter;
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isModelLoaded = true;
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  List<dynamic> runInference(img.Image image) {
    if (!_isModelLoaded) return [];

    // Preprocess image
    var input = _preprocessImage(image);

    // Prepare output tensors
    var output = List.generate(1, (index) => List.filled(10, 0.0));

    // Run inference
    _interpreter.run(input, output);

    return _postProcessOutput(output[0]);
  }

  List<List<List<double>>> _preprocessImage(img.Image image) {
    // Resize image to model input size (adjust based on your model)
    var resizedImage = img.copyResize(image, width: 224, height: 224);

    // Convert to normalized float values
    var input = List.generate(
      1,
      (i) => List.generate(
        224,
        (j) => List.generate(
          224,
          (k) => List.generate(3, (l) {
            var pixel = resizedImage.getPixel(j, k);
            switch (l) {
              case 0:
                return pixel.r / 255.0; // Red
              case 1:
                return pixel.g / 255.0; // Green
              case 2:
                return pixel.b / 255.0; // Blue
              default:
                return 0.0;
            }
          }),
        ),
      ),
    );

    return input[0];
  }

  List<Detection> _postProcessOutput(List<double> output) {
    // Process model output to extract detections
    // This depends on your specific model architecture
    List<Detection> detections = [];

    // Example for object detection model
    for (int i = 0; i < output.length; i += 6) {
      if (output[i + 4] > 0.5) {
        // Confidence threshold
        detections.add(
          Detection(
            classId: output[i].toInt(),
            className: 'Unknown', // Add default class name
            confidence: output[i + 4],
            boundingBox: Rect.fromLTWH(
              output[i + 0],
              output[i + 1],
              output[i + 2] - output[i + 0],
              output[i + 3] - output[i + 1],
            ),
          ),
        );
      }
    }

    return detections;
  }

  void dispose() {
    _interpreter.close();
  }
}
