import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/timing.dart';
import '../models/course.dart';
import '../models/session.dart';
import '../state/catalog_provider.dart';
import '../state/planner_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Single course view: metadata facts and session timings. The enrolled-student
/// roster donut is deferred (no roster API; `courseStudents.json` ships as a
/// stub) — a hook is left for a future endpoint.
class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseCode});

  final String courseCode;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final course = catalog.byCode(courseCode);

    return Scaffold(
      appBar: AppBar(title: Text(courseCode, style: AppText.mono(size: T.fs18, weight: FontWeight.w600))),
      body: course == null
          ? const EmptyState(message: 'Course not found in the catalog.', icon: Icons.help_outline)
          : _body(context, course),
    );
  }

  Widget _body(BuildContext context, Course course) {
    final planner = context.read<PlannerStore>();
    final onPlan = planner.selectedCourses.any((c) => c.courseCode == course.courseCode);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(course.courseName, style: AppText.serif(size: T.fs26)),
        const SizedBox(height: 4),
        if ((course.instructor ?? '').isNotEmpty)
          Text(course.instructor!, style: AppText.sans(size: T.fs14, color: T.ink2)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (course.slot.name != null && course.slot.name!.isNotEmpty)
            Pill('Slot ${course.slot.name}', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
          Pill('${course.totalCredits.toStringAsFixed(1)} credits', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
          Pill('L-T-P ${course.creditStructure}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
          if ((course.currentStrength ?? '').isNotEmpty)
            Pill('${course.currentStrength} enrolled', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
        ]),
        const SizedBox(height: 20),
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
                Text('${s.start.substring(0, 2)}:${s.start.substring(2)} – ${s.end.substring(0, 2)}:${s.end.substring(2)}',
                    style: AppText.mono(size: T.fs13, color: T.ink2)),
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
