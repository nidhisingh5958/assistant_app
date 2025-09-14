import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:listen_iq/screens/video_assistant/detection_screen.dart'
    as detection_screen;
import 'package:listen_iq/screens/video_assistant/widgets/detection_info_panel.dart'
    as detection_widgets;
import 'package:listen_iq/screens/video_assistant/widgets/detection_overlay.dart';
import 'package:listen_iq/screens/video_assistant/widgets/action_info_panel.dart'
    as action_widgets;
import 'package:listen_iq/services/video/camera_service.dart';
import 'package:listen_iq/services/video/models/video_detector.dart';
import 'package:listen_iq/services/video/models/action_detector.dart'
    as service_models;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraService _cameraService;
  late VideoDetector _videoDetector;
  late service_models.ActionDetector _actionDetector;

  detection_screen.DetectionResult? _lastResult;
  bool _isProcessing = false;
  bool _showInfo = true;
  bool _showActions = true;
  bool _actionDetectionEnabled = true;
  StreamSubscription? _imageSubscription;

  // Performance metrics
  double _avgInferenceTime = 0.0;
  double _avgActionInferenceTime = 0.0;
  int _frameCount = 0;
  int _fps = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _videoDetector = VideoDetector();
    _actionDetector = service_models.ActionDetector();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize detectors
      await _videoDetector.initialize();
      await _actionDetector.initialize(useQuantisedModel: true);

      // Initialize camera
      await _cameraService.initializeCamera(widget.cameras);

      if (_cameraService.isInitialized) {
        // Start image stream processing
        _startImageProcessing();
        setState(() {});
      }
    } catch (e) {
      print('Error initializing services: $e');
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  void _startImageProcessing() {
    _cameraService.startImageStream();

    _imageSubscription = _cameraService.imageStream?.listen((image) {
      if (!_isProcessing && mounted) {
        _isProcessing = true;
        _processFrame(image);
      }
    });
  }

  Future<void> _processFrame(dynamic image) async {
    if (!_videoDetector.isInitialized) {
      _isProcessing = false;
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Convert CameraImage to image package Image
      final imglib.Image? convertedImage = _convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      // Run object detection
      final detections = _videoDetector.detectObjects(convertedImage);

      // Run action detection if enabled
      List<detection_screen.ActionDetection> actionDetections = [];
      if (_actionDetectionEnabled && _actionDetector.isInitialized) {
        final actionStopwatch = Stopwatch()..start();
        actionDetections = _actionDetector
            .detectActions(convertedImage)
            .cast<detection_screen.ActionDetection>();
        actionStopwatch.stop();

        // Update action inference time
        _updateActionMetrics(actionStopwatch.elapsed);
      }

      stopwatch.stop();
      final processingTime = stopwatch.elapsed;

      // Update performance metrics
      _updateMetrics(processingTime);

      // Update UI with results
      if (mounted) {
        setState(() {
          _lastResult = detection_screen.DetectionResult(
            detections: detections,
            actionDetections: actionDetections,
            processingTime: processingTime,
            imageSize: Size(image.width.toDouble(), image.height.toDouble()),
            inferenceTime: processingTime,
          );
        });
      }
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  imglib.Image? _convertCameraImage(CameraImage cameraImage) {
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

  imglib.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = imglib.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex =
            uvPixelStride * (x ~/ 2).floor() + uvRowStride * (y ~/ 2).floor();
        final int index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixel(x, y, imglib.ColorRgb8(r, g, b));
      }
    }
    return image;
  }

  imglib.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    return imglib.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      format: imglib.Format.uint8,
    );
  }

  void _updateMetrics(Duration processingTime) {
    _frameCount++;
    _avgInferenceTime =
        (_avgInferenceTime * (_frameCount - 1) +
            processingTime.inMilliseconds) /
        _frameCount;

    final now = DateTime.now();
    if (now.difference(_lastFpsUpdate).inSeconds >= 1) {
      _fps = _frameCount;
      _frameCount = 0;
      _lastFpsUpdate = now;
    }
  }

  void _updateActionMetrics(Duration actionProcessingTime) {
    _avgActionInferenceTime =
        (_avgActionInferenceTime * (_frameCount - 1) +
            actionProcessingTime.inMilliseconds) /
        _frameCount;
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraService.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing Camera & AI Models...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Loading Action Detection Model...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(child: CameraPreview(_cameraService.controller!)),

          // Detection Overlay
          if (_lastResult != null)
            Positioned.fill(
              child: DetectionOverlay(
                detections: _lastResult!.detections,
                imageSize: _lastResult!.imageSize,
                previewSize: MediaQuery.of(context).size,
              ),
            ),

          // Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Toggle Button
                IconButton(
                  onPressed: () => setState(() => _showInfo = !_showInfo),
                  icon: Icon(
                    _showInfo ? Icons.info : Icons.info_outline,
                    color: Colors.white,
                  ),
                ),

                // Title
                Column(
                  children: [
                    Text(
                      'ListenIQ Vision',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Object & Action Detection',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                // Camera Switch Button
                IconButton(
                  onPressed: widget.cameras.length > 1
                      ? () => _cameraService.switchCamera()
                      : null,
                  icon: Icon(
                    Icons.switch_camera,
                    color: widget.cameras.length > 1
                        ? Colors.white
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Action Detection Toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _actionDetectionEnabled
                    ? Colors.green.withOpacity(0.8)
                    : Colors.grey.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _actionDetectionEnabled = !_actionDetectionEnabled;
                    if (!_actionDetectionEnabled) {
                      _actionDetector.clearFrameBuffer();
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _actionDetectionEnabled ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Performance Indicators
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_fps}fps',
                    style: TextStyle(
                      color: _fps > 15 ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_actionDetectionEnabled) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'A: ${_avgActionInferenceTime.toInt()}ms',
                      style: TextStyle(
                        color: _avgActionInferenceTime < 100
                            ? Colors.green
                            : Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Detection Info Panel
          if (_showInfo && _lastResult != null)
            Positioned(
              bottom: _lastResult!.actionDetections.isNotEmpty && _showActions
                  ? 120
                  : 16,
              left: 16,
              right: 16,
              child: detection_widgets.DetectionInfoPanel(
                result: _lastResult!,
                avgInferenceTime: _avgInferenceTime,
                fps: _fps,
              ),
            ),

          // Action Info Panel
          if (_showActions && _lastResult?.actionDetections.isNotEmpty == true)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: action_widgets.DetectionInfoPanel(
                result: _lastResult!,
                avgInferenceTime: _avgActionInferenceTime,
                fps: _fps,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();
    _cameraService.dispose();
    _videoDetector.dispose();
    _actionDetector.dispose();
    super.dispose();
  }
}
