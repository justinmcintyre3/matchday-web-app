import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/match.dart';

/// Analog 12-hour wind clock with 30-minute increments (24 slots).
class WindClockPicker extends StatefulWidget {
  final int selectedSlot;
  final ValueChanged<int> onSelected;

  const WindClockPicker({
    super.key,
    required this.selectedSlot,
    required this.onSelected,
  });

  @override
  State<WindClockPicker> createState() => _WindClockPickerState();
}

class _WindClockPickerState extends State<WindClockPicker> {
  late int _slot;

  @override
  void initState() {
    super.initState();
    _slot = TargetArray.migrateWindClockSlot(widget.selectedSlot);
  }

  @override
  void didUpdateWidget(WindClockPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSlot != widget.selectedSlot) {
      _slot = TargetArray.migrateWindClockSlot(widget.selectedSlot);
    }
  }

  void _selectSlotFromLocalPosition(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    if (dx.abs() < 8 && dy.abs() < 8) return;

    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * math.pi;
    final slot = ((angle / (2 * math.pi)) * 24).round() % 24;
    if (slot != _slot) {
      HapticFeedback.selectionClick();
      setState(() => _slot = slot);
      widget.onSelected(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = TargetArray.formatClockSlot(_slot);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Wind from · 30 min steps',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, 280.0);
            return Center(
              child: SizedBox(
                width: size,
                height: size,
                child: GestureDetector(
                  onTapUp: (details) =>
                      _selectSlotFromLocalPosition(details.localPosition, Size(size, size)),
                  onPanUpdate: (details) =>
                      _selectSlotFromLocalPosition(details.localPosition, Size(size, size)),
                  child: CustomPaint(
                    painter: _WindClockPainter(selectedSlot: _slot),
                    size: Size(size, size),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WindClockPainter extends CustomPainter {
  final int selectedSlot;

  _WindClockPainter({required this.selectedSlot});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1E1E24)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF007AFF).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (int slot = 0; slot < 24; slot++) {
      final angle = (slot / 24) * 2 * math.pi - math.pi / 2;
      final isHour = slot % 2 == 0;
      final isSelected = slot == selectedSlot;
      final tickOuter = radius - (isSelected ? 6 : 10);
      final tickInner = radius - (isHour ? 28 : 18);

      final outer = Offset(
        center.dx + tickOuter * math.cos(angle),
        center.dy + tickOuter * math.sin(angle),
      );
      final inner = Offset(
        center.dx + tickInner * math.cos(angle),
        center.dy + tickInner * math.sin(angle),
      );

      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = isSelected
              ? const Color(0xFF00E676)
              : (isHour ? Colors.white70 : Colors.white.withValues(alpha: 0.24))
          ..strokeWidth = isSelected ? 3.5 : (isHour ? 2 : 1)
          ..strokeCap = StrokeCap.round,
      );

      if (isHour) {
        final hour = TargetArray.formatClockSlot(slot).split(':').first;
        final textRadius = radius - 42;
        final textCenter = Offset(
          center.dx + textRadius * math.cos(angle),
          center.dy + textRadius * math.sin(angle),
        );
        final painter = TextPainter(
          text: TextSpan(
            text: hour,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00E676) : Colors.white54,
              fontSize: isSelected ? 14 : 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          textCenter - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    // Hand toward selected slot (from center, wind blows FROM clock position)
    final handAngle = (selectedSlot / 24) * 2 * math.pi - math.pi / 2;
    final handEnd = Offset(
      center.dx + (radius - 36) * math.cos(handAngle),
      center.dy + (radius - 36) * math.sin(handAngle),
    );
    canvas.drawLine(
      center,
      handEnd,
      Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF007AFF));
    canvas.drawCircle(handEnd, 8, Paint()..color = const Color(0xFF00E676));
  }

  @override
  bool shouldRepaint(_WindClockPainter oldDelegate) =>
      oldDelegate.selectedSlot != selectedSlot;
}

Future<int?> showWindClockPickerDialog(
  BuildContext context, {
  required int initialSlot,
}) {
  var slot = TargetArray.migrateWindClockSlot(initialSlot);
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Wind Direction',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 300,
        child: WindClockPicker(
          selectedSlot: slot,
          onSelected: (value) => slot = value,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, slot),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
          ),
          child: const Text('Set'),
        ),
      ],
    ),
  );
}
