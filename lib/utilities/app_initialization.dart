import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted;
  }

  static Future<void> requestAllPermissions() async {
    await [Permission.camera, Permission.storage].request();
  }
}

class VideoDetectionService {
  static Future<bool> checkServiceHealth() async {
    // Add your service health check logic here
    return true;
  }
}

class AppInitialization {
  static List<CameraDescription>? cameras;
  static bool _initialized = false;

  static Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize cameras
      cameras = await availableCameras();

      // Check and request permissions
      final hasCamera = await PermissionHelper.hasCameraPermission();
      final hasStorage = await PermissionHelper.hasStoragePermission();

      if (!hasCamera || !hasStorage) {
        await PermissionHelper.requestAllPermissions();
      }

      // Check backend service health
      final serviceHealthy = await VideoDetectionService.checkServiceHealth();

      _initialized = true;
      return serviceHealthy;
    } catch (e) {
      debugPrint('Initialization error: $e');
      return false;
    }
  }

  static bool get isInitialized => _initialized;
}
