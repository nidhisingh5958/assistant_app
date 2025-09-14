import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isStreaming = false;
  StreamController<img.Image>? _imageStreamController;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  Stream<img.Image>? get imageStream => _imageStreamController?.stream;

  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    _cameras = cameras;

    if (_cameras.isNotEmpty) {
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      try {
        await _controller!.initialize();
        _isInitialized = true;
        _imageStreamController = StreamController<img.Image>.broadcast();
        notifyListeners();
      } catch (e) {
        print('Error initializing camera: $e');
        _isInitialized = false;
      }
    }
  }

  void startImageStream() {
    if (!_isInitialized || _isStreaming) return;

    _controller!.startImageStream((CameraImage cameraImage) {
      if (!_isStreaming) return;

      // Convert CameraImage to img.Image in background
      _convertCameraImage(cameraImage).then((image) {
        if (image != null &&
            _imageStreamController != null &&
            !_imageStreamController!.isClosed) {
          _imageStreamController!.add(image);
        }
      });
    });

    _isStreaming = true;
    notifyListeners();
  }

  void stopImageStream() {
    if (!_isStreaming) return;

    _controller?.stopImageStream();
    _isStreaming = false;
    notifyListeners();
  }

  Future<img.Image?> _convertCameraImage(CameraImage cameraImage) async {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      }
    } catch (e) {
      print('Error converting camera image: $e');
    }
    return null;
  }

  img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;

    final image = img.Image(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final yValue = yBuffer[yIndex];
        final uValue = uBuffer[uvIndex];
        final vValue = vBuffer[uvIndex];

        // YUV to RGB conversion
        final r = (yValue + 1.13983 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.39465 * (uValue - 128) - 0.58060 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yValue + 2.03211 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixel(x, y, img.getColor(r, g, b));
      }
    }

    return image;
  }

  img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final bytes = cameraImage.planes[0].bytes;

    final image = img.Image(width, height);

    for (int i = 0; i < bytes.length; i += 4) {
      final b = bytes[i];
      final g = bytes[i + 1];
      final r = bytes[i + 2];
      final a = bytes[i + 3];

      final x = (i ~/ 4) % width;
      final y = (i ~/ 4) ~/ width;

      image.setPixel(x, y, img.getColor(r, g, b));
    }

    return image;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentIndex = _cameras.indexWhere(
      (camera) => camera == _controller!.description,
    );
    final nextIndex = (currentIndex + 1) % _cameras.length;

    await _controller!.dispose();

    _controller = CameraController(
      _cameras[nextIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    notifyListeners();
  }

  @override
  void dispose() {
    stopImageStream();
    _imageStreamController?.close();
    _controller?.dispose();
    super.dispose();
  }
}
