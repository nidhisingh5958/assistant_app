import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:listen_iq/utilities/app_initialization.dart';
import 'package:listen_iq/utilities/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitialization.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ListenIQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
      ),
      routerConfig: router,

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}

class AppConfig {
  static const bool ENABLE_ACTION_DETECTION = true;
  static const bool ENABLE_FUSION_MODEL = false; // Disable to reduce load
  static const int TARGET_PROCESSING_FPS = 30;
  static const Duration PROCESSING_TIMEOUT = Duration(milliseconds: 300);

  // Camera settings optimized for AI processing
  static const ResolutionPreset CAMERA_RESOLUTION = ResolutionPreset.medium;
  static const ImageFormatGroup? IMAGE_FORMAT = null; // Let system choose
}
