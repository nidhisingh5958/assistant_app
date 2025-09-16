import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class RecordingOverlay {
  static OverlaySupportEntry? _currentOverlay;

  static void show(VoidCallback onStop) {
    _currentOverlay = showOverlayNotification(
      (context) => _RecordingOverlayWidget(onStop: onStop),
      duration: Duration.zero,
      position: NotificationPosition.top,
    );
  }

  static void hide() {
    _currentOverlay?.dismiss();
    _currentOverlay = null;
  }
}

class _RecordingOverlayWidget extends StatefulWidget {
  final VoidCallback onStop;

  const _RecordingOverlayWidget({required this.onStop});

  @override
  State<_RecordingOverlayWidget> createState() =>
      _RecordingOverlayWidgetState();
}

class _RecordingOverlayWidgetState extends State<_RecordingOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_animation.value),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            SizedBox(width: 12),
            Text(
              'Recording...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: widget.onStop,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  'STOP',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
