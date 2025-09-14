import 'package:flutter/material.dart';
import 'package:listen_iq/screens/video_assistant/detection_screen.dart';

class DetectionInfoPanel extends StatelessWidget {
  final DetectionResult result;
  final double avgInferenceTime;
  final int fps;

  const DetectionInfoPanel({
    super.key,
    required this.result,
    required this.avgInferenceTime,
    required this.fps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Object Detection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: result.detections.length > 0
                      ? Colors.green
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${result.detections.length} objects',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Performance metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('FPS', '$fps', Colors.green),
              _buildMetric(
                'Latency',
                '${avgInferenceTime.toInt()}ms',
                Colors.blue,
              ),
              _buildMetric(
                'Objects',
                '${result.detections.length}',
                Colors.orange,
              ),
              if (result.actionDetections.isNotEmpty)
                _buildMetric(
                  'Actions',
                  '${result.actionDetections.length}',
                  Colors.purple,
                ),
            ],
          ),

          if (result.detections.isNotEmpty) ...[
            SizedBox(height: 12),
            Divider(color: Colors.white24),
            SizedBox(height: 8),

            // Detected objects list
            ...result.detections
                .take(3)
                .map(
                  (detection) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: detection.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            detection.className,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        Text(
                          '${(detection.confidence * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),

            if (result.detections.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '...and ${result.detections.length - 3} more',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],

          // Summary of total detections including actions
          if (result.actionDetections.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, color: Colors.white70, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Total: ${result.totalDetectionCount} detections (${result.detectionCount} objects, ${result.actionCount} actions)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
