import 'dart:collection';

class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Queue<PerformanceMetric> _metrics = Queue();
  static const int MAX_METRICS = 100;

  void recordMetric(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    _metrics.add(metric);

    // Keep only recent metrics
    while (_metrics.length > MAX_METRICS) {
      _metrics.removeFirst();
    }

    // Log slow operations
    if (duration.inMilliseconds > 500) {
      print('🐌 SLOW OPERATION: $operation took ${duration.inMilliseconds}ms');
      if (metadata != null && metadata.isNotEmpty) {
        print('   Metadata: $metadata');
      }
    }

    // Log metrics every 10 operations
    if (_metrics.length % 10 == 0) {
      _logSummary();
    }
  }

  void _logSummary() {
    if (_metrics.isEmpty) return;

    final recentMetrics = _metrics.toList().takeLast(20);
    final operationGroups = <String, List<PerformanceMetric>>{};

    for (final metric in recentMetrics) {
      operationGroups.putIfAbsent(metric.operation, () => []).add(metric);
    }

    print('📊 === PERFORMANCE SUMMARY (Last 20 operations) ===');

    operationGroups.forEach((operation, metrics) {
      final durations = metrics.map((m) => m.duration.inMilliseconds).toList();
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      final maxDuration = durations.reduce((a, b) => a > b ? a : b);
      final minDuration = durations.reduce((a, b) => a < b ? a : b);

      print('  $operation:');
      print('    Count: ${metrics.length}');
      print(
        '    Avg: ${avgDuration.toInt()}ms, Min: ${minDuration}ms, Max: ${maxDuration}ms',
      );

      // Check for concerning patterns
      if (avgDuration > 300) {
        print('    ⚠️ SLOW AVERAGE');
      }
      if (maxDuration > 1000) {
        print('    ❌ VERY SLOW PEAK');
      }
    });
    print('================================================');
  }

  Map<String, dynamic> getStats() {
    if (_metrics.isEmpty) return {};

    final operationGroups = <String, List<PerformanceMetric>>{};
    for (final metric in _metrics) {
      operationGroups.putIfAbsent(metric.operation, () => []).add(metric);
    }

    final stats = <String, dynamic>{};

    operationGroups.forEach((operation, metrics) {
      final durations = metrics.map((m) => m.duration.inMilliseconds).toList();
      stats[operation] = {
        'count': metrics.length,
        'avg_ms': (durations.reduce((a, b) => a + b) / durations.length)
            .round(),
        'max_ms': durations.reduce((a, b) => a > b ? a : b),
        'min_ms': durations.reduce((a, b) => a < b ? a : b),
      };
    });

    return stats;
  }

  void clear() {
    _metrics.clear();
  }
}

class PerformanceMetric {
  final String operation;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  PerformanceMetric({
    required this.operation,
    required this.duration,
    required this.timestamp,
    required this.metadata,
  });
}

extension _QueueExtension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = this.toList();
    return list.length <= count ? list : list.sublist(list.length - count);
  }
}
