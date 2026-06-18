import 'package:flutter/material.dart';

import '../core/timetable_layout.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Hour label + dashed gridline for the timetable left rail.
class TimetableHourRail extends StatelessWidget {
  const TimetableHourRail({super.key, required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final label = hour.toString().padLeft(2, '0');
    // One-pixel anchor on the hour boundary; label centered on the line via
    // translate (matches web `.tt__hour span { transform: translateY(-50%) }`).
    return SizedBox(
      height: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: TimetableLayout.railWidth,
            right: 0,
            top: 0,
            height: 1,
            child: CustomPaint(
              painter: _DashedLinePainter(T.line),
              size: const Size(double.infinity, 1),
            ),
          ),
          Positioned(
            top: 0,
            width: TimetableLayout.railWidth,
            child: Transform.translate(
              offset: const Offset(0, -7),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: AppText.mono(size: T.fs12, color: T.ink3, height: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
