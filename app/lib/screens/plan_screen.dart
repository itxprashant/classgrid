import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/clashes.dart';
import '../core/ics.dart';
import '../models/course.dart';
import '../models/plan.dart';
import '../state/catalog_provider.dart';
import '../state/planner_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/academic_calendar_sheet.dart';
import '../widgets/common.dart';
import '../widgets/edit_timing_sheet.dart';
import '../widgets/timetable_grid.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  String? _expandedCode;

  Future<void> _openAddCourse() async {
    final catalog = context.read<CatalogProvider>();
    final planner = context.read<PlannerStore>();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCourseSheet(catalog: catalog),
    );
    if (code != null) planner.addCourses([code]);
  }

  Future<void> _confirmAutoFetch() async {
    final planner = context.read<PlannerStore>();
    if (!planner.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with IITD to auto-fetch your courses.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-fetch registered courses?'),
        content: const Text(
            'This replaces your current plan — including any tutorial/lab timings you set — with the courses you are registered for this semester.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace plan')),
        ],
      ),
    );
    if (ok == true) await planner.refreshUserCourses();
  }

  Future<void> _exportIcs() async {
    final planner = context.read<PlannerStore>();
    if (planner.selectedCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add courses before exporting.')),
      );
      return;
    }
    final ics = generateICS(planner.selectedCourses, planner.timetableData);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/iitd-timetable.ics');
      await file.writeAsString(ics);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/calendar')],
          subject: 'IITD Timetable',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerStore>();
    final credits = totalCredits(planner.selectedCourses);
    final conflicts = countConflicts(planner.selectedCourses, planner.timetableData);

    return ListView(
      children: [
        PageHeader(
          eyebrow: 'Planner',
          title: 'Build your week',
          subtitle: Wrap(
            spacing: 12,
            children: [
              Text('${planner.selectedCourses.length} courses', style: AppText.mono(size: T.fs12, color: T.ink2)),
              Text('${credits.toStringAsFixed(1)} credits', style: AppText.mono(size: T.fs12, color: T.ink2)),
              Text(
                conflicts == 0 ? 'no clashes' : '$conflicts clash${conflicts == 1 ? '' : 'es'}',
                style: AppText.mono(size: T.fs12, color: conflicts == 0 ? T.successInk : T.danger),
              ),
            ],
          ),
        ),
        if (planner.banner != null)
          StatusBanner(
            kind: planner.banner!.kind,
            text: planner.banner!.text,
            onClose: planner.clearBanner,
          ),
        // Toolbar.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: _openAddCourse, icon: const Icon(Icons.add, size: 18), label: const Text('Add course')),
              OutlinedButton.icon(
                onPressed: planner.autoFetchLoading ? null : _confirmAutoFetch,
                icon: planner.autoFetchLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: const Text('Auto-fetch'),
              ),
              OutlinedButton.icon(onPressed: _exportIcs, icon: const Icon(Icons.ios_share, size: 18), label: const Text('Export .ics')),
              OutlinedButton.icon(
                onPressed: () => AcademicCalendarSheet.show(context),
                icon: const Icon(Icons.event_note_outlined, size: 18),
                label: const Text('Holidays'),
              ),
            ],
          ),
        ),
        if (conflicts > 0)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StatusBanner(
              kind: 'err',
              text: 'Some sessions clash. Conflicting blocks are hatched on the grid.',
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TimetableGrid(
            courses: planner.selectedCourses,
            timetableData: planner.timetableData,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text('SELECTED COURSES',
              style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2)),
        ),
        if (planner.selectedCourses.isEmpty)
          const EmptyState(
            message: 'No courses yet. Add a course or auto-fetch your registered courses.',
            icon: Icons.event_available_outlined,
          )
        else
          ...planner.selectedCourses.map((c) => _courseTile(c, planner)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _courseTile(SelectedCourse course, PlannerStore planner) {
    final expanded = _expandedCode == course.courseCode;
    final td = planner.timetableData[course.courseCode];
    final canEdit = course.tutorial || course.lab;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text(course.courseCode, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(course.courseName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs13, color: T.ink2)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                Pill(course.creditStructure, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                if (course.tutorial)
                  Pill(td?.tutorial != null ? 'Tut set' : 'Tut needed',
                      tint: T.tutorialTint, edge: T.tutorialEdge, ink: T.tutorialInk),
                if (course.lab)
                  Pill(td?.lab != null ? 'Lab set' : 'Lab needed',
                      tint: T.labTint, edge: T.labEdge, ink: T.labInk),
              ]),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (canEdit)
                IconButton(
                  tooltip: 'Edit sessions',
                  icon: Icon(expanded ? Icons.expand_less : Icons.edit_calendar_outlined, size: 20),
                  onPressed: () => setState(() => _expandedCode = expanded ? null : course.courseCode),
                ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  planner.removeCourse(course.courseCode);
                  if (expanded) setState(() => _expandedCode = null);
                },
              ),
            ]),
          ),
          if (expanded && canEdit && td != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Edit tutorial / lab sessions'),
                onPressed: () async {
                  final result = await EditTimingSheet.show(context, course: course, current: td);
                  if (result != null) {
                    planner.updateCourseTimings(
                      course.courseCode,
                      tutorial: result['tutorial'],
                      lab: result['lab'],
                      setTutorial: result.containsKey('tutorial'),
                      setLab: result.containsKey('lab'),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet course search: uppercase substring match on course code,
/// capped at 10 results (parity with the web add-course modal).
class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet({required this.catalog});
  final CatalogProvider catalog;

  @override
  State<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<_AddCourseSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toUpperCase();
    final results = q.isEmpty
        ? <Course>[]
        : widget.catalog.courses.where((c) => c.courseCode.contains(q)).take(10).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a course', style: AppText.serif(size: T.fs18)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: AppText.mono(size: T.fs16),
                decoration: const InputDecoration(
                  hintText: 'Course code, e.g. COL106',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 8),
              if (q.isNotEmpty && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No courses match "$q".', style: AppText.sans(size: T.fs13, color: T.ink3)),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in results)
                      ListTile(
                        dense: true,
                        title: Row(children: [
                          Text(c.courseCode, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.courseName,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs13, color: T.ink2)),
                          ),
                        ]),
                        subtitle: Text(c.instructor ?? '', style: AppText.sans(size: T.fs12, color: T.ink3)),
                        onTap: () => Navigator.pop(context, c.courseCode),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
