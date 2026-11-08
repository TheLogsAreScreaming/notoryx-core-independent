import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/telemetry.dart' show TelemetryPoint;

/// How far back the charts reach.
enum TelemetryRange {
  day('24 h', Duration(hours: 24)),
  week('7 days', Duration(days: 7)),
  all('All', null);

  const TelemetryRange(this.label, this.span);

  final String label;
  final Duration? span;
}

/// One value over time: its name, latest value, low and high, and a line
/// chart once there are two readings.
class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({
    required this.label,
    required this.points,
    required this.format,
    super.key,
  });

  final String label;

  /// Oldest first; at least one.
  final List<TelemetryPoint> points;

  /// A value with its unit, e.g. "-112 dBm".
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((p) => p.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final last = points.last.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Text(format(last)),
              ],
            ),
            Text(
              '${points.length} reading${points.length == 1 ? '' : 's'} · '
              'low ${format(low)} · '
              'high ${format(high)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (points.length < 2)
              Text(
                'The chart appears after a second reading.',
                style: theme.textTheme.bodySmall,
              )
            else
              Semantics(
                label:
                    '$label chart, ${points.length} readings, from '
                    '${format(points.first.value)} to '
                    '${format(last)}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 96,
                    child: CustomPaint(
                      painter: _LinePainter(
                        points: points,
                        line: theme.colorScheme.primary,
                        grid: theme.colorScheme.outlineVariant,
                      ),
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

/// A plain line through the points, spaced by time, with the low and high
/// marked by faint lines top and bottom.
class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.line, required this.grid});

  final List<TelemetryPoint> points;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final start = points.first.at.millisecondsSinceEpoch;
    final span = math.max(1, points.last.at.millisecondsSinceEpoch - start);
    var low = points.first.value;
    var high = low;
    for (final p in points) {
      low = math.min(low, p.value);
      high = math.max(high, p.value);
    }
    final range = high - low == 0 ? 1.0 : high - low;
    const pad = 4.0;
    final h = size.height - pad * 2;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas
      ..drawLine(const Offset(0, pad), Offset(size.width, pad), gridPaint)
      ..drawLine(
        Offset(0, size.height - pad),
        Offset(size.width, size.height - pad),
        gridPaint,
      );

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = (p.at.millisecondsSinceEpoch - start) / span * size.width;
      final y = pad + h - (p.value - low) / range * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.line != line || old.grid != grid;
}
