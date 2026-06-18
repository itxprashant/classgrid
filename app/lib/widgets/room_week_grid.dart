import 'package:flutter/material.dart';

import '../core/room_schedule.dart';
import '../core/timetable_layout.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'timetable_grid.dart';
import 'timetable_hour_rail.dart';

const Map<String, int> _dayIndex = {
  'Monday': 0,
  'Tuesday': 1,
  'Wednesday': 2,
  'Thursday': 3,
  'Friday': 4,
};
const List<String> _dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI'];

/// Weekly grid for a single room's sessions. Mirrors web RoomWeekGrid.
class RoomWeekGrid extends StatelessWidget {
  const RoomWeekGrid({
    super.key,
    required this.sessions,
    required this.conflicts,
    this.onBlockTap,
  });

  final List<RoomSession> sessions;
  final Set<int> conflicts;
  final void Function(RoomSession session, int index)? onBlockTap;

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
    final plotHeight = TimetableLayout.plotHeight;

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
          SizedBox(
            height: TimetableLayout.headerHeight,
            child: Row(
              children: [
                SizedBox(width: TimetableLayout.railWidth),
                for (final d in _dayLabels)
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: T.line))),
                      child: Text(d, style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1)),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: T.line),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No sessions scheduled in this room.',
                style: AppText.sans(size: T.fs13, color: T.ink3),
                textAlign: TextAlign.center,
              ),
            )
          else
            SizedBox(
              height: plotHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
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
                      for (int i = 0; i < sessions.length; i++)
                        _buildBlock(sessions[i], i, conflicts.contains(i), colWidth),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlock(RoomSession s, int index, bool conflict, double colWidth) {
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
      case 'Extra':
        tint = T.surfaceSunk;
        edge = T.lineStrong;
        ink = T.ink2;
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
      foregroundDecoration: conflict ? const DiagonalHatch() : null,
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fittedLine(s.displayCode, AppText.mono(size: T.fs12, weight: FontWeight.w600, color: ink)),
            if (!compact) _fittedLine(s.type, AppText.sans(size: T.fs10, color: ink)),
            if (!compact) _fittedLine('$start–$end', AppText.mono(size: T.fs10, color: ink)),
          ],
        ),
      ),
    );

    return Positioned(
      top: top,
      left: TimetableLayout.railWidth + dayIdx * colWidth + TimetableLayout.blockInset,
      width: colWidth - 2 * TimetableLayout.blockInset,
      height: height,
      child: onBlockTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onBlockTap!(s, index),
                borderRadius: BorderRadius.circular(T.rSm),
                child: block,
              ),
            )
          : block,
    );
  }
}
