import 'package:flutter/material.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';
import 'package:listen_iq/services/video/models/action_detector.dart';

class ActionInfoPanel extends StatefulWidget {
  final DetectionResult result;
  final double avgActionInferenceTime;
  final bool isActionDetectionActive;

  const ActionInfoPanel({
    super.key,
    required this.result,
    required this.avgActionInferenceTime,
    required this.isActionDetectionActive,
  });

  @override
  State<ActionInfoPanel> createState() => _ActionInfoPanelState();
}

class _ActionInfoPanelState extends State<ActionInfoPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(ActionInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result.actionDetections.length !=
        oldWidget.result.actionDetections.length) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActionDetectionActive ||
        widget.result.actionDetections.isEmpty) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade900.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.shade300.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.shade900.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildMetrics(),
              if (widget.result.actionDetections.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.purple),
                const SizedBox(height: 8),
                _buildActionsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_martial_arts,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Real-time Activity Recognition',
                  style: TextStyle(color: Colors.purple.shade200, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final actionCount = widget.result.actionDetections.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: actionCount > 0 ? Colors.green.shade700 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (actionCount > 0 ? Colors.green : Colors.orange).withOpacity(
              0.3,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            actionCount > 0 ? Icons.check_circle : Icons.search,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            actionCount > 0 ? '$actionCount actions' : 'Analyzing',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final primaryAction = widget.result.primaryAction;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetric(
          'Latency',
          '${widget.avgActionInferenceTime.toInt()}ms',
          Colors.cyan,
          Icons.timer,
        ),
        _buildMetric(
          'Actions',
          '${widget.result.actionDetections.length}',
          Colors.orange,
          Icons.visibility,
        ),
        if (primaryAction != null)
          _buildMetric(
            'Confidence',
            '${(primaryAction.confidence * 100).toInt()}%',
            Colors.green,
            Icons.trending_up,
          ),
        _buildMetric(
          'FPS Impact',
          _calculateFPSImpact(),
          _getFPSImpactColor(),
          Icons.speed,
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildActionsList() {
    final topActions = widget.result.actionDetections.take(3).toList();

    return Column(
      children: [
        ...topActions.map((action) => _buildActionItem(action)).toList(),
        if (widget.result.actionDetections.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '...and ${widget.result.actionDetections.length - 3} more actions',
              style: TextStyle(
                color: Colors.purple.shade300,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionItem(ActionDetection action) {
    final isPrimary = action == widget.result.primaryAction;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.purple.shade700.withOpacity(0.6)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isPrimary
            ? Border.all(color: Colors.purple.shade300, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: action.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: action.color.withOpacity(0.5),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      action.actionName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: isPrimary
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Detected ${DateTime.now().difference(action.timestamp).inSeconds}s ago',
                  style: TextStyle(color: Colors.purple.shade300, fontSize: 10),
                ),
              ],
            ),
          ),
          _buildConfidenceBar(action.confidence),
          const SizedBox(width: 8),
          Text(
            '${(action.confidence * 100).toInt()}%',
            style: TextStyle(
              color: _getConfidenceColor(action.confidence),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    return Container(
      width: 40,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: confidence,
        child: Container(
          decoration: BoxDecoration(
            color: _getConfidenceColor(confidence),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _calculateFPSImpact() {
    if (widget.avgActionInferenceTime < 50) return 'Low';
    if (widget.avgActionInferenceTime < 100) return 'Med';
    return 'High';
  }

  Color _getFPSImpactColor() {
    if (widget.avgActionInferenceTime < 50) return Colors.green;
    if (widget.avgActionInferenceTime < 100) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
