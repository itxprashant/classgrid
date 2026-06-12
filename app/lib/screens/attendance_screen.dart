import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/attendance.dart';
import '../core/planner_classes.dart';
import '../core/semester_schedule.dart';
import '../models/plan.dart';
import '../state/planner_store.dart';
import '../storage/attendance_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class _SessionRow {
  final DateTime day;
  final PlannerClass plannerClass;

  const _SessionRow(this.day, this.plannerClass);
}

List<_SessionRow> _sessionsForCourse({
  required String courseCode,
  String? sessionKind,
  required List<SelectedCourse> courses,
  required Map<String, CourseTimetable> timetableData,
}) {
  final from = parseDateKey(Semester.classesStart);
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  final rows = <_SessionRow>[];

  var cursor = from;
  while (!cursor.isAfter(end)) {
    for (final c in getClassesForDate(cursor, courses, timetableData)) {
      if (c.courseCode != courseCode) continue;
      if (sessionKind != null && c.kind != sessionKind) continue;
      rows.add(_SessionRow(cursor, c));
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  rows.sort((a, b) {
    final d = b.day.compareTo(a.day);
    return d != 0 ? d : a.plannerClass.start.compareTo(b.plannerClass.start);
  });
  return rows;
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'lecture':
      return 'Lecture';
    case 'tutorial':
      return 'Tutorial';
    case 'lab':
      return 'Lab';
    default:
      return kind;
  }
}

String _formatTimeRange(PlannerClass c) {
  String fmt(String hhmm) {
    if (hhmm.length != 4) return hhmm;
    return '${hhmm.substring(0, 2)}:${hhmm.substring(2)}';
  }

  return '${fmt(c.start)} – ${fmt(c.end)}';
}

/// Attendance dashboard and per-session marking.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.initialCourseCode,
    this.initialSessionKind,
    this.initialDate,
  });

  final String? initialCourseCode;
  final String? initialSessionKind;
  final String? initialDate;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String? _kindFilter;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenInitial());
  }

  void _maybeOpenInitial() {
    if (_openedInitial) return;
    final code = widget.initialCourseCode;
    if (code == null) return;
    _openedInitial = true;
    _openCourseSheet(
      context,
      courseCode: code,
      highlightDate: widget.initialDate,
      highlightKind: widget.initialSessionKind,
    );
  }

  void _showAttendanceSettings(BuildContext context) {
    final planner = context.read<PlannerStore>();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        AppPaletteScope.watch(ctx);
        return AlertDialog(
        title: Text('Attendance settings', style: AppText.serif(size: T.fs18, color: T.ink)),
        content: Consumer<AttendanceStore>(
          builder: (context, attendance, _) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Notify after class to mark attendance',
                style: AppText.sans(size: T.fs14, weight: FontWeight.w500),
              ),
              subtitle: Text(
                'Local reminder when a class ends',
                style: AppText.sans(size: T.fs12, color: T.ink3),
              ),
              value: attendance.markNotifyEnabled,
              onChanged: (v) async {
                await attendance.setMarkNotifyEnabled(v);
                await attendance.onPlannerChanged(
                  courses: planner.selectedCourses,
                  timetableData: planner.timetableData,
                );
              },
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
        );
      },
    );
  }

  bool _courseBelowThreshold({
    required SelectedCourse course,
    required AttendanceStore attendance,
    required Map<String, int> scheduled,
    String? kindFilter,
  }) {
    final kinds = <String>['lecture'];
    if (course.tutorial) kinds.add('tutorial');
    if (course.lab) kinds.add('lab');
    final threshold = attendance.thresholdFor(course.courseCode);

    int present = 0;
    int absent = 0;
    double? aggPercent;

    for (final kind in kinds) {
      if (kindFilter != null && kindFilter != kind) continue;
      final bucket = attendance.bucketFor(course.courseCode, kind) ??
          AttendanceBucket(courseCode: course.courseCode, sessionKind: kind);
      final stats = computeBucketStats(
        bucket: bucket,
        scheduledCount: scheduled['${course.courseCode}|$kind'] ?? 0,
        thresholdPercent: threshold,
      );
      present += stats.present;
      absent += stats.absent;
      if (stats.percent != null) {
        final p = stats.percent!;
        aggPercent = aggPercent == null ? p : (aggPercent + p) / 2;
      }
    }

    final denom = present + absent;
    final percent = denom > 0 ? (present / denom) * 100 : aggPercent;
    return percent != null && percent < threshold;
  }

  void _openCourseSheet(
    BuildContext context, {
    required String courseCode,
    String? highlightDate,
    String? highlightKind,
  }) {
    final planner = context.read<PlannerStore>();
    SelectedCourse? course;
    for (final c in planner.selectedCourses) {
      if (c.courseCode == courseCode) {
        course = c;
        break;
      }
    }
    if (course == null) return;
    final selected = course;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: T.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rLg)),
      ),
      builder: (ctx) => _CourseAttendanceSheet(
        course: selected,
        highlightDate: highlightDate,
        highlightKind: highlightKind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final planner = context.watch<PlannerStore>();
    final attendance = context.watch<AttendanceStore>();
    final courses = planner.selectedCourses;

    final termStart = parseDateKey(Semester.classesStart);
    final today = DateTime.now();
    final scheduled = countScheduledSessions(
      from: termStart,
      to: today,
      courses: courses,
      timetableData: planner.timetableData,
      through: today,
    );

    var belowThreshold = 0;
    for (final course in courses) {
      if (_courseBelowThreshold(
        course: course,
        attendance: attendance,
        scheduled: scheduled,
        kindFilter: _kindFilter,
      )) {
        belowThreshold++;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance', style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Attendance settings',
            onPressed: () => _showAttendanceSettings(context),
          ),
        ],
      ),
      body: Material(
        color: T.paper,
        child: ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        PageHeader(
          eyebrow: 'Tools',
          title: 'Attendance',
          subtitle: Text(
            'Track present and absent against your plan',
            style: AppText.sans(size: T.fs14, color: T.ink3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Semester.label,
                style: AppText.mono(size: T.fs12, color: T.ink3),
              ),
              if (belowThreshold > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$belowThreshold course${belowThreshold == 1 ? '' : 's'} below required attendance',
                  style: AppText.sans(size: T.fs13, color: T.danger, weight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              AppSegmentedFilters<String?>(
                selected: _kindFilter,
                onChanged: (v) => setState(() => _kindFilter = v),
                segments: [
                  const AppFilterSegment<String?>(
                    value: null,
                    label: 'All',
                    icon: Icons.grid_view_rounded,
                  ),
                  AppFilterSegment<String?>(
                    value: 'lecture',
                    label: 'Lecture',
                    icon: Icons.menu_book_outlined,
                    palette: AppFilterPalette.lecture,
                  ),
                  AppFilterSegment<String?>(
                    value: 'tutorial',
                    label: 'Tutorial',
                    icon: Icons.groups_outlined,
                    palette: AppFilterPalette.tutorial,
                  ),
                  AppFilterSegment<String?>(
                    value: 'lab',
                    label: 'Lab',
                    icon: Icons.science_outlined,
                    palette: AppFilterPalette.lab,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (courses.isEmpty)
          Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              message: 'Add courses on the Plan tab to track attendance.',
              icon: Icons.fact_check_outlined,
            ),
          )
        else
          ...courses.map((course) {
            final kinds = <String>['lecture'];
            if (course.tutorial) kinds.add('tutorial');
            if (course.lab) kinds.add('lab');

            int present = 0;
            int absent = 0;
            double? aggPercent;
            var worstSafe = 999;

            final courseThreshold = attendance.thresholdFor(course.courseCode);

            for (final kind in kinds) {
              if (_kindFilter != null && _kindFilter != kind) continue;
              final bucket = attendance.bucketFor(course.courseCode, kind) ??
                  AttendanceBucket(courseCode: course.courseCode, sessionKind: kind);
              final stats = computeBucketStats(
                bucket: bucket,
                scheduledCount: scheduled['${course.courseCode}|$kind'] ?? 0,
                thresholdPercent: courseThreshold,
              );
              present += stats.present;
              absent += stats.absent;
              if (stats.safeMissesLeft < worstSafe) worstSafe = stats.safeMissesLeft;
              if (stats.percent != null) {
                final p = stats.percent!;
                aggPercent = aggPercent == null ? p : (aggPercent + p) / 2;
              }
            }

            final denom = present + absent;
            final percent = denom > 0 ? (present / denom) * 100 : aggPercent;
            final below = percent != null && percent < courseThreshold;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: T.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(T.r),
                  side: BorderSide(color: below ? T.dangerEdge : T.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(T.r),
                  onTap: () => _openCourseSheet(context, courseCode: course.courseCode),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              course.courseCode,
                              style: AppText.mono(size: T.fs14, weight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                course.courseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.sans(size: T.fs13, color: T.ink2),
                              ),
                            ),
                            if (percent != null)
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: AppText.mono(
                                  size: T.fs14,
                                  weight: FontWeight.w600,
                                  color: below ? T.danger : T.successInk,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (denom > 0)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: present / denom,
                              minHeight: 6,
                              backgroundColor: T.line,
                              color: below ? T.danger : T.successInk,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          denom > 0
                              ? '$present present · $absent absent · $worstSafe safe misses left · req $courseThreshold%'
                              : 'No marks yet — tap to set threshold & log sessions',
                          style: AppText.sans(size: T.fs12, color: T.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
        ),
      ),
    );
  }
}

class _CourseAttendanceSheet extends StatelessWidget {
  const _CourseAttendanceSheet({
    required this.course,
    this.highlightDate,
    this.highlightKind,
  });

  final SelectedCourse course;
  final String? highlightDate;
  final String? highlightKind;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final planner = context.watch<PlannerStore>();
    final attendance = context.watch<AttendanceStore>();
    final kinds = <String>['lecture'];
    if (course.tutorial) kinds.add('tutorial');
    if (course.lab) kinds.add('lab');

    final termStart = parseDateKey(Semester.classesStart);
    final today = DateTime.now();
    final scheduled = countScheduledSessions(
      from: termStart,
      to: today,
      courses: planner.selectedCourses,
      timetableData: planner.timetableData,
      through: today,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                course.courseCode,
                style: AppText.mono(size: T.fs16, weight: FontWeight.w600),
              ),
              Text(
                course.courseName,
                style: AppText.sans(size: T.fs13, color: T.ink3),
              ),
              const SizedBox(height: 12),
              _ThresholdStepper(
                label: 'Required attendance',
                value: attendance.thresholdFor(course.courseCode),
                onDecrement: attendance.thresholdFor(course.courseCode) > 50
                    ? () => attendance.setCourseThreshold(
                          course.courseCode,
                          attendance.thresholdFor(course.courseCode) - 5,
                        )
                    : null,
                onIncrement: attendance.thresholdFor(course.courseCode) < 100
                    ? () => attendance.setCourseThreshold(
                          course.courseCode,
                          attendance.thresholdFor(course.courseCode) + 5,
                        )
                    : null,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    for (final kind in kinds) ...[
                      Builder(builder: (context) {
                        final bucket = attendance.bucketFor(course.courseCode, kind) ??
                            AttendanceBucket(courseCode: course.courseCode, sessionKind: kind);
                        final courseThreshold = attendance.thresholdFor(course.courseCode);
                        final stats = computeBucketStats(
                          bucket: bucket,
                          scheduledCount: scheduled['${course.courseCode}|$kind'] ?? 0,
                          thresholdPercent: courseThreshold,
                        );
                        final sessions = _sessionsForCourse(
                          courseCode: course.courseCode,
                          sessionKind: kind,
                          courses: planner.selectedCourses,
                          timetableData: planner.timetableData,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _kindLabel(kind),
                              style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                            ),
                            Text(
                              stats.percent != null
                                  ? '${stats.percent!.toStringAsFixed(0)}% · ${stats.present}P ${stats.absent}A · ${stats.safeMissesLeft} safe misses'
                                  : '${stats.scheduled} scheduled · tap rows to mark',
                              style: AppText.sans(size: T.fs12, color: T.ink3),
                            ),
                            const SizedBox(height: 8),
                            if (sessions.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'No past sessions for this kind.',
                                  style: AppText.sans(size: T.fs13, color: T.ink3),
                                ),
                              )
                            else
                              ...sessions.map((row) {
                                final dateKey = formatDateKey(row.day);
                                final current = attendance.statusFor(
                                  course.courseCode,
                                  kind,
                                  dateKey,
                                );
                                final highlighted = highlightDate == dateKey &&
                                    (highlightKind == null || highlightKind == kind);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: highlighted ? T.accentTint : T.surfaceSunk,
                                    border: Border.all(
                                      color: highlighted ? T.accentEdge : T.line,
                                    ),
                                    borderRadius: BorderRadius.circular(T.rSm),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              DateFormat('EEE, d MMM').format(row.day),
                                              style: AppText.sans(
                                                size: T.fs13,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeRange(row.plannerClass),
                                              style: AppText.mono(size: T.fs12, color: T.ink3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _StatusChip(
                                        label: 'P',
                                        selected: current == 'present',
                                        color: T.successInk,
                                        onTap: () => _setStatus(
                                          context,
                                          row,
                                          current == 'present' ? null : 'present',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _StatusChip(
                                        label: 'A',
                                        selected: current == 'absent',
                                        color: T.danger,
                                        onTap: () => _setStatus(
                                          context,
                                          row,
                                          current == 'absent' ? null : 'absent',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _StatusChip(
                                        label: 'E',
                                        selected: current == 'excused',
                                        color: T.ink3,
                                        onTap: () => _setStatus(
                                          context,
                                          row,
                                          current == 'excused' ? null : 'excused',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 12),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    _SessionRow row,
    String? status,
  ) async {
    final planner = context.read<PlannerStore>();
    final attendance = context.read<AttendanceStore>();
    final dateKey = formatDateKey(row.day);
    await attendance.markSession(
      courseCode: row.plannerClass.courseCode,
      sessionKind: row.plannerClass.kind,
      dateKey: dateKey,
      status: status,
      plannerClass: row.plannerClass,
      courses: planner.selectedCourses,
      timetableData: planner.timetableData,
    );
  }
}

class _ThresholdStepper extends StatelessWidget {
  const _ThresholdStepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Row(
      children: [
        Text(label, style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: onDecrement,
        ),
        Text('$value%', style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : T.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rSm),
        side: BorderSide(color: selected ? color : T.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rSm),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Text(
              label,
              style: AppText.mono(
                size: T.fs12,
                weight: FontWeight.w700,
                color: selected ? color : T.ink3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
