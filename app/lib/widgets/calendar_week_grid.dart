import 'dart:async';

import 'package:flutter/material.dart';

import '../core/calendar_events.dart';
import '../core/planner_classes.dart';
import '../core/semester_schedule.dart';
import '../core/timetable_layout.dart';
import '../models/academic_day.dart';
import '../models/calendar_event.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'timetable_hour_rail.dart';

const List<String> _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _weekdayLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const double _headBase = 56;
const double _headWithNotes = 72;
const double _headCompact = 40;
const double _headCompactNotes = 52;

const Map<String, String> _kindType = {
  'lecture': 'LEC',
  'tutorial': 'TUT',
  'lab': 'LAB',
};

/// First hall + "+…" when multi-venue (full list stays in tooltips).
String _shortHall(String loc) {
  final parts = loc
      .split(RegExp(r'\s*,\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length <= 1) return loc.trim();
  return '${parts.first}+…';
}

/// Planner-style week grid over seven calendar dates. Mirrors web CalendarWeekGrid.
class CalendarWeekGrid extends StatelessWidget {
  const CalendarWeekGrid({
    super.key,
    required this.weekDates,
    required this.classesByDate,
    required this.eventsByDate,
    required this.onDayTap,
    required this.onEventTap,
  });

  final List<DateTime> weekDates;
  final Map<String, List<PlannerClass>> classesByDate;
  final Map<String, List<CalendarEvent>> eventsByDate;
  final void Function(DateTime day) onDayTap;
  final void Function(CalendarEvent event, DateTime day) onEventTap;

  static String _formatTime(String t) {
    if (t.length != 4) return t;
    return '${t.substring(0, 2)}:${t.substring(2)}';
  }

  static ({String start, String end, bool allDay}) _eventTiming(CalendarEvent evt) {
    if (evt.schedule == 'timed' && evt.start != null && evt.end != null) {
      return (start: evt.start!, end: evt.end!, allDay: false);
    }
    if (evt.schedule == 'at' && evt.time != null) {
      final h = int.parse(evt.time!.substring(0, 2));
      final m = evt.time!.substring(2);
      final endH = h + 1 > 21 ? 21 : h + 1;
      return (
        start: evt.time!,
        end: '${endH.toString().padLeft(2, '0')}$m',
        allDay: false,
      );
    }
    return (start: '', end: '', allDay: true);
  }

  static String? _compactHeadNote(AcademicDay academic) {
    final short = academicCellLabel(academic);
    if (short != null) return short;
    switch (academic.type) {
      case AcademicType.weekend:
        return 'Wknd';
      case AcademicType.beforeTerm:
        return 'Pre-term';
      case AcademicType.afterTerm:
        return 'Post-term';
      default:
        return null;
    }
  }

  static String _dowLabel(int colIdx, bool compact) =>
      compact ? _weekdayLetter[colIdx] : _weekdayShort[colIdx];

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final todayKey = formatDateKey(DateTime.now());
    final columns = <_WeekColumn>[];

    for (var colIdx = 0; colIdx < weekDates.length; colIdx++) {
      final date = weekDates[colIdx];
      final key = formatDateKey(date);
      final academic = getAcademicDay(date);
      final classes = academic.hasClasses ? (classesByDate[key] ?? const []) : const <PlannerClass>[];
      final events = eventsByDate[key] ?? const <CalendarEvent>[];
      final timed = <_TimedItem>[];
      final allDay = <CalendarEvent>[];

      for (final s in classes) {
        timed.add(_TimedItem.classSession(
          colIdx: colIdx,
          courseCode: s.courseCode,
          kind: s.kind,
          kindLabel: _kindType[s.kind] ?? s.kindLabel,
          start: s.start,
          end: s.end,
          location: s.location,
        ));
      }

      for (final evt in events) {
        final timing = _eventTiming(evt);
        if (timing.allDay) {
          allDay.add(evt);
        } else {
          timed.add(_TimedItem.event(
            colIdx: colIdx,
            event: evt,
            start: timing.start,
            end: timing.end,
          ));
        }
      }

      timed.sort((a, b) => a.start.compareTo(b.start));

      columns.add(_WeekColumn(
        date: date,
        key: key,
        colIdx: colIdx,
        academic: academic,
        headNote: academicWeekHeadLabel(academic),
        isToday: key == todayKey,
        timed: timed,
        allDay: allDay,
        dow: _dowLabel(colIdx, false),
        dowCompact: _dowLabel(colIdx, true),
      ));
    }

    final plotHeight = TimetableLayout.plotHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boardWidth = constraints.maxWidth;
          final colWidth =
              (boardWidth - TimetableLayout.railWidth) / weekDates.length;
          final compact = colWidth < 56;
          final hasAnyHeadNote = columns.any(
            (c) => (compact ? _compactHeadNote(c.academic) : c.headNote) != null,
          );
          final headHeight = compact
              ? (hasAnyHeadNote ? _headCompactNotes : _headCompact)
              : (hasAnyHeadNote ? _headWithNotes : _headBase);
          final hasAnyAllDay = columns.any((c) => c.allDay.isNotEmpty);
          final hasAnyTimed = columns.any((c) => c.timed.isNotEmpty);

          return Container(
            width: boardWidth,
            decoration: BoxDecoration(
              color: T.surface,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.rLg),
              boxShadow: [
                BoxShadow(color: T.shadowCard, blurRadius: 2, offset: const Offset(0, 1)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: headHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: TimetableLayout.railWidth),
                      for (final col in columns)
                        Expanded(
                          child: _DayHead(
                            column: col,
                            compact: compact,
                            onDayTap: () => onDayTap(col.date),
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasAnyAllDay) ...[
                  Divider(height: 1, color: T.line),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: TimetableLayout.railWidth),
                        for (final col in columns)
                          Expanded(
                            child: Material(
                              color: T.paper2,
                              child: InkWell(
                                onTap: () => onDayTap(col.date),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: col.colIdx < 6
                                          ? BorderSide(color: T.line)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (final evt in col.allDay)
                                        _AllDayPill(
                                          event: evt,
                                          onTap: () => onEventTap(evt, col.date),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                Divider(height: 1, color: T.line),
                SizedBox(
                  height: plotHeight,
                  width: double.infinity,
                  child: LayoutBuilder(
                    builder: (context, plotConstraints) {
                      final dayAreaWidth =
                          plotConstraints.maxWidth - TimetableLayout.railWidth;
                      final colWidth = dayAreaWidth / 7;
                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          for (int h = TimetableLayout.startHour;
                              h <= TimetableLayout.endHour;
                              h++)
                            Positioned(
                              top: TimetableLayout.lineTopForHour(h),
                              left: 0,
                              right: 0,
                              child: TimetableHourRail(hour: h),
                            ),
                          for (int i = 0; i < 7; i++)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: TimetableLayout.railWidth + i * colWidth,
                              child: Container(width: 1, color: T.line),
                            ),
                          for (final col in columns)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: TimetableLayout.railWidth + col.colIdx * colWidth,
                              width: colWidth,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => onDayTap(col.date),
                                ),
                              ),
                            ),
                          for (final col in columns)
                            for (final item in col.timed)
                              _TimedBlock(
                                item: item,
                                colWidth: colWidth,
                                compact: compact,
                                // Events open the form; class blocks open the day sheet
                                // (same as tapping empty space in the column).
                                onTap: item.event != null
                                    ? () => onEventTap(item.event!, col.date)
                                    : () => onDayTap(col.date),
                              ),
                          _NowLine(
                            todayColIdx: columns
                                .where((c) => c.isToday)
                                .map((c) => c.colIdx)
                                .firstOrNull,
                            colWidth: colWidth,
                          ),
                          if (!hasAnyTimed && !hasAnyAllDay)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'NOTHING THIS WEEK',
                                          style: AppText.mono(
                                            size: T.fs12,
                                            color: T.ink3,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Tap a day column or + to add an event.',
                                          style: AppText.sans(
                                            size: T.fs13,
                                            color: T.ink3,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekColumn {
  const _WeekColumn({
    required this.date,
    required this.key,
    required this.colIdx,
    required this.academic,
    required this.headNote,
    required this.isToday,
    required this.timed,
    required this.allDay,
    required this.dow,
    required this.dowCompact,
  });

  final DateTime date;
  final String key;
  final int colIdx;
  final AcademicDay academic;
  final String? headNote;
  final bool isToday;
  final List<_TimedItem> timed;
  final List<CalendarEvent> allDay;
  final String dow;
  final String dowCompact;
}

class _TimedItem {
  _TimedItem({
    required this.colIdx,
    required this.start,
    required this.end,
    required this.isClass,
    this.courseCode,
    this.kind,
    this.kindLabel,
    this.location = '',
    this.event,
  });

  factory _TimedItem.classSession({
    required int colIdx,
    required String courseCode,
    required String kind,
    required String kindLabel,
    required String start,
    required String end,
    String location = '',
  }) =>
      _TimedItem(
        colIdx: colIdx,
        start: start,
        end: end,
        isClass: true,
        courseCode: courseCode,
        kind: kind,
        kindLabel: kindLabel,
        location: location,
      );

  factory _TimedItem.event({
    required int colIdx,
    required CalendarEvent event,
    required String start,
    required String end,
  }) =>
      _TimedItem(
        colIdx: colIdx,
        start: start,
        end: end,
        isClass: false,
        event: event,
      );

  final int colIdx;
  final String start;
  final String end;
  final bool isClass;
  final String? courseCode;
  final String? kind;
  final String? kindLabel;
  final String location;
  final CalendarEvent? event;
}

class _DayHead extends StatelessWidget {
  const _DayHead({
    required this.column,
    required this.compact,
    required this.onDayTap,
  });

  final _WeekColumn column;
  final bool compact;
  final VoidCallback onDayTap;

  String? get _noteText =>
      compact ? CalendarWeekGrid._compactHeadNote(column.academic) : column.headNote;

  String get _dowLabel => compact ? column.dowCompact : column.dow;

  Color? get _bg {
    final a = column.academic;
    if (column.isToday) return T.accentTint;
    switch (a.type) {
      case AcademicType.holiday:
        return T.successTint;
      case AcademicType.swapped:
        return T.tutorialTint;
      case AcademicType.breakPeriod:
        return isExamPeriod(a.name) ? T.dangerTint : T.labTint;
      case AcademicType.weekend:
        return T.surfaceSunk;
      default:
        return null;
    }
  }

  Color _noteColor() {
    switch (column.academic.type) {
      case AcademicType.holiday:
        return T.successInk;
      case AcademicType.swapped:
        return T.tutorialInk;
      case AcademicType.breakPeriod:
        return isExamPeriod(column.academic.name) ? T.danger : T.labInk;
      default:
        return T.ink3;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final note = _noteText;
    return Material(
      color: _bg ?? Colors.transparent,
      child: InkWell(
        onTap: onDayTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(compact ? 2 : 6, compact ? 4 : 6, compact ? 1 : 4, compact ? 3 : 5),
          decoration: BoxDecoration(
            border: Border(
              right: column.colIdx < 6 ? BorderSide(color: T.line) : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compact ? _dowLabel : _dowLabel.toUpperCase(),
                          style: AppText.mono(
                            size: compact ? 9 : 10,
                            color: T.ink3,
                            letterSpacing: compact ? 0 : 1,
                          ),
                        ),
                        Text(
                          '${column.date.day}',
                          style: AppText.mono(
                            size: compact ? T.fs14 : T.fs16,
                            color: column.isToday ? T.accentInk : T.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Icon(Icons.add, size: 16, color: T.ink3)
                  else
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.add, size: 14, color: T.ink3),
                    ),
                ],
              ),
              if (note != null) ...[
                SizedBox(height: compact ? 1 : 2),
                Text(
                  note,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.mono(
                    size: compact ? 8 : 9,
                    color: _noteColor(),
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllDayPill extends StatelessWidget {
  const _AllDayPill({required this.event, required this.onTap});

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final label = event.isPersonal
        ? event.title
        : '${event.courseCode != null && event.courseCode!.isNotEmpty ? '${event.courseCode} · ' : ''}${event.title}';

    Color tint = T.surface;
    Color ink = T.ink2;
    Color edge = T.line;

    if (event.isPersonal) {
      tint = T.labTint;
      ink = T.labInk;
      edge = T.labEdge;
    } else {
      switch (event.type) {
        case 'quiz':
          tint = T.lectureTint;
          ink = T.lectureInk;
          edge = T.lectureEdge;
        case 'deadline':
          tint = T.tutorialTint;
          ink = T.tutorialInk;
          edge = T.tutorialEdge;
        case 'exam':
          tint = T.dangerTint;
          ink = T.danger;
          edge = T.dangerEdge;
        default:
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: tint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rSm),
          side: BorderSide(color: edge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 10, color: ink, height: 1.25),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimedBlock extends StatelessWidget {
  const _TimedBlock({
    required this.item,
    required this.colWidth,
    required this.compact,
    this.onTap,
  });

  final _TimedItem item;
  final double colWidth;
  final bool compact;
  final VoidCallback? onTap;

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
    final span = TimetableLayout.durationHours(item.start, item.end);
    final top = TimetableLayout.blockTop(item.start);
    final height = TimetableLayout.blockHeight(item.start, item.end)
        .clamp(compact ? 16.0 : 20.0, TimetableLayout.plotHeight);
    // Match planner/web: only shorten blocks by session length, not column width.
    final blockCompact = span < 0.75;
    final left = TimetableLayout.railWidth +
        item.colIdx * colWidth +
        TimetableLayout.blockInset;
    final width = colWidth - 2 * TimetableLayout.blockInset;

    Color tint, edge, ink;
    String body, sub;
    var locLine = '';

    if (item.isClass) {
      switch (item.kind) {
        case 'tutorial':
          tint = T.tutorialTint;
          edge = T.tutorialEdge;
          ink = T.tutorialInk;
        case 'lab':
          tint = T.labTint;
          edge = T.labEdge;
          ink = T.labInk;
        default:
          tint = T.lectureTint;
          edge = T.lectureEdge;
          ink = T.lectureInk;
      }
      body = item.courseCode ?? '';
      final hall = item.location.isNotEmpty ? _shortHall(item.location) : '';
      // ≤1h blocks: fold LH into type line (avoids mid-glyph clip). Longer: own line below.
      if (hall.isNotEmpty && span < 1.25) {
        final kind = item.kindLabel ?? '';
        sub = kind.isEmpty ? hall : '$kind · $hall';
      } else {
        sub = item.kindLabel ?? '';
        if (hall.isNotEmpty && !blockCompact) {
          locLine = hall;
        }
      }
    } else {
      final e = item.event!;
      if (e.isPersonal) {
        tint = T.labTint;
        edge = T.labEdge;
        ink = T.labInk;
        body = 'You';
        sub = e.title;
      } else {
        switch (e.type) {
          case 'quiz':
            tint = T.lectureTint;
            edge = T.lectureEdge;
            ink = T.lectureInk;
          case 'deadline':
            tint = T.tutorialTint;
            edge = T.tutorialEdge;
            ink = T.tutorialInk;
          case 'exam':
            tint = T.dangerTint;
            edge = T.dangerEdge;
            ink = T.danger;
          case 'extra-class':
            tint = T.labTint;
            edge = T.labEdge;
            ink = T.labInk;
          case 'presentation':
            tint = T.accentTint;
            edge = T.accentEdge;
            ink = T.accentInk;
          default:
            tint = T.surfaceSunk;
            edge = T.lineStrong;
            ink = T.ink2;
        }
        body = (e.courseCode != null && e.courseCode!.isNotEmpty) ? e.courseCode! : e.title;
        sub = '${kEventTypeLabels[e.type] ?? e.type} · ${e.title}';
      }
    }

    final start = CalendarWeekGrid._formatTime(item.start);
    final end = CalendarWeekGrid._formatTime(item.end);

    final block = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: edge, width: compact ? 0.75 : 1),
        borderRadius: BorderRadius.circular(T.rSm),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fittedLine(
              body,
              AppText.mono(
                size: compact ? 9 : T.fs12,
                weight: FontWeight.w600,
                color: ink,
              ),
            ),
            if (sub.isNotEmpty)
              _fittedLine(
                sub,
                AppText.sans(
                  size: blockCompact ? 8 : (compact ? 8 : 9),
                  color: ink,
                ),
              ),
            _fittedLine(
              '$start–$end',
              AppText.mono(
                size: blockCompact ? 8 : (compact ? 9 : 10),
                color: ink,
              ),
            ),
            if (locLine.isNotEmpty)
              _fittedLine(
                locLine,
                AppText.mono(
                  size: blockCompact ? 8 : (compact ? 9 : 10),
                  color: ink,
                ),
              ),
          ],
        ),
      ),
    );

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(T.rSm),
                child: block,
              ),
            )
          : block,
    );
  }
}

/// Current-time indicator for today's column only (glowing line + dot).
class _NowLine extends StatefulWidget {
  const _NowLine({
    required this.todayColIdx,
    required this.colWidth,
  });

  final int? todayColIdx;
  final double colWidth;

  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> with SingleTickerProviderStateMixin {
  late DateTime _now;
  Timer? _timer;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _scheduleTick();
  }

  void _scheduleTick() {
    _timer?.cancel();
    final next = Duration(
      milliseconds: (60 - _now.second) * 1000 - _now.millisecond,
    );
    _timer = Timer(next < const Duration(milliseconds: 250) ? const Duration(milliseconds: 250) : next, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final colIdx = widget.todayColIdx;
    if (colIdx == null) return const SizedBox.shrink();

    final offset = (_now.hour - TimetableLayout.startHour) + _now.minute / 60.0;
    if (offset < 0 || offset > TimetableLayout.hourCount) {
      return const SizedBox.shrink();
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final top = offset * TimetableLayout.rowHeight;
    final left = TimetableLayout.railWidth + colIdx * widget.colWidth;
    final width = widget.colWidth;

    return Positioned(
      top: top - 4,
      left: left,
      width: width,
      height: 8,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = reduceMotion ? 0.5 : _pulse.value;
            final glow = 0.35 + 0.35 * t;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 4,
                  right: 4,
                  top: 3,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: T.danger,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: T.danger.withValues(alpha: 0.55 * glow),
                          blurRadius: 4 + 4 * t,
                          spreadRadius: 0.5,
                        ),
                        BoxShadow(
                          color: T.danger.withValues(alpha: 0.35 * glow),
                          blurRadius: 10 + 8 * t,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: T.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: T.surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: T.danger.withValues(alpha: 0.7 * glow),
                          blurRadius: 6 + 6 * t,
                        ),
                        BoxShadow(
                          color: T.danger.withValues(alpha: 0.4 * glow),
                          blurRadius: 14 + 8 * t,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
