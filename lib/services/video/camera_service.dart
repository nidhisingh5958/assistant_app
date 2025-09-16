import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  StreamController<CameraImage>? _imageStreamController;
  bool _isInitialized = false;
  int _currentCameraIndex = 0;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  Stream<CameraImage>? get imageStream => _imageStreamController?.stream;
  bool get isInitialized => _isInitialized;

  // Performance optimizations
  DateTime _lastFrameTime = DateTime.now();
  int _frameSkipCount = 0;
  static const int FRAME_SKIP_THRESHOLD = 2; // Skip every 2nd frame

  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    try {
      print('🚀 Starting optimized camera initialization...');
      print('📱 Platform: ${Platform.operatingSystem}');

      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamerasAvailable',
          'No cameras provided to initialize',
        );
      }

      _cameras = List.from(cameras);
      print('📷 Available cameras: ${_cameras.length}');

      // Log camera details
      for (int i = 0; i < _cameras.length; i++) {
        final camera = _cameras[i];
        print('📷 Camera $i: ${camera.name} (${camera.lensDirection})');
      }

      // Check permissions first
      await _checkAndRequestPermissions();
      print('✅ Permissions granted');

      // Test camera availability
      await _testCameraAvailability();
      print('✅ Camera availability confirmed');

      // Initialize with optimized settings
      await _initializeCameraWithOptimizedSettings();
      print('✅ Camera initialization completed successfully!');
    } catch (e, stackTrace) {
      print('❌ Camera initialization failed: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      await _cleanup();
      rethrow;
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    var cameraStatus = await Permission.camera.status;
    print('📋 Camera permission status: $cameraStatus');

    if (!cameraStatus.isGranted) {
      print('📋 Requesting camera permission...');
      cameraStatus = await Permission.camera.request();
      print('📋 Camera permission after request: $cameraStatus');

      if (!cameraStatus.isGranted) {
        if (cameraStatus.isPermanentlyDenied) {
          throw CameraException(
            'CameraPermissionPermanentlyDenied',
            'Camera permission permanently denied. Please enable it in app settings.',
          );
        } else {
          throw CameraException(
            'CameraPermissionDenied',
            'Camera permission denied',
          );
        }
      }
    }
  }

  Future<void> _testCameraAvailability() async {
    try {
      final testCameras = await availableCameras();
      print('🔍 Camera availability test: ${testCameras.length} cameras found');

      if (testCameras.isEmpty) {
        throw CameraException(
          'NoCamerasFound',
          'No cameras available on this device',
        );
      }

      if (testCameras.length != _cameras.length) {
        print('⚠️ Warning: Camera count mismatch!');
        print('⚠️ Expected: ${_cameras.length}, Found: ${testCameras.length}');
        _cameras = testCameras; // Use the fresh camera list
      }
    } catch (e) {
      throw CameraException(
        'CameraAvailabilityTest',
        'Failed to verify camera availability: $e',
      );
    }
  }

  Future<void> _initializeCameraWithOptimizedSettings() async {
    final strategies = [
      () => _createAndInitializeController(
        resolutionPreset: ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      ),
      () => _createAndInitializeController(
        resolutionPreset: ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      ),
      () => _createAndInitializeController(
        resolutionPreset: ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: null,
      ),
      () => _createAndInitializeController(
        resolutionPreset: ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: null,
      ),
    ];

    Exception? lastError;

    for (int i = 0; i < strategies.length; i++) {
      try {
        print(
          '🔧 Trying initialization strategy ${i + 1}/${strategies.length}',
        );
        await strategies[i]();
        print('✅ Strategy ${i + 1} succeeded!');
        return;
      } catch (e) {
        print('❌ Strategy ${i + 1} failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        await _cleanup();

        // Wait a bit before trying next strategy
        if (i < strategies.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    throw lastError ??
        CameraException(
          'AllStrategiesFailed',
          'All initialization strategies failed',
        );
  }

  Future<void> _initializeCameraControllerWithFallback() async {
    // Try different initialization strategies
    final strategies = [
      _initializeWithHighResolution,
      _initializeWithMediumResolution,
      _initializeWithLowResolution,
      _initializeWithBasicSettings,
    ];

    Exception? lastError;

    for (int i = 0; i < strategies.length; i++) {
      try {
        print(
          '🔧 Trying initialization strategy ${i + 1}/${strategies.length}',
        );
        await strategies[i]();
        print('✅ Strategy ${i + 1} succeeded!');
        return;
      } catch (e) {
        print('❌ Strategy ${i + 1} failed: $e');
        lastError = e is Exception ? e : Exception(e.toString());
        await _cleanup();

        // Wait a bit before trying next strategy
        if (i < strategies.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
    }

    throw lastError ??
        CameraException(
          'AllStrategiesFailed',
          'All initialization strategies failed',
        );
  }

  Future<void> _initializeWithHighResolution() async {
    print('📐 Trying high resolution initialization...');
    await _createAndInitializeController(
      resolutionPreset: ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
  }

  Future<void> _initializeWithMediumResolution() async {
    print('📐 Trying medium resolution initialization...');
    await _createAndInitializeController(
      resolutionPreset: ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
  }

  Future<void> _initializeWithLowResolution() async {
    print('📐 Trying low resolution initialization...');
    await _createAndInitializeController(
      resolutionPreset: ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: null, // Let system decide
    );
  }

  Future<void> _initializeWithBasicSettings() async {
    print('📐 Trying basic initialization...');
    await _createAndInitializeController(
      resolutionPreset: ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: null,
    );
  }

  Future<void> _createAndInitializeController({
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    ImageFormatGroup? imageFormatGroup,
  }) async {
    print('🔧 Creating controller with buffer management...');

    await _controller?.dispose();

    // SOLUTION: Use lower resolution for heavy processing
    final effectiveResolution = resolutionPreset == ResolutionPreset.high
        ? ResolutionPreset.medium
        : resolutionPreset;

    _controller = CameraController(
      _cameras[_currentCameraIndex],
      effectiveResolution, // Use reduced resolution
      enableAudio: enableAudio,
      imageFormatGroup: imageFormatGroup,
    );

    await _controller!.initialize().timeout(
      Duration(seconds: 10),
      onTimeout: () {
        throw CameraException('InitializationTimeout', 'Camera timed out');
      },
    );

    if (!_controller!.value.isInitialized) {
      throw CameraException(
        'InitializationFailed',
        'Controller not initialized',
      );
    }

    _isInitialized = true;
  }

  Future<void> _cleanup() async {
    try {
      await _controller?.dispose();
      _controller = null;
      _isInitialized = false;
    } catch (e) {
      print('⚠️ Error during cleanup: $e');
    }
  }

  void startImageStream() {
    if (!_isInitialized || _controller == null) {
      print('❌ Cannot start image stream: camera not initialized');
      return;
    }

    try {
      print('🎬 Starting optimized image stream...');
      _imageStreamController = StreamController<CameraImage>.broadcast();

      // Throttle to target FPS
      DateTime _lastFrameTime = DateTime.now();
      const int targetFps = 10;
      const Duration minInterval = Duration(milliseconds: 1000 ~/ targetFps);

      bool _isProcessing = false;

      _controller!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        if (_isProcessing) {
          // Drop frame if still processing previous
          return;
        }
        if (now.difference(_lastFrameTime) < minInterval) {
          // Throttle frame rate
          return;
        }
        _lastFrameTime = now;
        _isProcessing = true;

        if (!_imageStreamController!.isClosed &&
            _imageStreamController!.hasListener) {
          _imageStreamController!.add(image);
        }

        // Reset processing flag after frame is handled externally
        Future.delayed(minInterval, () {
          _isProcessing = false;
        });
      });

      print('✅ Optimized image stream started');
    } catch (e) {
      print('❌ Failed to start image stream: $e');
      rethrow;
    }
  }

  void stopImageStream() {
    try {
      print('🛑 Stopping image stream...');
      _controller?.stopImageStream();
      _imageStreamController?.close();
      _imageStreamController = null;
      print('✅ Image stream stopped');
    } catch (e) {
      print('❌ Error stopping image stream: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length <= 1) {
      print('📷 Only one camera available, cannot switch');
      return;
    }

    try {
      print('🔄 Switching camera...');
      stopImageStream();
      await _cleanup();
      _controller =
          null; // 👈 Add this line to immediately clear the reference.

      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      print(
        '🔄 Switching to camera $_currentCameraIndex: ${_cameras[_currentCameraIndex].name}',
      );

      await _initializeCameraControllerWithFallback();
      startImageStream();

      print('✅ Camera switched successfully');
    } catch (e) {
      print('❌ Failed to switch camera: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      print('🗑️ Disposing camera service...');
      stopImageStream();
      await _cleanup();
      print('✅ Camera service disposed successfully');
    } catch (e) {
      print('❌ Error disposing camera service: $e');
    }
  }
}
