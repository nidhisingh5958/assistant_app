import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
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
  Timer? _processingTimer;

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

  // Optimized processing parameters
  static const int TARGET_PROCESSING_FPS = 5; // Reduced from 10
  static const Duration MIN_PROCESS_INTERVAL = Duration(
    milliseconds: 200,
  ); // Increased from 100ms
  static const Duration MAX_PROCESSING_TIME = Duration(
    milliseconds: 500,
  ); // Added timeout

  // Frame skipping logic
  int _frameSkipCounter = 0;
  static const int FRAME_SKIP_RATIO = 3; // Process every 3rd frame

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _analysisService = UnifiedVideoAnalysisService();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      setState(() {
        _initializationStatus = 'Loading AI models...';
      });

      // Initialize analysis service with reduced timeout
      await _analysisService.initialize().timeout(
        Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'AI model loading timed out',
          Duration(seconds: 15),
        ),
      );
      _analysisServiceInitialized = true;
      print('✅ Analysis service initialized');

      if (!_analysisServiceInitialized) {
        throw Exception('Failed to initialize analysis service');
      }

      await Future.delayed(Duration(milliseconds: 100));

      setState(() {
        _initializationStatus = 'Connecting to camera...';
      });

      try {
        await _cameraService
            .initializeCamera(widget.cameras)
            .timeout(
              Duration(seconds: 10),
              onTimeout: () => throw TimeoutException(
                'Camera initialization timed out',
                Duration(seconds: 10),
              ),
            );
        _cameraInitialized = _cameraService.isInitialized;
        print('✅ Camera initialized');
      } catch (e) {
        print('❌ Camera initialization error: $e');
        String userFriendlyError = _getUserFriendlyError(e.toString());
        setState(() {
          _initializationStatus = 'Camera Error: $userFriendlyError';
        });
        _showErrorDialog('Camera Initialization Failed', userFriendlyError);
        return;
      }

      if (!_cameraInitialized) {
        throw Exception('Camera service reports not initialized');
      }

      // Start processing with optimized settings
      if (_cameraInitialized && _analysisServiceInitialized) {
        setState(() {
          _initializationStatus = 'Starting video analysis...';
        });
        await Future.delayed(Duration(milliseconds: 100));
        _startOptimizedImageProcessing();
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

  String _getUserFriendlyError(String error) {
    if (error.contains('permission')) {
      return 'Camera permission required. Please enable camera access in settings.';
    } else if (error.contains('timeout') || error.contains('Timeout')) {
      return 'Camera initialization timed out. Try restarting the app.';
    } else if (error.contains('CameraAccessDenied')) {
      return 'Camera access denied. Please check app permissions.';
    } else {
      return 'Camera failed to start: Check if camera is being used by another app.';
    }
  }

  void _startOptimizedImageProcessing() {
    _cameraService.startImageStream();

    // Use a timer-based approach instead of listening to every frame
    _processingTimer = Timer.periodic(MIN_PROCESS_INTERVAL, (timer) {
      if (!_isProcessing && mounted && _actionDetectionEnabled) {
        _processLatestFrame();
      }
    });

    // Also listen to stream but with heavy frame skipping
    _imageSubscription = _cameraService.imageStream?.listen((image) {
      _frameCount++;

      // Skip most frames
      _frameSkipCounter++;
      if (_frameSkipCounter < FRAME_SKIP_RATIO) {
        _droppedFrames++;
        return;
      }
      _frameSkipCounter = 0;

      // Store latest frame for timer-based processing
      _latestFrame = image;

      _updateFPSMetrics();
    });
  }

  CameraImage? _latestFrame;

  void _processLatestFrame() async {
    if (_latestFrame == null ||
        _isProcessing ||
        !_analysisServiceInitialized ||
        !mounted) {
      return;
    }

    _isProcessing = true;
    final frame = _latestFrame;
    _latestFrame = null; // Clear to get fresh frame next time

    try {
      final stopwatch = Stopwatch()..start();

      // Convert with timeout
      final convertedImage = await _convertCameraImageWithTimeout(frame!);
      if (convertedImage == null || !mounted) {
        return;
      }

      // Simplified processing - only resize once
      final processingSize = 320; // Reduced from 640 for faster processing
      final resizedImage = imglib.copyResize(
        convertedImage,
        width: processingSize,
        height: processingSize,
        interpolation: imglib.Interpolation.nearest, // Faster interpolation
      );

      // Process with strict timeout
      final result = await _analysisService
          .analyzeFrame(resizedImage, resizedImage)
          .timeout(
            MAX_PROCESSING_TIME,
            onTimeout: () {
              print('⚠️ Analysis timeout - frame skipped');
              return null;
            },
          );

      if (result != null && mounted) {
        setState(() {
          _lastResult = result;
        });
        _updateInferenceMetrics(stopwatch.elapsed);
        _processedFrames++;
      }

      stopwatch.stop();
    } catch (e) {
      print('❌ Frame processing error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<imglib.Image?> _convertCameraImageWithTimeout(
    CameraImage cameraImage,
  ) async {
    try {
      return await compute(_convertCameraImageIsolate, cameraImage).timeout(
        Duration(milliseconds: 100),
        onTimeout: () {
          print('⚠️ Image conversion timeout');
          return null;
        },
      );
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  // Move heavy image conversion to isolate
  static imglib.Image? _convertCameraImageIsolate(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImageOptimized(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      }
    } catch (e) {
      print('Error in image conversion isolate: $e');
    }
    return null;
  }

  // Optimized YUV conversion
  static imglib.Image _convertYUV420ToImageOptimized(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    // Reduce resolution for faster processing
    final int scaledWidth = (width * 0.5).round();
    final int scaledHeight = (height * 0.5).round();

    final image = imglib.Image(width: scaledWidth, height: scaledHeight);

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    for (int y = 0; y < scaledHeight; y++) {
      for (int x = 0; x < scaledWidth; x++) {
        final int srcX = (x * 2).clamp(0, width - 1);
        final int srcY = (y * 2).clamp(0, height - 1);

        final int yIndex = srcY * width + srcX;
        final int uvIndex = (srcY ~/ 2) * (width ~/ 2) + (srcX ~/ 2);

        if (yIndex < yPlane.bytes.length &&
            uvIndex < uPlane.bytes.length &&
            uvIndex < vPlane.bytes.length) {
          final int yp = yPlane.bytes[yIndex];
          final int up = uPlane.bytes[uvIndex];
          final int vp = vPlane.bytes[uvIndex];

          // Simplified YUV to RGB conversion
          int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
          int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
              .round()
              .clamp(0, 255);
          int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

          image.setPixel(x, y, imglib.ColorRgb8(r, g, b));
        }
      }
    }
    return image;
  }

  static imglib.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final plane = cameraImage.planes[0];
    return imglib.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: plane.bytes.buffer,
      format: imglib.Format.uint8,
    );
  }

  void _updateInferenceMetrics(Duration processingTime) {
    _avgInferenceTime =
        (_avgInferenceTime * (_processedFrames - 1) +
            processingTime.inMilliseconds) /
        _processedFrames;
  }

  void _updateFPSMetrics() {
    final now = DateTime.now();
    if (now.difference(_lastFpsUpdate).inSeconds >= 1) {
      _fps = _frameCount;
      _frameCount = 0;
      _lastFpsUpdate = now;

      final safeAvgInference = _avgInferenceTime.isFinite
          ? _avgInferenceTime.toInt()
          : 0;
      print(
        '📊 Display FPS: $_fps, Processing: ${_processedFrames}fps, Dropped: $_droppedFrames, Avg: ${safeAvgInference}ms',
      );
      _droppedFrames = 0;
      _processedFrames = 0;
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

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
                _initializeServices();
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
                IconButton(
                  onPressed: () => setState(() => _showInfo = !_showInfo),
                  icon: Icon(
                    _showInfo ? Icons.info : Icons.info_outline,
                    color: Colors.white,
                  ),
                ),
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
                      'Optimized AI Analysis',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Container(), // Spacer
              ],
            ),
          ),

          // AI Toggle
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
                      _lastResult = null; // Clear results when disabled
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
                      _actionDetectionEnabled ? 'AI ON' : 'AI OFF',
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
                    'AI: ${_avgInferenceTime.isFinite ? _avgInferenceTime.toInt() : 0}ms',
                    style: TextStyle(
                      color: _avgInferenceTime < 300
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

          // Detection Count Badge
          if (_lastResult != null &&
              (_lastResult!.hasObjectDetections ||
                  _lastResult!.hasActionDetections))
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Text(
                  'Objects: ${_lastResult!.objectDetections.length} | Actions: ${_lastResult!.actionDetections.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
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
                  imageSize: Size(640, 480),
                  inferenceTime: _lastResult!.processingTime,
                ),
                avgInferenceTime: _avgInferenceTime,
                fps: _processedFrames,
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
                  imageSize: Size(640, 480),
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
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(_cameraService.controller!);
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _imageSubscription?.cancel();
    _cameraService.dispose();
    _analysisService.dispose();
    super.dispose();
  }
}
