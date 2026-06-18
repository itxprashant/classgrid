import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/history_api.dart';
import '../models/course_offering.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/offering_history_tile.dart';
import 'course_offering_screen.dart';

class ProfDetailScreen extends StatefulWidget {
  const ProfDetailScreen({
    super.key,
    required this.instructorEmail,
    this.instructorName,
  });

  final String instructorEmail;
  final String? instructorName;

  @override
  State<ProfDetailScreen> createState() => _ProfDetailScreenState();
}

class _ProfDetailScreenState extends State<ProfDetailScreen> {
  List<CourseOffering>? _offerings;
  String? _displayName;
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
      final data = await context.read<HistoryApi>().fetchInstructorOfferings(widget.instructorEmail);
      if (!mounted) return;
      setState(() {
        _displayName = data.instructor.name.isNotEmpty ? data.instructor.name : widget.instructorName;
        _offerings = sortOfferingsBySemesterDesc(data.offerings);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load offerings';
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

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final title = _displayName ?? widget.instructorName ?? widget.instructorEmail;

    return ScreenShell(
      eyebrow: 'Prof explorer',
      title: title,
      subtitle: Text(widget.instructorEmail, style: AppText.mono(size: T.fs13, color: T.ink3)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(message: _error!, icon: Icons.error_outline)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final offerings = _offerings ?? [];
    if (offerings.isEmpty) {
      return EmptyState(message: 'No catalog offerings found for this instructor.', icon: Icons.school_outlined);
    }

    final grouped = _groupBySemester(offerings);

    return ListView(
      padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
      children: [
        Pill('${offerings.length} offerings', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
        const SizedBox(height: T.space16),
        for (final entry in grouped.entries) ...[
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
    );
  }
}
