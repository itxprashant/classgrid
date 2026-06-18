import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/history_api.dart';
import '../core/kerberos_meta.dart';
import '../models/course_offering.dart';
import '../models/student_summary.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/offering_history_tile.dart';
import 'course_offering_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({
    super.key,
    required this.kerberos,
    this.studentName,
  });

  final String kerberos;
  final String? studentName;

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  StudentSummary? _student;
  List<CourseOffering>? _offerings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<HistoryApi>().fetchStudentOfferings(widget.kerberos);
      if (!mounted) return;
      setState(() {
        _student = data.student;
        _offerings = sortOfferingsBySemesterDesc(data.offerings);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load courses';
      });
    }
  }

  Map<String, List<CourseOffering>> _groupBySemester(List<CourseOffering> items) {
    final map = <String, List<CourseOffering>>{};
    for (final o in items) {
      map.putIfAbsent(o.semesterCode, () => []).add(o);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.courseCode.compareTo(b.courseCode));
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: map[k]!};
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: T.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: AppText.mono(size: T.fs11, color: T.ink3, letterSpacing: 0.08),
            ),
          ),
          Expanded(
            child: Text(value, style: AppText.sans(size: T.fs14, color: T.ink2)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final student = _student;
    final title = student?.name.isNotEmpty == true
        ? student!.name
        : (widget.studentName ?? widget.kerberos);

    return ScreenShell(
      eyebrow: 'Student explorer',
      title: title,
      subtitle: Text(widget.kerberos, style: AppText.mono(size: T.fs13, color: T.ink3)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(message: _error!, icon: Icons.error_outline)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final student = _student;
    final offerings = _offerings ?? [];
    final meta = kerberosMeta(student?.kerberos ?? widget.kerberos);
    final branch = student?.branch ?? meta.branch;
    final entryYear = student?.entryYear ?? meta.entryYear;

    return ListView(
      padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
      children: [
        Container(
          padding: const EdgeInsets.all(T.space16),
          decoration: BoxDecoration(
            color: T.surface,
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: AppText.mono(size: T.fs11, color: T.ink3, letterSpacing: 0.12)),
              const SizedBox(height: T.space12),
              if (branch != null) _metaRow('Branch', branch),
              if (entryYear != null) _metaRow('Entry', entryYear),
              _metaRow('Hostel', formatHostel(student?.hostel)),
            ],
          ),
        ),
        const SizedBox(height: T.space16),
        if (offerings.isEmpty)
          EmptyState(message: 'No registered courses found for this student.', icon: Icons.school_outlined)
        else ...[
          Pill('${offerings.length} courses', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
          const SizedBox(height: T.space16),
          for (final entry in _groupBySemester(offerings).entries) ...[
            Text(
              entry.value.first.label,
              style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 0.08),
            ),
            const SizedBox(height: T.space8),
            for (final offering in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: T.space8),
                child: OfferingHistoryTile(
                  offering: offering,
                  variant: OfferingHistoryVariant.byCourse,
                  highlight: offering.isActive,
                  onTap: () => pushAppRoute<void>(
                    context,
                    CourseOfferingScreen(
                      courseCode: offering.courseCode,
                      semesterCode: offering.semesterCode,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: T.space12),
          ],
        ],
      ],
    );
  }
}
