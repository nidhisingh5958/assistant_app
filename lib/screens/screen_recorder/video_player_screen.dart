import 'package:flutter/material.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String videoTitle;

  const VideoPlayerScreen({
    Key? key,
    required this.videoPath,
    required this.videoTitle,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));

    try {
      await _controller.initialize();
      setState(() {
        _duration = _controller.value.duration;
        _isInitialized = true;
      });

      _controller.addListener(() {
        setState(() {
          _position = _controller.value.position;
          _isPlaying = _controller.value.isPlaying;
        });
      });
    } catch (e) {
      print('Video player initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load video: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    String seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppHeader(
        title: widget.videoTitle,
        isInChat: true,
        onBackPressed: () => Navigator.pop(context),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isInitialized
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Stack(
                children: [
                  // Video Player
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),

                  // Controls Overlay
                  if (_showControls)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Rewind 10s
                                  IconButton(
                                    onPressed: () {
                                      final newPosition =
                                          _position - Duration(seconds: 10);
                                      _seekTo(
                                        newPosition < Duration.zero
                                            ? Duration.zero
                                            : newPosition,
                                      );
                                    },
                                    icon: Icon(
                                      Icons.replay_10,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),

                                  // Play/Pause
                                  IconButton(
                                    onPressed: _togglePlayPause,
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),

                                  // Forward 10s
                                  IconButton(
                                    onPressed: () {
                                      final newPosition =
                                          _position + Duration(seconds: 10);
                                      _seekTo(
                                        newPosition > _duration
                                            ? _duration
                                            : newPosition,
                                      );
                                    },
                                    icon: Icon(
                                      Icons.forward_10,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Progress Bar and Time
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              children: [
                                // Progress Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.red,
                                    inactiveTrackColor: Colors.grey,
                                    thumbColor: Colors.red,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 8.0,
                                    ),
                                    trackHeight: 4.0,
                                  ),
                                  child: Slider(
                                    value: _position.inMilliseconds.toDouble(),
                                    max: _duration.inMilliseconds.toDouble(),
                                    onChanged: (value) {
                                      _seekTo(
                                        Duration(milliseconds: value.toInt()),
                                      );
                                    },
                                  ),
                                ),

                                // Time Display
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(_position),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(_duration),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
    );
  }
}
