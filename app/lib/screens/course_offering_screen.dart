import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/courses_api.dart';
import '../api/history_api.dart';
import '../core/roster.dart';
import '../core/timing.dart';
import '../models/course.dart';
import '../models/course_offering.dart';
import '../models/enrolled_student.dart';
import '../models/instructor_ref.dart';
import '../models/session.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/instructor_links.dart';
import 'prof_detail_screen.dart';
import 'course_detail_screen.dart';

class CourseOfferingScreen extends StatefulWidget {
  const CourseOfferingScreen({
    super.key,
    required this.courseCode,
    required this.semesterCode,
  });

  final String courseCode;
  final String semesterCode;

  @override
  State<CourseOfferingScreen> createState() => _CourseOfferingScreenState();
}

class _CourseOfferingScreenState extends State<CourseOfferingScreen> {
  CourseOffering? _offering;
  List<EnrolledStudent> _students = [];
  bool _loading = true;
  String? _error;
  bool _rosterLoading = true;
  String? _rosterError;
  bool _showBranchBreakdown = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _rosterLoading = true;
      _rosterError = null;
    });
    try {
      final offerings = await context.read<HistoryApi>().fetchCourseOfferings(widget.courseCode);
      if (!mounted) return;
      CourseOffering? match;
      for (final o in offerings) {
        if (o.semesterCode == widget.semesterCode) {
          match = o;
          break;
        }
      }
      if (match == null) {
        setState(() {
          _loading = false;
          _error = 'Offering not found for this semester.';
        });
        return;
      }
      setState(() {
        _offering = match;
        _loading = false;
      });
      await _loadRoster();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load offering';
      });
    }
  }

  Future<void> _loadRoster() async {
    setState(() {
      _rosterLoading = true;
      _rosterError = null;
    });
    try {
      final roster = await context.read<CoursesApi>().fetchCourseStudents(
            widget.courseCode,
            semesterCode: widget.semesterCode,
          );
      if (!mounted) return;
      setState(() {
        _students = roster.students;
        _rosterLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rosterLoading = false;
        _rosterError = e is ApiException ? e.message : 'Could not load roster';
      });
    }
  }

  void _openInstructor(String email, String name) {
    if (!email.contains('@')) return;
    pushAppRoute<void>(
      context,
      ProfDetailScreen(instructorEmail: email, instructorName: name),
    );
  }

  List<InstructorRef> _instructors(CourseOffering offering) {
    if (offering.instructors.isNotEmpty) return offering.instructors;
    if (offering.instructor.isNotEmpty) {
      return [InstructorRef(name: offering.instructor, email: offering.instructorEmail)];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final offering = _offering;

    if (_loading) {
      return ScreenShell(
        eyebrow: 'Courses',
        title: widget.courseCode,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || offering == null) {
      return ScreenShell(
        eyebrow: 'Courses',
        title: widget.courseCode,
        body: EmptyState(
          message: _error ?? 'Offering not found.',
          icon: Icons.help_outline,
          action: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back'),
          ),
        ),
      );
    }

    final course = Course.fromOffering(offering, offeredThisSemester: offering.isActive);
    final planner = context.watch<PlannerStore>();
    final onPlan = planner.selectedCourses.any((c) => c.courseCode == course.courseCode);
    final instructors = _instructors(offering);
    final strength = (offering.currentStrength ?? '').trim();

    return ScreenShell(
      eyebrow: 'Courses',
      title: course.courseCode,
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              course.courseName,
              style: AppText.sans(size: T.fs14, color: T.ink2),
            ),
          ),
          const SizedBox(width: T.space8),
          Pill(offering.label, tint: T.surfaceSunk, edge: T.lineStrong, ink: T.ink2),
          if (offering.isActive) ...[
            const SizedBox(width: T.space8),
            Pill('Current', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
        children: [
          if (!offering.isActive) ...[
            StatusBanner(
              kind: 'warn',
              text: 'Archived offering for ${offering.label}.',
            ),
            const SizedBox(height: T.space16),
          ],
          if (instructors.isNotEmpty) ...[
            InstructorLinks(instructors: instructors, onTap: _openInstructor),
            const SizedBox(height: T.space16),
          ],
          Wrap(
            spacing: T.space8,
            runSpacing: T.space8,
            children: [
              if (course.slot.name != null && course.slot.name!.isNotEmpty)
                Pill('Slot ${course.slot.name}', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
              Pill('${course.totalCredits.toStringAsFixed(1)} credits', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
              Pill('L-T-P ${course.creditStructure}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            ],
          ),
          const SizedBox(height: T.space16),
          _factsCard(course, offering),
          if (offering.isActive) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => pushAppRoute(
                  context,
                  CourseDetailScreen(courseCode: widget.courseCode),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Previous offerings'),
              ),
            ),
            const SizedBox(height: T.space8),
          ],
          _sessionsCard('Lecture', parseTimingStr(course.slot.lectureTiming), course.lectureHall),
          _sessionsCard('Tutorial', parseTimingStr(course.slot.tutorialTiming), null),
          _sessionsCard('Lab', parseTimingStr(course.slot.labTiming), null),
          const SizedBox(height: T.space16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enrolled students',
                  style: AppText.serif(size: T.fs18, weight: FontWeight.w500, color: T.ink),
                ),
              ),
              _PlanToggleButton(
                onPlan: onPlan,
                onAdd: () {
                  context.read<PlannerStore>().addCourses([course.courseCode]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${course.courseCode} added to your plan.')),
                  );
                },
                onRemove: () async {
                  final confirmed = await confirmDestructive(
                    context,
                    title: 'Remove from plan?',
                    message: 'Remove ${course.courseCode} from your timetable plan?',
                    confirmLabel: 'Remove',
                  );
                  if (!confirmed || !context.mounted) return;
                  context.read<PlannerStore>().removeCourse(course.courseCode);
                },
              ),
            ],
          ),
          const SizedBox(height: T.space12),
          if (_rosterLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_rosterError != null)
            EmptyState(
              message: _rosterError!,
              icon: Icons.error_outline,
              action: TextButton(onPressed: _loadRoster, child: const Text('Retry')),
            )
          else if (_students.isEmpty)
            EmptyState(
              message: strength.isNotEmpty
                  ? 'No roster imported yet. Catalog listed $strength registered.'
                  : 'No students registered for this offering.',
              icon: Icons.people_outline,
            )
          else
            _rosterBody(),
        ],
      ),
    );
  }

  Widget _rosterBody() {
    final branches = branchCounts(_students);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Pill('${_students.length} enrolled', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showBranchBreakdown = !_showBranchBreakdown),
              icon: Icon(
                _showBranchBreakdown ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: T.accentInk,
              ),
              label: Text(
                _showBranchBreakdown ? 'Hide branches' : 'Show branches',
                style: AppText.sans(size: T.fs13, color: T.accentInk),
              ),
            ),
          ],
        ),
        if (_showBranchBreakdown && branches.isNotEmpty) ...[
          const SizedBox(height: T.space12),
          _BranchBarChart(students: _students),
          const SizedBox(height: T.space24),
        ],
        _studentsTable(),
      ],
    );
  }

  Widget _studentsTable() {
    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#', style: AppText.mono(size: T.fs11, color: T.ink3))),
                Expanded(child: Text('Name', style: AppText.mono(size: T.fs11, color: T.ink3))),
                SizedBox(
                  width: 108,
                  child: Text('Kerberos', style: AppText.mono(size: T.fs11, color: T.ink3), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: T.line),
          for (var i = 0; i < _students.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('${i + 1}', style: AppText.mono(size: T.fs12, color: T.ink3)),
                  ),
                  Expanded(child: Text(_students[i].name, style: AppText.sans(size: T.fs14))),
                  SizedBox(
                    width: 108,
                    child: Text(
                      _students[i].id,
                      style: AppText.mono(size: T.fs12, color: T.ink2),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _students.length - 1) Divider(height: 1, color: T.line, indent: 14, endIndent: 14),
          ],
        ],
      ),
    );
  }

  Widget _factsCard(Course course, CourseOffering offering) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(k, style: AppText.sans(size: T.fs13, color: T.ink3))),
              Expanded(child: Text(v, style: AppText.mono(size: T.fs13))),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: T.space16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: T.space8),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        children: [
          row('Semester', offering.label),
          Divider(height: 1, color: T.line),
          row('Lecture slot', course.slot.lectureTimingStr ?? course.slot.lectureTiming ?? '—'),
          Divider(height: 1, color: T.line),
          row('Venue', (course.lectureHall ?? '').isNotEmpty ? course.lectureHall! : '—'),
        ],
      ),
    );
  }

  Widget _sessionsCard(String label, List<Session> sessions, String? hall) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          for (final s in sessions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(width: 90, child: Text(s.day, style: AppText.sans(size: T.fs13))),
                Text(
                  '${s.start.substring(0, 2)}:${s.start.substring(2)} – ${s.end.substring(0, 2)}:${s.end.substring(2)}',
                  style: AppText.mono(size: T.fs13, color: T.ink2),
                ),
                if (hall != null && hall.isNotEmpty) ...[
                  const SizedBox(width: T.space8),
                  Text(hall, style: AppText.mono(size: T.fs12, color: T.ink3)),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _PlanToggleButton extends StatelessWidget {
  const _PlanToggleButton({
    required this.onPlan,
    required this.onAdd,
    required this.onRemove,
  });

  final bool onPlan;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final label = onPlan ? 'On plan' : 'Add';
    final icon = onPlan ? Icons.check_rounded : Icons.add_rounded;
    final bg = onPlan ? T.accentTint : T.surfaceSunk;
    final border = onPlan ? T.accentInk.withValues(alpha: 0.35) : T.accentEdge;
    final ink = T.accentInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPlan ? onRemove : onAdd,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: ink),
                const SizedBox(width: 6),
                Text(label, style: AppText.mono(size: T.fs12, weight: FontWeight.w600, color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchBarChart extends StatelessWidget {
  const _BranchBarChart({required this.students});

  final List<EnrolledStudent> students;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final rows = branchCounts(students);
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxCount = rows.first.count;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Branch breakdown', style: AppText.sans(size: T.fs14, weight: FontWeight.w600)),
          const SizedBox(height: T.space12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: T.space8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(row.branch, style: AppText.mono(size: T.fs12, color: T.ink2)),
                  ),
                  const SizedBox(width: T.space8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(T.rSm),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? row.count / maxCount : 0,
                        minHeight: 18,
                        backgroundColor: T.line,
                        color: T.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: T.space8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${row.count}',
                      textAlign: TextAlign.right,
                      style: AppText.mono(size: T.fs12, color: T.ink3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
