import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/courses_api.dart';
import '../core/roster.dart';
import '../models/enrolled_student.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class CourseRosterScreen extends StatefulWidget {
  const CourseRosterScreen({
    super.key,
    required this.courseCode,
    this.courseName,
  });

  final String courseCode;
  final String? courseName;

  @override
  State<CourseRosterScreen> createState() => _CourseRosterScreenState();
}

class _CourseRosterScreenState extends State<CourseRosterScreen> {
  List<EnrolledStudent> _students = [];
  bool _loading = true;
  String? _error;
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
    });
    try {
      final roster = await context.read<CoursesApi>().fetchCourseStudents(widget.courseCode);
      if (!mounted) return;
      setState(() {
        _students = roster.students;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load roster';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final title = widget.courseCode;
    final subtitle = (widget.courseName ?? '').trim();

    return ScreenShell(
      eyebrow: 'Courses',
      title: title,
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle, style: AppText.sans(size: T.fs14, color: T.ink2))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  message: _error!,
                  icon: Icons.error_outline,
                  action: TextButton(onPressed: _load, child: const Text('Retry')),
                )
              : _students.isEmpty
                  ? EmptyState(
                      message: 'No students registered for this course yet.',
                      icon: Icons.people_outline,
                    )
                  : _buildBody(),
    );
  }

  Widget _buildBody() {
    final branches = branchCounts(_students);

    return ListView(
      padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
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
        Container(
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
                    SizedBox(
                      width: 36,
                      child: Text('#', style: AppText.mono(size: T.fs11, color: T.ink3)),
                    ),
                    Expanded(
                      child: Text('Name', style: AppText.mono(size: T.fs11, color: T.ink3)),
                    ),
                    SizedBox(
                      width: 108,
                      child: Text(
                        'Kerberos',
                        style: AppText.mono(size: T.fs11, color: T.ink3),
                        textAlign: TextAlign.right,
                      ),
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
                        child: Text(
                          '${i + 1}',
                          style: AppText.mono(size: T.fs12, color: T.ink3),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _students[i].name,
                          style: AppText.sans(size: T.fs14),
                        ),
                      ),
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
        ),
      ],
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
