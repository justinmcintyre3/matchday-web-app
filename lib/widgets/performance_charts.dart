import 'dart:math';
import 'package:flutter/material.dart';

class ChartSegment {
  final double value;
  final Color color;
  final String label;

  ChartSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class MatchdayDonutChart extends StatelessWidget {
  final List<ChartSegment> segments;
  final String centerLabel;
  final String centerSubLabel;
  final double size;

  const MatchdayDonutChart({
    super.key,
    required this.segments,
    this.centerLabel = '',
    this.centerSubLabel = '',
    this.size = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (sum, seg) => sum + seg.value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Chart
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _DonutChartPainter(segments: segments, total: total),
              ),
              if (centerLabel.isNotEmpty || centerSubLabel.isNotEmpty)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (centerLabel.isNotEmpty)
                      Text(
                        centerLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    if (centerSubLabel.isNotEmpty)
                      Text(
                        centerSubLabel,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white38,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: segments.map((seg) {
              final pct = total > 0 ? (seg.value / total * 100).toStringAsFixed(0) : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: seg.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        seg.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${seg.value.toInt()} ($pct%)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<ChartSegment> segments;
  final double total;

  _DonutChartPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.35;
    final drawRadius = radius - strokeWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      // Draw a grey circle if no data
      paint.color = Colors.grey.withValues(alpha: 0.1);
      canvas.drawCircle(center, drawRadius, paint);
      return;
    }

    double startAngle = -pi / 2;

    for (final seg in segments) {
      if (seg.value == 0) continue;
      final sweepAngle = (seg.value / total) * 2 * pi;
      paint.color = seg.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: drawRadius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
