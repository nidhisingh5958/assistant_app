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

  Future<void> initializeCamera(List<CameraDescription> cameras) async {
    try {
      print('🚀 === DETAILED CAMERA INITIALIZATION DEBUG ===');
      print('📱 Platform: ${Platform.operatingSystem}');
      print('🔧 Flutter mode: ${kDebugMode ? 'Debug' : 'Release'}');

      // Step 1: Validate input
      print('📷 Step 1: Validating cameras input');
      print('📷 Cameras count: ${cameras.length}');

      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamerasAvailable',
          'No cameras provided to initialize',
        );
      }

      // Log each camera details
      for (int i = 0; i < cameras.length; i++) {
        final camera = cameras[i];
        print('📷 Camera $i:');
        print('   - Name: ${camera.name}');
        print('   - Direction: ${camera.lensDirection}');
        print('   - Sensor Orientation: ${camera.sensorOrientation}');
      }

      _cameras = List.from(cameras);

      // Step 2: Check permissions thoroughly
      print('🔒 Step 2: Checking permissions');
      await _checkAndRequestPermissions();

      // Step 3: Test camera availability
      print('🔍 Step 3: Testing camera availability');
      await _testCameraAvailability();

      // Step 4: Initialize controller with different strategies
      print('⚙️ Step 4: Initializing camera controller');
      await _initializeCameraControllerWithFallback();

      print('✅ Camera initialization completed successfully!');
    } catch (e, stackTrace) {
      print('❌ === CAMERA INITIALIZATION FAILED ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      await _cleanup();
      rethrow;
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      // Check camera permission
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

      // For Android, also check microphone if needed
      if (Platform.isAndroid) {
        final micStatus = await Permission.microphone.status;
        print('🎤 Microphone permission status: $micStatus');
      }
    } catch (e) {
      print('❌ Permission check failed: $e');
      rethrow;
    }
  }

  Future<void> _testCameraAvailability() async {
    try {
      print('🔍 Testing camera availability...');

      // Try to get available cameras again as a test
      final testCameras = await availableCameras();
      print('🔍 availableCameras() returned: ${testCameras.length} cameras');

      if (testCameras.length != _cameras.length) {
        print('⚠️ Warning: Camera count mismatch!');
        print(
          '⚠️ Original: ${_cameras.length}, Current: ${testCameras.length}',
        );
      }
    } catch (e) {
      print('❌ Camera availability test failed: $e');
      throw CameraException(
        'CameraAvailabilityTest',
        'Failed to verify camera availability: $e',
      );
    }
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
    print('🔧 Creating controller with:');
    print('   - Camera: ${_cameras[_currentCameraIndex].name}');
    print('   - Resolution: $resolutionPreset');
    print('   - Audio: $enableAudio');
    print('   - Format: $imageFormatGroup');

    // Clean up existing controller
    await _controller?.dispose();

    // Create new controller
    _controller = CameraController(
      _cameras[_currentCameraIndex],
      resolutionPreset,
      enableAudio: enableAudio,
      imageFormatGroup: imageFormatGroup,
    );

    print('🔧 Controller created, calling initialize()...');

    // Add timeout to initialization
    await _controller!.initialize().timeout(
      Duration(seconds: 10),
      onTimeout: () {
        throw CameraException(
          'InitializationTimeout',
          'Camera initialization timed out after 10 seconds',
        );
      },
    );

    print('🔧 Controller.initialize() completed');

    if (!_controller!.value.isInitialized) {
      throw CameraException(
        'InitializationFailed',
        'Controller reports not initialized after initialize() call',
      );
    }

    // Log success details
    final previewSize = _controller!.value.previewSize;
    print('✅ Controller initialized successfully!');
    print('📐 Preview size: ${previewSize?.width}x${previewSize?.height}');
    print('📱 Aspect ratio: ${_controller!.value.aspectRatio}');
    print('🔄 Is streaming images: ${_controller!.value.isStreamingImages}');

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
      print('🎬 Starting image stream...');
      _imageStreamController = StreamController<CameraImage>.broadcast();

      _controller!.startImageStream((CameraImage image) {
        if (!_imageStreamController!.isClosed) {
          _imageStreamController!.add(image);
        }
      });

      print('✅ Image stream started successfully');
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
