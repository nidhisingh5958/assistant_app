import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:listen_iq/screens/screen_recorder/recording_list_screen.dart';
import 'package:listen_iq/screens/screen_recorder/recording_overlay.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ScreenRecorderScreen extends StatefulWidget {
  @override
  _ScreenRecorderScreenState createState() => _ScreenRecorderScreenState();
}

class _ScreenRecorderScreenState extends State<ScreenRecorderScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordingPath;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _recordingsPath = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _requestPermissions();
    _initializeRecordingsPath();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeRecordingsPath() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        // Try to use external storage first, then fall back to app directory
        try {
          directory = Directory('/storage/emulated/0/Movies/ScreenRecordings');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          // Test if we can write to this directory
          await directory.list().toList();
        } catch (e) {
          print(
            'Cannot access /storage/emulated/0/Movies/ScreenRecordings: $e',
          );
          // Fall back to external storage directory
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            directory = Directory('${directory.path}/ScreenRecordings');
            if (!await directory.exists()) {
              await directory.create(recursive: true);
            }
          }
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        setState(() {
          _recordingsPath = directory!.path;
        });
        print('Recordings will be saved to: ${directory.path}');
      }
    } catch (e) {
      print('Error setting up recordings directory: $e');
      // Final fallback to app documents directory
      try {
        Directory fallbackDir = await getApplicationDocumentsDirectory();
        setState(() {
          _recordingsPath = fallbackDir.path;
        });
      } catch (e2) {
        print('Final fallback directory also failed: $e2');
      }
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.storage,
      Permission.microphone,
      Permission.manageExternalStorage,
    ].request();

    print('Permission statuses: $permissions');

    // For Android 11+, we might need to request MANAGE_EXTERNAL_STORAGE
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      print('Starting screen recording...');

      if (_recordingsPath.isEmpty) {
        await _initializeRecordingsPath();
      }

      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'screen_recording_$timestamp.mp4';

      // Start recording with the filename
      bool started = await FlutterScreenRecording.startRecordScreen(fileName);

      if (started) {
        setState(() {
          _isRecording = true;
          _isProcessing = false;
          _recordingPath = '$_recordingsPath/$fileName';
        });

        _pulseController.repeat(reverse: true);

        // Show recording overlay
        RecordingOverlay.show(() {
          _stopRecording();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screen recording started!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording. Check permissions.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      print('Recording error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      String? path = await FlutterScreenRecording.stopRecordScreen;

      _pulseController.stop();
      _pulseController.reset();

      // Hide recording overlay
      RecordingOverlay.hide();

      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });

      print('Recording stopped, path: $path');

      if (path != null && path.isNotEmpty) {
        // Check if file exists
        File recordedFile = File(path);
        if (await recordedFile.exists()) {
          print('File exists at: $path');
          print('File size: ${await recordedFile.length()} bytes');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recording saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => _navigateToRecordings(),
              ),
            ),
          );
        } else {
          print('File does not exist at expected path');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recording completed but file not found at expected location',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Check Gallery',
                textColor: Colors.white,
                onPressed: () => _navigateToRecordings(),
              ),
            ),
          );
        }
      } else {
        print('No path returned from recording');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording completed. Check your gallery or recordings folder.',
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Browse',
              textColor: Colors.white,
              onPressed: () => _navigateToRecordings(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
      print('Stop recording error: $e');
      RecordingOverlay.hide();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToRecordings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecordingsListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Screen Recorder',
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.video_library, color: Colors.white),
            onPressed: _navigateToRecordings,
            tooltip: 'View Recordings',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade900, Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Text
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Text(
                  _isRecording
                      ? 'Recording in progress...'
                      : _isProcessing
                      ? 'Processing...'
                      : 'Ready to record',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(height: 60),

              // Recording Button
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isRecording ? _pulseAnimation.value : 1.0,
                    child: GestureDetector(
                      onTap: _isProcessing
                          ? null
                          : (_isRecording ? _stopRecording : _startRecording),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.red : Colors.white)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade700,
                                ),
                              )
                            : Icon(
                                _isRecording
                                    ? Icons.stop
                                    : Icons.fiber_manual_record,
                                size: 50,
                                color: _isRecording ? Colors.white : Colors.red,
                              ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 30),

              // Action Text
              Text(
                _isRecording
                    ? 'Recording... Use notification to stop'
                    : 'Tap to start recording',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 60),

              // View Recordings Button
              ElevatedButton.icon(
                onPressed: _navigateToRecordings,
                icon: Icon(Icons.video_library),
                label: Text('View Recordings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey.shade800,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Debug info
              if (_recordingsPath.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Save location: $_recordingsPath',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
