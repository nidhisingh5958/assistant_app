import 'dart:async';
import 'dart:math' as math;
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:listen_iq/screens/voice_assistant/components/3d_mesh.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _statusController;
  late AnimationController _meshController;
  late AnimationController _textController;

  double _level = 0.0;
  bool _running = false;
  String _status = "Ask me anything";

  // Enhanced Speech-to-text functionality
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  double _confidence = 1.0;
  String _recognizedText = '';
  List<String> _words = [];
  String _lastFullText = '';
  String _lastWords = '';
  String _debugInfo = '';
  List<stt.LocaleName> _localeNames = [];
  String _currentLocaleId = '';
  Timer? _speechTimeout;
  Timer? _levelSimulationTimer;

  // Color scheme as specified
  static const Color primaryPurple = Color(0xFF662d8c);
  static const Color accentPink = Color(0xFFd4145a);
  static const Color accentYellow = Color(0xFFfbb03b);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpeech();
  }

  void _initializeAnimations() {
    try {
      _waveController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3500),
      );

      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );

      _particleController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 10000),
      );

      _statusController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );

      _meshController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 16000),
      );

      _textController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      // Start continuous animations
      _waveController.repeat();
      _particleController.repeat();
      _meshController.repeat();
    } catch (e) {
      print('Error initializing animations: $e');
    }
  }

  void _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();

      // Initialize with enhanced error handling
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          print('Speech status: $status');

          if (mounted) {
            setState(() {
              _isListening = status == 'listening';

              // Handle different status states
              switch (status) {
                case 'listening':
                  _status = "Listening... Speak now";
                  break;
                case 'notListening':
                  if (_running) {
                    _status = "Processing...";
                  }
                  break;
                case 'done':
                  _status = "Speech completed";
                  break;
              }
            });
          }
        },
        onError: (error) {
          print('Speech error: ${error.errorMsg} - ${error.permanent}');

          if (mounted) {
            setState(() {
              _isListening = false;
              _status = "Speech error: ${error.errorMsg}";
            });
          }

          // If error is permanent, try to reinitialize
          if (error.permanent) {
            Future.delayed(Duration(seconds: 2), () {
              _reinitializeSpeech();
            });
          }
        },
      );

      if (_speechAvailable) {
        // Get available locales
        _localeNames = await _speech.locales();

        // Try to find English locale or use system default
        var systemLocale = await _speech.systemLocale();
        if (systemLocale != null) {
          _currentLocaleId = systemLocale.localeId;
        } else {
          _currentLocaleId = 'en_IN'; // fallback
        }

        print('Speech initialized successfully');
        print(
          'Available locales: ${_localeNames.map((l) => l.localeId).join(', ')}',
        );
        print('Using locale: $_currentLocaleId');
      } else {
        print('Speech recognition not available');
        setState(() {
          _status = "Speech recognition not supported";
        });
      }
    } catch (e) {
      print('Error initializing speech: $e');
      setState(() {
        _speechAvailable = false;
        _status = "Speech initialization failed";
      });
    }
  }

  void _reinitializeSpeech() async {
    if (!mounted) return;

    print('Reinitializing speech recognition...');
    setState(() {
      _status = "Reinitializing speech...";
    });

    try {
      await _speech.stop();
      await Future.delayed(Duration(milliseconds: 500));
      _initializeSpeech();
    } catch (e) {
      print('Error reinitializing speech: $e');
    }
  }

  void _simulateAudioLevel() {
    _levelSimulationTimer?.cancel();
    _levelSimulationTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      if (_isListening && mounted) {
        setState(() {
          // Simulate audio level with some randomness while listening
          _level = 0.3 + (math.Random().nextDouble() * 0.4);
        });
      } else if (mounted) {
        setState(() {
          _level = math.max(0.0, _level - 0.05); // Gradually decrease
        });
        if (_level <= 0.01) {
          timer.cancel();
        }
      }
    });
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(() {
        _isListening = false;
        _status = "Speech recognition not available";
      });
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _status = "Listening... Speak now";
        _recognizedText = '';
        _words.clear();
      });

      // Start simulating audio levels
      _simulateAudioLevel();

      // Set a timeout for speech recognition
      _speechTimeout?.cancel();
      _speechTimeout = Timer(Duration(seconds: 60), () {
        if (_isListening) {
          print('Speech timeout reached');
          _stopListening();
        }
      });

      bool started = await _speech.listen(
        onResult: (val) {
          print(
            'Speech result: ${val.recognizedWords} (confidence: ${val.confidence}, final: ${val.finalResult})',
          );
          setState(() {
            _recognizedText = val.recognizedWords;
            _words = _recognizedText
                .split(" ")
                .where((word) => word.isNotEmpty)
                .toList();

            if (val.finalResult) {
              _lastFullText = _recognizedText;
              _lastWords = val.recognizedWords;
              _confidence = val.confidence;
              _status = "Got it! Processing...";
            } else {
              _status = "Listening... (${_recognizedText.length} chars)";
            }

            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
            // Show recognized text container animation
            if (_recognizedText.isNotEmpty) {
              _textController.forward();
            }
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          // Use the sound level from speech recognition for visual feedback
          if (mounted) {
            setState(() {
              _level =
                  (level + 60) / 60; // Convert dB to 0-1 range (approximate)
              _level = _level.clamp(0.0, 1.0);
            });
          }
          print('Sound level: $level -> normalized: $_level');
        },
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      if (!started) {
        print('Listen failed to start');
        setState(() {
          _isListening = false;
          _status = "Failed to start listening";
        });
        _levelSimulationTimer?.cancel();
      }
    } catch (e) {
      print('Error starting to listen: $e');
      setState(() {
        _isListening = false;
        _status = "Speech recognition started";
      });
      _levelSimulationTimer?.cancel();
    }
  }

  void _stopListening() {
    _speechTimeout?.cancel();
    _levelSimulationTimer?.cancel();

    try {
      _speech.stop();
    } catch (e) {
      print('Error stopping speech: $e');
    }

    setState(() {
      _isListening = false;
      _level = 0.0;
      if (_recognizedText.isNotEmpty) {
        _status =
            "Processing: \"${_recognizedText.length > 50 ? _recognizedText.substring(0, 50) + '...' : _recognizedText}\"";
      } else {
        _status = "No speech detected. Try again.";
      }
    });
  }

  Future<void> _toggle() async {
    if (!mounted) return;

    try {
      setState(() {
        _status = _running ? "Stopping..." : "Starting...";
      });

      _statusController.forward().then((_) {
        if (mounted) {
          _statusController.reverse();
        }
      });

      if (_running) {
        // Stop speech recognition
        _stopListening();
        _pulseController.stop();

        if (mounted) {
          setState(() {
            _status = _recognizedText.isNotEmpty
                ? "Tap mic to speak again"
                : "Press mic & start speaking...";
            _running = false;
          });
        }
      } else {
        // Start speech recognition
        if (_speechAvailable) {
          await _startListening();
        }
        _pulseController.repeat();

        if (mounted) {
          setState(() {
            _running = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error toggling recording: $e');
      if (mounted) {
        setState(() {
          _status = "Error: ${e.toString()}";
          _running = false;
        });
        _pulseController.stop();
      }
    }
  }

  void _clearText() {
    setState(() {
      _recognizedText = '';
      _lastWords = '';
      _words.clear();
      _status = "Ask me anything";
    });
    _textController.reverse();
  }

  void _testSpeech() async {
    // Test function to check speech recognition capabilities
    if (!_speechAvailable) {
      print('Speech not available for testing');
      return;
    }

    try {
      bool available = await _speech.initialize();
      print('Speech available: $available');

      var locales = await _speech.locales();
      print(
        'Available locales: ${locales.map((l) => '${l.name} (${l.localeId})').join('\n')}',
      );

      var systemLocale = await _speech.systemLocale();
      print('System locale: ${systemLocale?.name} (${systemLocale?.localeId})');

      bool hasPermission = await _speech.hasPermission;
      print('Has microphone permission: $hasPermission');
    } catch (e) {
      print('Error testing speech: $e');
    }
  }

  @override
  void dispose() {
    try {
      _speechTimeout?.cancel();
      _levelSimulationTimer?.cancel();
      _speech.stop();
      _waveController.dispose();
      _pulseController.dispose();
      _particleController.dispose();
      _statusController.dispose();
      _meshController.dispose();
      _textController.dispose();
    } catch (e) {
      print('Error disposing resources: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5 + (_level * 0.4),
            colors: [
              primaryPurple.withOpacity(0.6 + _level * 0.3),
              primaryPurple.withOpacity(0.3 + _level * 0.2),
              const Color(0xFF1a0d2e),
              Colors.black,
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Spacer(flex: 2),
              _buildMainVisualization(),
              const Spacer(flex: 1),
              _buildStatusText(),
              if (_recognizedText.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildRecognizedText(),
              ],
              // Debug info (remove in production)
              if (_debugInfo.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDebugInfo(),
              ],
              const Spacer(flex: 2),
              _buildBottomControls(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        'Debug: $_debugInfo',
        style: TextStyle(
          color: Colors.red.withOpacity(0.8),
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white70,
              size: 16,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 16),
          AnimatedContainer(
            duration: Duration(milliseconds: _running ? 100 : 300),
            width: 32 + (_running ? _level * 4 : 0),
            height: 32 + (_running ? _level * 4 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: _running
                    ? [
                        Color.lerp(primaryPurple, accentPink, _level)!,
                        Color.lerp(
                          primaryPurple.withOpacity(0.8),
                          accentYellow,
                          _level * 0.5,
                        )!,
                      ]
                    : [primaryPurple, primaryPurple.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _running && _level > 0.3
                  ? [
                      BoxShadow(
                        color: accentPink.withOpacity(_level * 0.6),
                        blurRadius: 8 + (_level * 4),
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18 + (_running ? _level * 2 : 0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Voice Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _speechAvailable ? "Ready" : "Not Available",
                      style: TextStyle(
                        color: _speechAvailable ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (_isListening) ...[
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentPink.withOpacity(
                                0.6 +
                                    0.4 *
                                        math.sin(
                                          _pulseController.value * 2 * math.pi,
                                        ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Add test button for debugging
          GestureDetector(
            onTap: _testSpeech,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.bug_report,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainVisualization() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 320 + (_running ? _level * 80 : 0),
      transform: Matrix4.identity()
        ..scale(1.0 + (_running ? _level * 0.15 : 0)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Enhanced background glow
          if (_running && _level > 0.1)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentPink.withOpacity(_level * 0.4),
                      blurRadius: 120 + (_level * 80),
                      spreadRadius: 30 + (_level * 40),
                    ),
                    BoxShadow(
                      color: primaryPurple.withOpacity(_level * 0.3),
                      blurRadius: 80 + (_level * 60),
                      spreadRadius: 20 + (_level * 30),
                    ),
                  ],
                ),
              ),
            ),

          // Main 3D Mesh Animation
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _waveController,
                _particleController,
                _meshController,
              ]),
              builder: (context, child) {
                return CustomPaint(
                  painter: Optimized3DMeshPainter(
                    waveTime: _waveController.value,
                    particleTime: _particleController.value,
                    meshTime: _meshController.value,
                    level: _level,
                    isActive: _running,
                  ),
                );
              },
            ),
          ),

          // Responsive outer rings
          if (_running)
            ...List.generate(
              2,
              (index) => AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final ringOpacity =
                      (_level * 0.5) *
                      (0.7 - index * 0.2) *
                      (0.5 +
                          0.5 *
                              math.sin(
                                _pulseController.value * 2 * math.pi +
                                    index * 0.5,
                              ));

                  return Container(
                    width: 180 + (index * 60) + (_level * 100),
                    height: 180 + (index * 60) + (_level * 100),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: index == 0
                            ? accentPink.withOpacity(ringOpacity)
                            : accentYellow.withOpacity(ringOpacity * 0.7),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedBuilder(
        animation: _statusController,
        builder: (context, child) {
          return Transform.scale(
            scale:
                1.0 +
                (_statusController.value * 0.03) +
                (_running ? _level * 0.02 : 0),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: _running
                    ? Color.lerp(
                        Colors.white.withOpacity(0.9),
                        accentPink,
                        _level * 0.4,
                      )
                    : Colors.white.withOpacity(0.9),
                fontSize: 24 + (_running ? _level * 3 : 0),
                fontWeight: FontWeight.w500,
                height: 1.3,
                shadows: _running && _level > 0.3
                    ? [
                        Shadow(
                          color: accentPink.withOpacity(_level * 0.8),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(_status, textAlign: TextAlign.center),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecognizedText() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _textController.value) * 20),
          child: Opacity(
            opacity: _textController.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentPink.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentPink.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        color: accentPink,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Recognized Speech (${(_confidence * 100).toInt()}%)",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _clearText,
                        child: Icon(
                          Icons.clear,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _recognizedText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildControlButton(
            icon: Icons.refresh,
            onTap: () {
              setState(() {
                _status = "Ask me anything";
                _recognizedText = '';
                _lastWords = '';
                _debugInfo = '';
              });
              _textController.reverse();
            },
          ),
          _buildMicrophoneButton(),
          _buildControlButton(
            icon: Icons.close,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white70, size: 24),
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return AvatarGlow(
      animate: _isListening,
      glowColor: _speechAvailable ? accentPink : Colors.red,
      duration: Duration(milliseconds: 1200),
      repeat: true,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseValue = _running ? _pulseController.value : 0.0;
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _speechAvailable
                      ? (_running
                            ? [accentPink, primaryPurple]
                            : [accentPink, const Color(0xFFff8a5b)])
                      : [Colors.grey, Colors.grey.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _speechAvailable
                        ? accentPink.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3),
                    blurRadius: 25,
                    spreadRadius: 3 + (pulseValue * 10),
                  ),
                ],
              ),
              child: Icon(
                _running ? Icons.pause : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }
}
