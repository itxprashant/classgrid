import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../core/timing.dart';
import '../models/course.dart';
import '../models/session.dart';
import '../api/history_api.dart';
import '../api/course_policy_api.dart';
import '../api/planner_api.dart';
import '../models/course_offering.dart';
import '../models/course_policy.dart';
import '../core/calendar_events.dart';
import '../core/course_policy.dart';
import '../core/feedback.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../state/explorer_catalog_provider.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/offering_history_tile.dart';
import '../widgets/instructor_links.dart';
import '../models/instructor_ref.dart';
import '../models/actor.dart';
import 'prof_detail_screen.dart';
import 'course_offering_screen.dart';
import '../widgets/course_policy_sheet.dart';
import '../widgets/report_content_sheet.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseCode});

  final String courseCode;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<CourseOffering>? _pastOfferings;
  bool _offeringsLoading = true;
  String? _offeringsError;
  bool _showPastOfferings = false;

  bool _enrollmentLoaded = false;
  bool _isEnrolled = false;
  CoursePolicy? _policy;
  bool _policyLoading = false;
  String? _policyError;
  bool _policySaving = false;

  @override
  void initState() {
    super.initState();
    _loadPastOfferings();
    _loadEnrollmentAndPolicy();
  }

  Future<void> _loadEnrollmentAndPolicy() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _enrollmentLoaded = true;
        _isEnrolled = false;
      });
      return;
    }

    try {
      final codes = await context.read<PlannerApi>().fetchEnrolledCourses();
      if (!mounted) return;
      final enrolled = codes.contains(widget.courseCode);
      setState(() {
        _enrollmentLoaded = true;
        _isEnrolled = enrolled;
      });
      if (enrolled) {
        await _loadPolicy();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enrollmentLoaded = true;
        _isEnrolled = false;
      });
    }
  }

  Future<void> _loadPolicy() async {
    setState(() {
      _policyLoading = true;
      _policyError = null;
    });
    try {
      final response = await context.read<CoursePolicyApi>().fetchPolicy(widget.courseCode);
      if (!mounted) return;
      setState(() {
        _policy = response.policy;
        _policyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _policyLoading = false;
        _policyError = e is ApiException ? e.message : 'Could not load policy';
      });
    }
  }

  Future<void> _openPolicyEditor() async {
    final draft = await CoursePolicySheet.show(context, policy: _policy);
    if (draft == null || !mounted) return;

    setState(() => _policySaving = true);
    try {
      final saved = await context.read<CoursePolicyApi>().savePolicy(
            widget.courseCode,
            policyPayload(draft),
          );
      if (!mounted) return;
      setState(() {
        _policy = saved;
        _policySaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course policy saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _policySaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Could not save policy'),
        ),
      );
    }
  }

  Future<void> _loadPastOfferings() async {
    setState(() {
      _offeringsLoading = true;
      _offeringsError = null;
    });
    try {
      final offerings = await context.read<HistoryApi>().fetchCourseOfferings(widget.courseCode);
      if (!mounted) return;
      setState(() {
        _pastOfferings = sortOfferingsBySemesterDesc(offerings);
        _offeringsLoading = false;
        _showPastOfferings = offerings.length >= 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _offeringsLoading = false;
        _offeringsError = e is ApiException ? e.message : 'Could not load history';
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

  List<InstructorRef> _instructorsForCourse(Course course) {
    return instructorsFromOffering({
      'instructor': course.instructor,
      'instructorEmail': course.instructorEmail,
    });
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final activeCatalog = context.watch<CatalogProvider>();
    final explorer = context.watch<ExplorerCatalogProvider>();
    final planner = context.watch<PlannerStore>();

    Course? course =
        activeCatalog.byCode(widget.courseCode) ?? explorer.byCode(widget.courseCode);

    if (course == null && _pastOfferings != null && _pastOfferings!.isNotEmpty) {
      course = Course.fromOffering(_pastOfferings!.first, offeredThisSemester: false);
    }

    if (course == null) {
      if (_offeringsLoading || (explorer.loading && !explorer.isReady)) {
        return ScreenShell(
          eyebrow: 'Courses',
          title: widget.courseCode,
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return ScreenShell(
        eyebrow: 'Courses',
        title: widget.courseCode,
        body: EmptyState(message: 'Course not found in the catalog.', icon: Icons.help_outline),
      );
    }

    final resolvedCourse = course;
    final onPlan = planner.selectedCourses.any((c) => c.courseCode == resolvedCourse.courseCode);
    CourseOffering? activeOffering;
    for (final o in _pastOfferings ?? const <CourseOffering>[]) {
      if (o.isActive) {
        activeOffering = o;
        break;
      }
    }
    final primaryOffering = activeOffering ?? (_pastOfferings?.isNotEmpty == true ? _pastOfferings!.first : null);

    return ScreenShell(
      eyebrow: 'Courses',
      title: resolvedCourse.courseCode,
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              resolvedCourse.courseName,
              style: AppText.sans(size: T.fs14, color: T.ink2),
            ),
          ),
          if (!resolvedCourse.offeredThisSemester) ...[
            const SizedBox(width: T.space8),
            Pill('Not offered', tint: T.surfaceSunk, edge: T.lineStrong, ink: T.ink3),
          ],
          const SizedBox(width: T.space8),
          _PlanToggleButton(
            onPlan: onPlan,
            onAdd: () {
              planner.addCourses([resolvedCourse.courseCode]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${resolvedCourse.courseCode} added to your plan.')),
              );
            },
            onRemove: () => _removeFromPlan(context, resolvedCourse),
          ),
        ],
      ),
      body: _body(context, resolvedCourse, primaryOffering),
    );
  }

  Future<void> _removeFromPlan(BuildContext context, Course course) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove from plan?',
      message: 'Remove ${course.courseCode} from your timetable plan?',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    context.read<PlannerStore>().removeCourse(course.courseCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${course.courseCode} removed from your plan.')),
    );
  }

  Widget _body(BuildContext context, Course course, CourseOffering? primaryOffering) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
      children: [
        if (!course.offeredThisSemester) ...[
          StatusBanner(
            kind: 'warn',
            text: 'Not offered this semester. Open the archived offering for full details and enrolled students.',
          ),
          const SizedBox(height: T.space16),
        ],
        if (course.offeredThisSemester && primaryOffering != null) ...[
          StatusBanner(
            kind: 'info',
            text: 'Summary page — open the ${primaryOffering.label} offering for schedule, venue, and enrolled students.',
          ),
          const SizedBox(height: T.space16),
        ],
        if (_instructorsForCourse(course).isNotEmpty) ...[
          InstructorLinks(
            instructors: _instructorsForCourse(course),
            onTap: _openInstructor,
          ),
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
        _factsCard(course),
        if (_enrollmentLoaded && _isEnrolled && course.offeredThisSemester) ...[
          const SizedBox(height: T.space16),
          _coursePolicyCard(),
        ],
        if (primaryOffering != null) ...[
          const SizedBox(height: T.space16),
          _offeringLinkButton(course, primaryOffering),
        ],
        const SizedBox(height: T.space16),
        _sessionsCard('Lecture', parseTimingStr(course.slot.lectureTiming), course.lectureHall),
        _sessionsCard('Tutorial', parseTimingStr(course.slot.tutorialTiming), null),
        _sessionsCard('Lab', parseTimingStr(course.slot.labTiming), null),
        const SizedBox(height: T.space16),
        _pastOfferingsCard(course),
      ],
    );
  }

  Widget _pastOfferingsCard(Course course) {
    final offerings = _pastOfferings ?? [];
    final historical = sortOfferingsBySemesterDesc(offerings);

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
                child: Text('Past offerings', style: AppText.sans(size: T.fs14, weight: FontWeight.w600)),
              ),
              if (_offeringsLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (historical.isNotEmpty)
                Pill('${historical.length}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            ],
          ),
          if (_offeringsError != null) ...[
            const SizedBox(height: 10),
            Text(_offeringsError!, style: AppText.sans(size: T.fs13, color: T.danger)),
            TextButton(onPressed: _loadPastOfferings, child: const Text('Retry')),
          ] else if (!_offeringsLoading && historical.isEmpty) ...[
            const SizedBox(height: T.space8),
            Text(
              'No archived offerings yet for ${course.courseCode}.',
              style: AppText.sans(size: T.fs13, color: T.ink3),
            ),
          ] else if (historical.isNotEmpty) ...[
            const SizedBox(height: T.space12),
            InkWell(
              onTap: () => setState(() => _showPastOfferings = !_showPastOfferings),
              borderRadius: BorderRadius.circular(T.rSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showPastOfferings ? 'Hide semester history' : 'Show semester history',
                        style: AppText.sans(size: T.fs13, color: T.accentInk),
                      ),
                    ),
                    Icon(
                      _showPastOfferings ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: T.accentInk,
                    ),
                  ],
                ),
              ),
            ),
            if (_showPastOfferings) ...[
              const SizedBox(height: T.space12),
              for (final offering in historical)
                Padding(
                  padding: const EdgeInsets.only(bottom: T.space8),
                  child: OfferingHistoryTile(
                    offering: offering,
                    highlight: offering.isActive,
                    onInstructorTap: _openInstructor,
                    onTap: () => pushAppRoute<void>(
                      context,
                      CourseOfferingScreen(
                        courseCode: offering.courseCode,
                        semesterCode: offering.semesterCode,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _coursePolicyCard() {
    final policy = _policy;
    final hasContent = policy?.hasContent ?? false;

    Widget subsection(String label, String text) {
      if (text.trim().isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.5),
          ),
        ],
      );
    }

    String? actorLine(Actor? actor) {
      final info = formatEventActor(actor);
      if (info == null) return null;
      return '${info.who} · ${info.when}';
    }

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
                child: Text(
                  'Course policy',
                  style: AppText.serif(size: T.fs18, weight: FontWeight.w500, color: T.ink),
                ),
              ),
              if (hasContent && !_policyLoading) ...[
                TextButton(
                  onPressed: () => ReportContentSheet.show(
                    context,
                    targetKind: 'course_policy',
                    targetId: widget.courseCode,
                    contextLabel: reportContextForPolicy(widget.courseCode),
                  ),
                  child: const Text('Report'),
                ),
                TextButton(
                  onPressed: _policySaving ? null : _openPolicyEditor,
                  child: const Text('Edit'),
                ),
              ],
            ],
          ),
          if (_policyLoading) ...[
            const SizedBox(height: T.space12),
            const LinearProgressIndicator(minHeight: 2),
          ] else if (_policyError != null) ...[
            const SizedBox(height: T.space8),
            Text(_policyError!, style: AppText.sans(size: T.fs13, color: T.danger)),
            TextButton(onPressed: _loadPolicy, child: const Text('Retry')),
          ] else if (!hasContent) ...[
            const SizedBox(height: T.space8),
            Text(
              'No policy yet.',
              style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Add marking and attendance rules for your section.',
              style: AppText.sans(size: T.fs13, color: T.ink3),
            ),
            const SizedBox(height: T.space12),
            FilledButton(
              onPressed: _policySaving ? null : _openPolicyEditor,
              child: const Text('Add policy'),
            ),
          ] else ...[
            const SizedBox(height: T.space12),
            subsection('Marking scheme', policy!.markingScheme),
            if (policy.markingScheme.trim().isNotEmpty &&
                (policy.attendancePolicy.trim().isNotEmpty ||
                    policy.auditWithdrawalPolicy.trim().isNotEmpty ||
                    policy.otherNotes.trim().isNotEmpty))
              Divider(height: 24, color: T.line),
            subsection('Attendance policy', policy.attendancePolicy),
            if (policy.attendancePolicy.trim().isNotEmpty &&
                (policy.auditWithdrawalPolicy.trim().isNotEmpty ||
                    policy.otherNotes.trim().isNotEmpty))
              Divider(height: 24, color: T.line),
            subsection('Audit / withdrawal policy', policy.auditWithdrawalPolicy),
            if (policy.auditWithdrawalPolicy.trim().isNotEmpty &&
                policy.otherNotes.trim().isNotEmpty)
              Divider(height: 24, color: T.line),
            subsection('Other notes', policy.otherNotes),
            if (policy.createdBy != null || policy.updatedBy != null) ...[
              Divider(height: 24, color: T.line),
              if (policy.createdBy != null)
                Text(
                  'Added by ${actorLine(policy.createdBy)!}',
                  style: AppText.mono(size: T.fs11, color: T.ink3),
                ),
              if (policy.updatedBy != null &&
                  !actorsMatch(policy.createdBy, policy.updatedBy))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Last edited by ${actorLine(policy.updatedBy)!}',
                    style: AppText.mono(size: T.fs11, color: T.ink3),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _offeringLinkButton(Course course, CourseOffering offering) {
    final strength = (course.currentStrength ?? offering.currentStrength ?? '').trim();
    final isCurrent = offering.isActive;

    return Material(
      color: T.surface,
      borderRadius: BorderRadius.circular(T.r),
      child: InkWell(
        onTap: () => pushAppRoute<void>(
          context,
          CourseOfferingScreen(
            courseCode: course.courseCode,
            semesterCode: offering.semesterCode,
          ),
        ),
        borderRadius: BorderRadius.circular(T.r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.r),
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: T.accentInk),
              const SizedBox(width: T.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCurrent ? 'Open ${offering.label} offering' : 'View ${offering.label} offering',
                      style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCurrent
                          ? (strength.isNotEmpty
                              ? '$strength registered · slot, schedule, roster'
                              : 'Schedule, venue, and enrolled students')
                          : 'Archived slot, schedule, and enrolled students',
                      style: AppText.sans(size: T.fs12, color: T.ink3),
                    ),
                  ],
                ),
              ),
              if (strength.isNotEmpty && isCurrent)
                Padding(
                  padding: const EdgeInsets.only(right: T.space8),
                  child: Pill(strength, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                ),
              Icon(Icons.chevron_right, color: T.ink3),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: T.space8),
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
                Text(
                  label,
                  style: AppText.mono(size: T.fs12, weight: FontWeight.w600, color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
