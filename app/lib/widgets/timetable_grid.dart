import 'package:flutter/material.dart';

import '../core/clashes.dart';
import '../models/plan.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

const int _startHour = 7;
const int _endHour = 21;
const double _rowHeight = 58;
const double _railWidth = 40;
const double _headerHeight = 26;

const Map<String, int> _dayIndex = {
  'Monday': 0,
  'Tuesday': 1,
  'Wednesday': 2,
  'Thursday': 3,
  'Friday': 4,
};
const List<String> _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI'];

/// The weekly timetable board. Mirrors the web TimetableGrid: a mono hour rail
/// (7 AM–9 PM), five day columns, solid session-tinted blocks positioned
/// absolutely, and a diagonal hatch + red border for conflicts.
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.courses,
    required this.timetableData,
  });

  final List<SelectedCourse> courses;
  final Map<String, CourseTimetable> timetableData;

  double _hourOffset(String start) {
    final hour = int.parse(start.substring(0, 2));
    final minute = int.parse(start.substring(2, 4));
    return (hour - _startHour) + minute / 60.0;
  }

  double _duration(String start, String end) {
    final sh = int.parse(start.substring(0, 2));
    final sm = int.parse(start.substring(2, 4));
    final eh = int.parse(end.substring(0, 2));
    final em = int.parse(end.substring(2, 4));
    return (eh - sh) + (em - sm) / 60.0;
  }

  /// Drop leading zero on the hour so "09:30" → "9:30" — saves width in narrow columns.
  static String _formatTime(String hhmm) {
    final hour = int.parse(hhmm.substring(0, 2));
    final minute = hhmm.substring(2, 4);
    return '$hour:$minute';
  }

  static Widget _fittedLine(String text, TextStyle style) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = flattenSessions(courses, timetableData);
    final conflicts = conflictIndices(sessions);
    final hourCount = _endHour - _startHour; // 14
    final plotHeight = hourCount * _rowHeight;

    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.rLg),
        boxShadow: [BoxShadow(color: T.shadowCard, blurRadius: 2, offset: const Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Day header row.
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                SizedBox(width: _railWidth),
                for (final d in _dayLabels)
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: T.line)),
                      ),
                      child: Text(d,
                          style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1)),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: T.line),
          SizedBox(
            height: plotHeight,
            child: LayoutBuilder(builder: (context, constraints) {
              final dayAreaWidth = constraints.maxWidth - _railWidth;
              final colWidth = dayAreaWidth / 5;
              return Stack(
                children: [
                  // Hour gridlines + labels.
                  for (int h = _startHour; h <= _endHour; h++)
                    Positioned(
                      top: (h - _startHour) * _rowHeight,
                      left: 0,
                      right: 0,
                      child: _HourLine(hour: h),
                    ),
                  // Column separators.
                  for (int i = 0; i < 5; i++)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: _railWidth + i * colWidth,
                      child: Container(width: 1, color: T.line),
                    ),
                  // Session blocks.
                  for (int i = 0; i < sessions.length; i++)
                    _buildBlock(sessions[i], i, conflicts.contains(i), colWidth),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(GridSession s, int index, bool conflict, double colWidth) {
    final dayIdx = _dayIndex[s.day];
    if (dayIdx == null) return const SizedBox.shrink();
    final top = _hourOffset(s.start) * _rowHeight;
    final span = _duration(s.start, s.end);
    final height = (span * _rowHeight).clamp(20.0, plotHeightMax);
    final compact = span < 0.75;

    Color tint, edge, ink;
    switch (s.type) {
      case 'Tutorial':
        tint = T.tutorialTint;
        edge = T.tutorialEdge;
        ink = T.tutorialInk;
        break;
      case 'Lab':
        tint = T.labTint;
        edge = T.labEdge;
        ink = T.labInk;
        break;
      default:
        tint = T.lectureTint;
        edge = T.lectureEdge;
        ink = T.lectureInk;
    }

    final start = _formatTime(s.start);
    final end = _formatTime(s.end);

    return Positioned(
      top: top + 1,
      left: _railWidth + dayIdx * colWidth + 1.5,
      width: colWidth - 3,
      height: height - 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: tint,
          border: Border.all(color: conflict ? T.danger : edge, width: conflict ? 1.5 : 1),
          borderRadius: BorderRadius.circular(T.rSm),
        ),
        foregroundDecoration: conflict
            ? const DiagonalHatch()
            : null,
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fittedLine(
                s.courseCode,
                AppText.mono(size: T.fs12, weight: FontWeight.w600, color: ink),
              ),
              if (!compact)
                _fittedLine(
                  s.type,
                  AppText.sans(size: 9, color: ink),
                ),
              if (!compact)
                _fittedLine(
                  '$start–$end',
                  AppText.mono(size: 10, color: ink),
                ),
              if (!compact && s.location.isNotEmpty)
                _fittedLine(
                  s.location,
                  AppText.mono(size: 9, color: ink),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const double plotHeightMax = (21 - 7) * _rowHeight;
}

class _HourLine extends StatelessWidget {
  const _HourLine({required this.hour});
  final int hour;

  @override
  Widget build(BuildContext context) {
    final label = hour <= 12 ? '$hour' : '${hour - 12}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _railWidth,
          child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 0),
            child: Text(label,
                textAlign: TextAlign.right,
                style: AppText.mono(size: T.fs12, color: T.ink3)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: CustomPaint(painter: _DashedLinePainter(), size: const Size(double.infinity, 1)),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = T.line
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Diagonal hatch overlay drawn over conflicting blocks.
class DiagonalHatch extends Decoration {
  const DiagonalHatch();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HatchPainter();
}

class _HatchPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size ?? Size.zero;
    final rect = offset & size;
    canvas.save();
    canvas.clipRect(rect);
    final paint = Paint()
      ..color = T.danger.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    const step = 7.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(offset.dx + x, offset.dy),
        Offset(offset.dx + x + size.height, offset.dy + size.height),
        paint,
      );
    }
    canvas.restore();
  }
}
