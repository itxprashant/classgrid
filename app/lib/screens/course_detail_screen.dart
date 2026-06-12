import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/courses_api.dart';
import '../core/roster.dart';
import '../core/timing.dart';
import '../models/course.dart';
import '../models/enrolled_student.dart';
import '../models/session.dart';
import '../state/catalog_provider.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseCode});

  final String courseCode;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  CourseRoster? _roster;
  bool _rosterLoading = true;
  String? _rosterError;
  bool _showBranchBreakdown = false;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _rosterLoading = true;
      _rosterError = null;
    });
    try {
      final roster = await context.read<CoursesApi>().fetchCourseStudents(widget.courseCode);
      if (!mounted) return;
      setState(() {
        _roster = roster;
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

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final catalog = context.watch<CatalogProvider>();
    final course = catalog.byCode(widget.courseCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseCode, style: AppText.mono(size: T.fs18, weight: FontWeight.w600)),
      ),
      body: course == null
          ? EmptyState(message: 'Course not found in the catalog.', icon: Icons.help_outline)
          : _body(context, course),
    );
  }

  Widget _body(BuildContext context, Course course) {
    final planner = context.read<PlannerStore>();
    final onPlan = planner.selectedCourses.any((c) => c.courseCode == course.courseCode);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(course.courseName, style: AppText.serif(size: T.fs26, color: T.ink)),
        const SizedBox(height: 4),
        if ((course.instructor ?? '').isNotEmpty)
          Text(course.instructor!, style: AppText.sans(size: T.fs14, color: T.ink2)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (course.slot.name != null && course.slot.name!.isNotEmpty)
              Pill('Slot ${course.slot.name}', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
            Pill('${course.totalCredits.toStringAsFixed(1)} credits', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            Pill('L-T-P ${course.creditStructure}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            if ((course.currentStrength ?? '').isNotEmpty)
              Pill('${course.currentStrength} enrolled', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
          ],
        ),
        const SizedBox(height: 20),
        _rosterCard(),
        const SizedBox(height: 16),
        _factsCard(course),
        const SizedBox(height: 16),
        _sessionsCard('Lecture', parseTimingStr(course.slot.lectureTiming), course.lectureHall),
        _sessionsCard('Tutorial', parseTimingStr(course.slot.tutorialTiming), null),
        _sessionsCard('Lab', parseTimingStr(course.slot.labTiming), null),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onPlan
              ? null
              : () {
                  planner.addCourses([course.courseCode]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${course.courseCode} added to your plan.')),
                  );
                },
          icon: Icon(onPlan ? Icons.check : Icons.add, size: 18),
          label: Text(onPlan ? 'Already on your plan' : 'Add to plan'),
        ),
      ],
    );
  }

  Widget _rosterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Enrolled students', style: AppText.sans(size: T.fs14, weight: FontWeight.w600)),
              ),
              if (_rosterLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_roster != null)
                Pill('${_roster!.count}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            ],
          ),
          if (_rosterError != null) ...[
            const SizedBox(height: 10),
            Text(_rosterError!, style: AppText.sans(size: T.fs13, color: T.danger)),
            TextButton(onPressed: _loadRoster, child: const Text('Retry')),
          ] else if (!_rosterLoading && (_roster == null || _roster!.students.isEmpty)) ...[
            const SizedBox(height: 8),
            Text(
              'No roster data for this course yet.',
              style: AppText.sans(size: T.fs13, color: T.ink3),
            ),
          ] else if (_roster != null && _roster!.students.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _showBranchBreakdown = !_showBranchBreakdown),
              borderRadius: BorderRadius.circular(T.rSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showBranchBreakdown ? 'Hide branch breakdown' : 'Show branch breakdown',
                        style: AppText.sans(size: T.fs13, color: T.accentInk),
                      ),
                    ),
                    Icon(
                      _showBranchBreakdown ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: T.accentInk,
                    ),
                  ],
                ),
              ),
            ),
            if (_showBranchBreakdown) ...[
              const SizedBox(height: 8),
              for (final row in branchCounts(_roster!.students))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(row.branch, style: AppText.mono(size: T.fs13))),
                      Text('${row.count}', style: AppText.mono(size: T.fs13, color: T.ink2)),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _factsCard(Course course) {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        children: [
          row('Code', course.courseCode),
          Divider(height: 1, color: T.line),
          row('Semester', course.semesterCode ?? '—'),
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
                  const SizedBox(width: 8),
                  Text(hall, style: AppText.mono(size: T.fs12, color: T.ink3)),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}
