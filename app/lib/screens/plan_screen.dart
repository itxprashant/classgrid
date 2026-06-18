import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../core/clashes.dart';
import '../core/ics.dart';
import '../models/course.dart';
import '../models/plan.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
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
  Future<void> _startLogin() async {
    if (AppConfig.usesDesktopLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use IITD login in the app bar to sign in.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final opened = await auth.startBrowserLogin();
    if (!mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in on ClassGrid in your browser, then return here.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }

  Future<void> _openAddCourse() async {
    final catalog = context.read<CatalogProvider>();
    final planner = context.read<PlannerStore>();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCourseSheet(
        catalog: catalog,
        existingCodes: planner.selectedCourses.map((c) => c.courseCode).toSet(),
      ),
    );
    if (code == null || !mounted) return;
    if (planner.selectedCourses.any((c) => c.courseCode == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$code is already on your plan.')),
      );
      return;
    }
    planner.addCourses([code]);
  }

  Future<void> _confirmAutoFetch() async {
    final planner = context.read<PlannerStore>();
    if (!planner.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sign in with IITD to auto-fetch your courses.'),
          action: SnackBarAction(
            label: 'Log in',
            onPressed: _startLogin,
          ),
        ),
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
      final file = File('${dir.path}/classgrid-timetable.ics');
      await file.writeAsString(ics);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/calendar')],
          subject: 'ClassGrid timetable',
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

  Future<void> _openEditTiming(SelectedCourse course, PlannerStore planner) async {
    final td = planner.timetableData[course.courseCode];
    if (td == null) return;
    final result = await EdTimingSheet.show(context, course: course, current: td);
    if (result != null) {
      planner.updateCourseTimings(
        course.courseCode,
        tutorial: result['tutorial'],
        lab: result['lab'],
        setTutorial: result.containsKey('tutorial'),
        setLab: result.containsKey('lab'),
      );
    }
  }

  Future<void> _confirmRemoveCourse(SelectedCourse course, PlannerStore planner) async {
    final ok = await confirmDestructive(
      context,
      title: 'Remove ${course.courseCode}?',
      message: 'This course will be removed from your plan.',
    );
    if (ok) planner.removeCourse(course.courseCode);
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final planner = context.watch<PlannerStore>();

    if (!planner.planReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final credits = totalCredits(planner.selectedCourses);
    final conflicts = countConflicts(planner.selectedCourses, planner.timetableData);
    final gridSessions = flattenSessions(planner.selectedCourses, planner.timetableData);
    final gridConflicts = conflictIndices(gridSessions);

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
          padding: const EdgeInsets.symmetric(horizontal: T.space16),
          child: Wrap(
            spacing: T.space8,
            runSpacing: T.space8,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16, vertical: T.space8),
            child: StatusBanner(
              kind: 'err',
              text: 'Some sessions clash. Conflicting blocks are hatched on the grid.',
            ),
          ),
        const SizedBox(height: T.space12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: T.space16),
          child: TimetableGrid(
            courses: planner.selectedCourses,
            timetableData: planner.timetableData,
            sessions: gridSessions,
            conflicts: gridConflicts,
          ),
        ),
        const SectionHeader('Selected courses'),
        if (planner.selectedCourses.isEmpty)
          EmptyState(
            message: 'No courses yet. Add a course or auto-fetch your registered courses.',
            icon: Icons.event_available_outlined,
          )
        else
          ...planner.selectedCourses.map((c) => _courseTile(c, planner)),
        const SizedBox(height: T.space32),
      ],
    );
  }

  Widget _courseTile(SelectedCourse course, PlannerStore planner) {
    final td = planner.timetableData[course.courseCode];
    final canEdit = course.tutorial || course.lab;
    return Container(
      margin: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space8),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: ListTile(
        title: Row(
          children: [
            Text(course.courseCode, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
            const SizedBox(width: T.space8),
            Expanded(
              child: Text(course.courseName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs13, color: T.ink2)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: T.space4),
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
              icon: const Icon(Icons.edit_calendar_outlined, size: 20),
              onPressed: () => _openEditTiming(course, planner),
            ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _confirmRemoveCourse(course, planner),
          ),
        ]),
      ),
    );
  }
}

/// Bottom-sheet course search: uppercase substring match on course code,
/// capped at 10 results (parity with the web add-course modal).
class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet({required this.catalog, required this.existingCodes});

  final CatalogProvider catalog;
  final Set<String> existingCodes;

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
          padding: const EdgeInsets.all(T.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add a course', style: AppText.serif(size: T.fs18, color: T.ink)),
              const SizedBox(height: T.space12),
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
              const SizedBox(height: T.space8),
              if (q.isNotEmpty && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(T.space16),
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
                          const SizedBox(width: T.space8),
                          Expanded(
                            child: Text(c.courseName,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs13, color: T.ink2)),
                          ),
                          if (widget.existingCodes.contains(c.courseCode))
                            Pill('On plan', tint: T.surfaceSunk, edge: T.line, ink: T.ink3),
                        ]),
                        subtitle: Text(c.instructor ?? '', style: AppText.sans(size: T.fs12, color: T.ink3)),
                        onTap: () {
                          if (widget.existingCodes.contains(c.courseCode)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${c.courseCode} is already on your plan.')),
                            );
                            return;
                          }
                          Navigator.pop(context, c.courseCode);
                        },
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
