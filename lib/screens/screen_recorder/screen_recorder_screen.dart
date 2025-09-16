import 'package:flutter/material.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:listen_iq/screens/screen_recorder/recording_list_screen.dart';
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.microphone.request();
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _startRecording() async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Get external storage directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String fileName = 'screen_recording_$timestamp.mp4';
        String filePath = '${directory.path}/$fileName';

        await FlutterScreenRecording.startRecordScreen(fileName);

        setState(() {
          _isRecording = true;
          _isProcessing = false;
          _recordingPath = filePath;
        });

        _pulseController.repeat(reverse: true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screen recording started!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
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

      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });

      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop recording: $e'),
          backgroundColor: Colors.red,
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
      appBar: AppBar(
        title: Text('Screen Recorder'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.video_library),
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
            colors: [Colors.blue.shade700, Colors.blue.shade900],
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
                                  Colors.blue.shade700,
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
                    ? 'Tap to stop recording'
                    : 'Tap to start recording',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),

              SizedBox(height: 60),

              // View Recordings Button
              ElevatedButton.icon(
                onPressed: _navigateToRecordings,
                icon: Icon(Icons.video_library),
                label: Text('View Recordings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
