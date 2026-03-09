import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Lightweight performance monitor active only in debug mode.
/// Tracks execution time of operations for profiling large datasets.
class PerformanceMonitor {
  PerformanceMonitor._();

  static final Map<String, _OperationMetrics> _metrics = {};

  /// Measure a synchronous operation.
  static T measure<T>(String name, T Function() operation) {
    if (!kDebugMode) return operation();

    final stopwatch = Stopwatch()..start();
    final result = operation();
    stopwatch.stop();

    _record(name, stopwatch.elapsedMicroseconds);
    return result;
  }

  /// Measure an async operation.
  static Future<T> measureAsync<T>(
      String name, Future<T> Function() operation) async {
    if (!kDebugMode) return operation();

    final stopwatch = Stopwatch()..start();
    final result = await operation();
    stopwatch.stop();

    _record(name, stopwatch.elapsedMicroseconds);
    return result;
  }

  static void _record(String name, int microseconds) {
    final metrics = _metrics.putIfAbsent(name, _OperationMetrics.new);
    metrics.count++;
    metrics.totalMicroseconds += microseconds;
    if (microseconds < metrics.minMicroseconds) {
      metrics.minMicroseconds = microseconds;
    }
    if (microseconds > metrics.maxMicroseconds) {
      metrics.maxMicroseconds = microseconds;
    }

    // Log slow operations (>50ms) immediately
    if (microseconds > 50000) {
      developer.log(
        'SLOW: $name took ${(microseconds / 1000).toStringAsFixed(1)}ms',
        name: 'PerformanceMonitor',
      );
    }
  }

  /// Log a summary of all tracked operations.
  static void report() {
    if (!kDebugMode || _metrics.isEmpty) return;

    final buffer = StringBuffer('\n=== Performance Report ===\n');
    final sorted = _metrics.entries.toList()
      ..sort((a, b) =>
          b.value.totalMicroseconds.compareTo(a.value.totalMicroseconds));

    for (final entry in sorted) {
      final m = entry.value;
      final avg = m.count > 0 ? m.totalMicroseconds / m.count : 0;
      buffer.writeln(
        '${entry.key}: '
        'calls=${m.count}, '
        'avg=${(avg / 1000).toStringAsFixed(1)}ms, '
        'min=${(m.minMicroseconds / 1000).toStringAsFixed(1)}ms, '
        'max=${(m.maxMicroseconds / 1000).toStringAsFixed(1)}ms, '
        'total=${(m.totalMicroseconds / 1000).toStringAsFixed(1)}ms',
      );
    }
    buffer.writeln('===========================');

    developer.log(buffer.toString(), name: 'PerformanceMonitor');
  }

  /// Reset all metrics.
  static void reset() {
    _metrics.clear();
  }
}

class _OperationMetrics {
  int count = 0;
  int totalMicroseconds = 0;
  int minMicroseconds = 1 << 62; // large initial value
  int maxMicroseconds = 0;
}
