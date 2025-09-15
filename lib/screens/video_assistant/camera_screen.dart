import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:listen_iq/screens/video_assistant/widgets/detection_info_panel.dart'
    as detection_widgets;
import 'package:listen_iq/screens/video_assistant/widgets/detection_overlay.dart';
import 'package:listen_iq/screens/video_assistant/widgets/action_info_panel.dart';
import 'package:listen_iq/services/video/camera_service.dart';
import 'package:listen_iq/services/video/models/unified_video_analysis_service.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraService _cameraService;
  late UnifiedVideoAnalysisService _analysisService;

  UnifiedAnalysisResult? _lastResult;
  bool _isProcessing = false;
  bool _showInfo = true;
  bool _showActions = true;
  bool _actionDetectionEnabled = true;
  StreamSubscription? _imageSubscription;

  // Initialization state tracking
  String _initializationStatus = 'Starting initialization...';
  bool _cameraInitialized = false;
  bool _analysisServiceInitialized = false;

  // Performance metrics
  double _avgInferenceTime = 0.0;
  int _frameCount = 0;
  int _fps = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _analysisService = UnifiedVideoAnalysisService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Step 1: Initialize Unified Analysis Service
      setState(() {
        _initializationStatus = 'Initializing AI models...';
      });

      await _analysisService.initialize(useQuantisedAction: true);
      _analysisServiceInitialized = _analysisService.isInitialized;

      print('Analysis service initialized: $_analysisServiceInitialized');

      if (!_analysisServiceInitialized) {
        throw Exception('Failed to initialize analysis service');
      }

      // Step 2: Initialize Camera
      setState(() {
        _initializationStatus = 'Initializing camera...';
      });

      await _cameraService.initializeCamera(widget.cameras);
      _cameraInitialized = _cameraService.isInitialized;

      print('Camera initialized: $_cameraInitialized');

      if (!_cameraInitialized) {
        throw Exception('Failed to initialize camera');
      }

      // Step 3: Start processing
      if (_cameraInitialized && _analysisServiceInitialized) {
        setState(() {
          _initializationStatus = 'Starting video analysis...';
        });

        _startImageProcessing();

        setState(() {
          _initializationStatus = 'Ready!';
        });

        print('All services initialized successfully');
      }
    } catch (e) {
      print('Critical initialization error: $e');
      setState(() {
        _initializationStatus = 'Error: ${e.toString()}';
      });
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  void _startImageProcessing() {
    _cameraService.startImageStream();

    _imageSubscription = _cameraService.imageStream?.listen((image) {
      if (!_isProcessing && mounted && _analysisServiceInitialized) {
        _isProcessing = true;
        _processFrame(image);
      }
    });
  }

  Future<void> _processFrame(dynamic image) async {
    if (!_analysisService.isInitialized) {
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

      // Run unified analysis
      final result = await _analysisService.analyzeFrame(convertedImage);

      stopwatch.stop();
      final processingTime = stopwatch.elapsed;

      // Update performance metrics
      _updateMetrics(processingTime);

      // Update UI with results
      if (mounted) {
        setState(() {
          _lastResult = result;
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 16),
            Text('Debug Info:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Camera: ${_cameraInitialized ? 'OK' : 'Failed'}'),
            Text(
              'Analysis Service: ${_analysisServiceInitialized ? 'OK' : 'Failed'}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          if (!_cameraInitialized || !_analysisServiceInitialized)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initializeServices(); // Retry initialization
              },
              child: Text('Retry'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen if essential services aren't ready
    if (!_cameraInitialized || !_analysisServiceInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                _initializationStatus,
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              // Debug information
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Initialization Status:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildStatusRow('Camera', _cameraInitialized),
                    _buildStatusRow(
                      'Object Detection',
                      _analysisServiceInitialized,
                    ),
                    _buildStatusRow(
                      'Action Detection',
                      _analysisServiceInitialized,
                    ),
                    _buildStatusRow(
                      'Fusion Model',
                      _analysisServiceInitialized,
                    ),
                  ],
                ),
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
                detections: _lastResult!.objectDetections,
                imageSize: Size(
                  _cameraService.controller!.value.previewSize!.height,
                  _cameraService.controller!.value.previewSize!.width,
                ),
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
                      'ListenIQ Vision Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Unified AI Analysis',
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
                      _analysisService.clearBuffers();
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
                      'AI Analysis',
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
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'AI: ${_avgInferenceTime.toInt()}ms',
                    style: TextStyle(
                      color: _avgInferenceTime < 200
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Context Information Panel
          if (_lastResult?.hasContext == true)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_lastResult!.sceneDescription.isNotEmpty) ...[
                      Text(
                        'Scene: ${_lastResult!.sceneDescription}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                    if (_lastResult!.activityContext.isNotEmpty) ...[
                      Text(
                        'Activity: ${_lastResult!.activityContext}',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Detection Info Panel
          if (_showInfo && _lastResult != null)
            Positioned(
              bottom: (_lastResult!.hasActionDetections && _showActions)
                  ? 120
                  : 16,
              left: 16,
              right: 16,
              child: detection_widgets.DetectionInfoPanel(
                result: DetectionResult(
                  detections: _lastResult!.objectDetections,
                  actionDetections: _lastResult!.actionDetections,
                  processingTime: _lastResult!.processingTime,
                  imageSize: Size(640, 480), // Placeholder size
                  inferenceTime: _lastResult!.processingTime,
                ),
                avgInferenceTime: _avgInferenceTime,
                fps: _fps,
              ),
            ),

          // Action Info Panel
          if (_showActions && _lastResult?.hasActionDetections == true)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ActionInfoPanel(
                result: DetectionResult(
                  detections: _lastResult!.objectDetections,
                  actionDetections: _lastResult!.actionDetections,
                  processingTime: _lastResult!.processingTime,
                  imageSize: Size(640, 480), // Placeholder size
                  inferenceTime: _lastResult!.processingTime,
                ),
                avgActionInferenceTime: _avgInferenceTime,
                isActionDetectionActive: _actionDetectionEnabled,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12)),
          Icon(
            status ? Icons.check_circle : Icons.error,
            color: status ? Colors.green : Colors.red,
            size: 16,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();
    _cameraService.dispose();
    _analysisService.dispose();
    super.dispose();
  }
}
