import 'package:flutter/material.dart';

import '../core/clashes.dart';
import '../core/timetable_layout.dart';
import '../models/plan.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'timetable_hour_rail.dart';

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
///
/// Parents should memoize [sessions] and [conflicts] when feeding a large or
/// frequently rebuilt plan (e.g. cache `flattenSessions` / `conflictIndices`
/// in a [StatefulWidget] or provider) to avoid recomputing on every frame.
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.courses,
    required this.timetableData,
    this.sessions,
    this.conflicts,
    this.onBlockTap,
  });

  final List<SelectedCourse> courses;
  final Map<String, CourseTimetable> timetableData;

  /// Precomputed session list; defaults to [flattenSessions].
  final List<GridSession>? sessions;

  /// Precomputed conflict indices; defaults to [conflictIndices] on [sessions].
  final Set<int>? conflicts;

  /// Optional tap handler for a session block (index into the resolved session list).
  final void Function(int index, GridSession session)? onBlockTap;

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
    AppPaletteScope.watch(context);
    final resolvedSessions =
        sessions ?? flattenSessions(courses, timetableData);
    final resolvedConflicts =
        conflicts ?? conflictIndices(resolvedSessions);
    final plotHeight = TimetableLayout.plotHeight;
    final empty = resolvedSessions.isEmpty;

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
            height: TimetableLayout.headerHeight,
            child: Row(
              children: [
                SizedBox(width: TimetableLayout.railWidth),
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
              final dayAreaWidth = constraints.maxWidth - TimetableLayout.railWidth;
              final colWidth = dayAreaWidth / 5;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int h = TimetableLayout.startHour; h <= TimetableLayout.endHour; h++)
                    Positioned(
                      top: TimetableLayout.lineTopForHour(h),
                      left: 0,
                      right: 0,
                      child: TimetableHourRail(hour: h),
                    ),
                  for (int i = 0; i < 5; i++)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: TimetableLayout.railWidth + i * colWidth,
                      child: Container(width: 1, color: T.line),
                    ),
                  if (empty)
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: T.space24),
                          child: Text(
                            'No sessions yet — add courses to see your week',
                            textAlign: TextAlign.center,
                            style: AppText.sans(size: T.fs13, color: T.ink3),
                          ),
                        ),
                      ),
                    ),
                  // Session blocks.
                  for (int i = 0; i < resolvedSessions.length; i++)
                    _buildBlock(
                      resolvedSessions[i],
                      i,
                      resolvedConflicts.contains(i),
                      colWidth,
                    ),
                ],
              );
            }),
          ),
          Divider(height: 1, color: T.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space12, vertical: T.space8),
            child: Wrap(
              spacing: T.space8,
              runSpacing: T.space4,
              alignment: WrapAlignment.center,
              children: [
                Pill('Lecture', tint: T.lectureTint, edge: T.lectureEdge, ink: T.lectureInk),
                Pill('Tutorial', tint: T.tutorialTint, edge: T.tutorialEdge, ink: T.tutorialInk),
                Pill('Lab', tint: T.labTint, edge: T.labEdge, ink: T.labInk),
                Pill('Conflict', tint: T.dangerTint, edge: T.dangerEdge, ink: T.danger),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(GridSession s, int index, bool conflict, double colWidth) {
    final dayIdx = _dayIndex[s.day];
    if (dayIdx == null) return const SizedBox.shrink();
    final span = TimetableLayout.durationHours(s.start, s.end);
    final top = TimetableLayout.blockTop(s.start);
    final height = TimetableLayout.blockHeight(s.start, s.end)
        .clamp(20.0, TimetableLayout.plotHeight);
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

    final block = Container(
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
                AppText.sans(size: T.fs10, color: ink),
              ),
            if (!compact)
              _fittedLine(
                '$start–$end',
                AppText.mono(size: T.fs10, color: ink),
              ),
            if (!compact && s.location.isNotEmpty)
              _fittedLine(
                s.location,
                AppText.mono(size: T.fs10, color: ink),
              ),
          ],
        ),
      ),
    );

    Widget child = block;
    if (onBlockTap != null) {
      child = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onBlockTap!(index, s),
          borderRadius: BorderRadius.circular(T.rSm),
          child: block,
        ),
      );
    }

    final positioned = Positioned(
      top: top,
      left: TimetableLayout.railWidth + dayIdx * colWidth + TimetableLayout.blockInset,
      width: colWidth - 2 * TimetableLayout.blockInset,
      height: height,
      child: child,
    );

    if (conflict) {
      return Semantics(
        label: '${s.courseCode} ${s.type}, clashes with another session',
        button: onBlockTap != null,
        child: positioned,
      );
    }

    return positioned;
  }
}

/// Diagonal hatch overlay drawn over conflicting blocks (shared with [RoomWeekGrid]).
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
