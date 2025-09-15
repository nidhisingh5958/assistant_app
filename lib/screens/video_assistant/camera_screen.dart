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
import 'package:listen_iq/services/video/models/unified_model_service.dart';

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

  int _droppedFrames = 0;
  int _processedFrames = 0;
  DateTime _lastProcessTime = DateTime.now();
  static const int TARGET_FPS = 10; // Limit processing to 10 FPS
  static const Duration MIN_PROCESS_INTERVAL = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _analysisService = UnifiedVideoAnalysisService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Add a small delay to ensure everything is ready
      await Future.delayed(Duration(milliseconds: 500));

      setState(() {
        _initializationStatus = 'Preparing camera system...';
      });

      // Step 1: Initialize AI models first (they're working fine)
      setState(() {
        _initializationStatus = 'Loading AI models...';
      });

      // Explicitly initialize the analysis service
      await _analysisService.initialize();
      _analysisServiceInitialized = true;

      print('✅ Analysis service initialized: $_analysisServiceInitialized');

      if (!_analysisServiceInitialized) {
        throw Exception('Failed to initialize analysis service');
      }

      // Step 2: Wait a moment before camera initialization
      await Future.delayed(Duration(milliseconds: 300));

      // Step 3: Initialize Camera with detailed error handling
      setState(() {
        _initializationStatus = 'Connecting to camera...';
      });

      try {
        await _cameraService.initializeCamera(widget.cameras);
        _cameraInitialized = _cameraService.isInitialized;

        print('✅ Camera initialized: $_cameraInitialized');
      } catch (e) {
        print('❌ Camera initialization error details: $e');

        // Try to provide specific error messages
        String userFriendlyError;
        if (e.toString().contains('permission')) {
          userFriendlyError =
              'Camera permission required. Please enable camera access in settings.';
        } else if (e.toString().contains('timeout')) {
          userFriendlyError =
              'Camera initialization timed out. Try restarting the app.';
        } else if (e.toString().contains('CameraAccessDenied')) {
          userFriendlyError =
              'Camera access denied. Please check app permissions.';
        } else {
          userFriendlyError = 'Camera failed to start: ${e.toString()}';
        }

        setState(() {
          _initializationStatus = 'Camera Error: $userFriendlyError';
        });

        // Show error but don't throw - let user retry
        _showErrorDialog('Camera Initialization Failed', userFriendlyError);
        return; // Don't proceed to next steps
      }

      if (!_cameraInitialized) {
        throw Exception('Camera service reports not initialized');
      }

      // Step 4: Start processing only if both are ready
      if (_cameraInitialized && _analysisServiceInitialized) {
        setState(() {
          _initializationStatus = 'Starting video analysis...';
        });

        await Future.delayed(Duration(milliseconds: 200));
        _startImageProcessing();

        setState(() {
          _initializationStatus = 'Ready!';
        });

        print('✅ All services initialized successfully');
      }
    } catch (e) {
      print('❌ Critical initialization error: $e');
      setState(() {
        _initializationStatus = 'Initialization failed: ${e.toString()}';
      });
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  void _startImageProcessing() {
    _cameraService.startImageStream();
    _imageSubscription = _cameraService.imageStream?.listen((image) {
      final now = DateTime.now();

      // SOLUTION 1: Skip frames if processing is ongoing
      if (_isProcessing) {
        _droppedFrames++;
        return; // Skip this frame
      }

      // SOLUTION 2: Throttle processing based on target FPS
      if (now.difference(_lastProcessTime) < MIN_PROCESS_INTERVAL) {
        _droppedFrames++;
        return; // Too soon, skip this frame
      }

      // SOLUTION 3: Only process if analysis service is ready
      if (!_analysisServiceInitialized || !mounted) {
        return;
      }

      _isProcessing = true;
      _lastProcessTime = now;
      _processedFrames++;
      _processFrame(image);
    });
  }

  Future<void> _processFrame(dynamic image) async {
    if (!_analysisService.isInitialized) {
      _isProcessing = false;
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Convert camera image to processable format
      final convertedImage = _convertCameraImage(image);
      if (convertedImage == null) {
        _isProcessing = false;
        return;
      }

      // Prepare resized image for action detection (as required by analyzeFrame)
      final resizedForAction = imglib.copyResize(
        convertedImage,
        width: UnifiedVideoAnalysisService.ACTION_INPUT_SIZE,
        height: UnifiedVideoAnalysisService.ACTION_INPUT_SIZE,
        interpolation: imglib.Interpolation.linear,
      );

      // SOLUTION 4: Add timeout to prevent hanging
      final result = await _analysisService
          .analyzeFrame(convertedImage, resizedForAction)
          .timeout(
            Duration(seconds: 3), // 3 second timeout
            onTimeout: () {
              print('⚠️ Analysis timeout - skipping frame');
              return null;
            },
          );

      if (result != null && mounted) {
        setState(() {
          _lastResult = result;
        });
        _updateMetrics(stopwatch.elapsed);
      }
    } catch (e) {
      print('❌ Frame processing error: $e');
    } finally {
      _isProcessing = false; // CRITICAL: Always reset processing flag
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

  // Add performance monitoring
  void _updateMetrics(Duration processingTime) {
    _frameCount++;
    _avgInferenceTime =
        (_avgInferenceTime * (_frameCount - 1) +
            processingTime.inMilliseconds) /
        _frameCount;

    final now = DateTime.now();
    if (now.difference(_lastFpsUpdate).inSeconds >= 1) {
      _fps = _processedFrames;
      _processedFrames = 0;
      _lastFpsUpdate = now;

      // Log performance stats
      print(
        '📊 FPS: $_fps, Dropped: $_droppedFrames, Avg: ${_avgInferenceTime.toInt()}ms',
      );
      _droppedFrames = 0;
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
          Positioned.fill(child: _buildCameraPreview()),

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

                Spacer(),

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
                      'Unified AI Analysis',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                // Camera Switch Button
                // IconButton(
                //   onPressed: widget.cameras.length > 1
                //       ? () => _cameraService.switchCamera()
                //       : null,
                //   icon: Icon(
                //     Icons.switch_camera,
                //     color: widget.cameras.length > 1
                //         ? Colors.white
                //         : Colors.grey,
                //   ),
                // ),
                Spacer(),
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

  Widget _buildCameraPreview() {
    if (_cameraService.controller == null ||
        !_cameraService.controller!.value.isInitialized) {
      // This will show a loading spinner or a black screen during the brief
      // moment the controller is being switched.
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(_cameraService.controller!);
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();
    _cameraService.dispose();
    _analysisService.dispose();
    super.dispose();
  }
}
