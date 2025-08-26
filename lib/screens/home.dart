import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/screens/components/colors.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:listen_iq/screens/components/sidemenu.dart';
import 'package:listen_iq/services/router_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AnimationController? _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController?.dispose();
    super.dispose();
  }

  // Helper method to ensure drawer is closed before navigation
  void _navigateAndCloseDrawer(String routeName) {
    // Close drawer if it's open
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop(); // Close the drawer
    }

    // Add a small delay to ensure drawer is fully closed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        context.goNamed(routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      body: Stack(
        children: [
          // Gradient Blobs
          Positioned(
            top: -100,
            left: -80,
            child: _buildBlob(const [
              Color(0xFFd4145a),
              Color(0xFFfbb03b),
            ], 300),
          ),

          // Blur Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 150, sigmaY: 150),
            child: Container(color: black.withOpacity(0.25)),
          ),

          // Wave Transition behind app bar
          if (_waveController != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _waveController!,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WavePainter(
                      animationValue: _waveController!.value,
                      gradientColors: [
                        const Color(0xFFd4145a).withOpacity(0.3),
                        const Color(0xFF662d8c).withOpacity(0.4),
                        const Color(0xFFfbb03b).withOpacity(0.2),
                      ],
                    ),
                    size: Size(MediaQuery.of(context).size.width, 200),
                  );
                },
              ),
            ),

          // Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Use the scaffold key to open drawer
                          _scaffoldKey.currentState?.openDrawer();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFd4145a),
                                Color(0xFF662d8c),
                                Color(0xFFfbb03b),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          "ListenIQ",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Hero Text
                  const Text(
                    'Ask, recall,\nbe aware',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: white,
                      height: 1.1,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Search Bar
                  GestureDetector(
                    onTap: () {
                      // Always close the drawer before navigating
                      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                        Navigator.of(context).pop();
                        Future.delayed(const Duration(milliseconds: 150), () {
                          if (mounted) {
                            context.goNamed(RouteConstants.chatHome);
                          }
                        });
                      } else {
                        context.goNamed(RouteConstants.chatHome);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Search...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _navigateAndCloseDrawer(
                                RouteConstants.voiceAssistant,
                              );
                            },
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // AI Tools Grid
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildAIToolCard(
                          'AI audio\nservice',
                          Icons.edit_outlined,
                          onTap: () {
                            context.goNamed(RouteConstants.voiceAssistant);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildAIToolCard(
                          'AI video\nservice',
                          Icons.image_outlined,
                          onTap: () {
                            // context.goNamed(RouteConstants.videoAssistant);
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildAIToolCard(
                          'AI\nscreen recorder',
                          Icons.auto_awesome_outlined,
                          onTap: () {
                            // context.goNamed(RouteConstants.screenAssistant);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // History Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _navigateAndCloseDrawer(RouteConstants.history);
                        },
                        child: Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // History Items
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildHistoryItem(
                          'Code tutor',
                          'How to use Visual Studio',
                          Icons.code,
                          const Color(0xFFEC4899),
                        ),
                        _buildHistoryItem(
                          'Text writer',
                          'Healthy eating tips',
                          Icons.edit,
                          const Color(0xFF8B5CF6),
                        ),
                        _buildHistoryItem(
                          'Image generator',
                          'Dog in red plaid in house in winter',
                          Icons.image,
                          const Color(0xFFF59E0B),
                        ),
                        _buildHistoryItem(
                          'Text writer',
                          'Best clothing combinations',
                          Icons.edit,
                          const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(List<Color> colors, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          center: Alignment.center,
          radius: 0.7,
        ),
      ),
    );
  }

  Widget _buildAIToolCard(String title, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.arrow_outward,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: () {
        // Handle history item tap - you can add specific routes here
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Keep your existing WavePainter class unchanged
class WavePainter extends CustomPainter {
  final double animationValue;
  final List<Color> gradientColors;

  WavePainter({required this.animationValue, required this.gradientColors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, 0);
    path.lineTo(0, size.height * 0.6);

    for (int i = 0; i < 1; i++) {
      final waveHeight = 20 + (i * 20);
      final frequency = 0.02 + (i * 0.01);
      final phaseShift = animationValue * 2 * math.pi + (i * math.pi / 3);

      for (double x = 0; x <= size.width; x += 1) {
        final y =
            size.height * 0.6 +
            waveHeight * math.sin((x * frequency) + phaseShift) +
            (waveHeight / 2) * math.cos((x * frequency * 2) + phaseShift);

        if (x == 0) {
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
