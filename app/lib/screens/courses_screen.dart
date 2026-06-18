import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/course_routes.dart';
import '../models/course.dart';
import '../state/explorer_catalog_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/sheet_scaffold.dart';
import 'course_detail_screen.dart';
import 'course_offering_screen.dart';

const int _pageSize = 40;

/// Course catalog browser. Mirrors the web CourseExplorer: case-insensitive
/// search on code/name/instructor, department filter (first two letters of the
/// code), and incremental pagination (40 per page).
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _dept;
  int _limit = _pageSize;
  int _filteredTotal = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients || _limit >= _filteredTotal) return;
    final pos = _scroll.position;
    if (!pos.hasContentDimensions) return;
    final nearEnd = pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 400;
    if (!nearEnd) return;
    final next = (_limit + _pageSize).clamp(0, _filteredTotal);
    if (next == _limit) return;
    setState(() => _limit = next);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _limit = _pageSize;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<Course> _filtered(List<Course> all) {
    final q = _query.toLowerCase().trim();
    return all.where((c) {
      if (_dept != null && c.department != _dept) return false;
      if (q.isEmpty) return true;
      return c.courseCode.toLowerCase().contains(q) ||
          c.courseName.toLowerCase().contains(q) ||
          (c.instructor ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openDepartmentFilter(List<String> depts) async {
    final result = await SheetScaffold.show<String>(
      context: context,
      initialChildSize: 0.55,
      child: SheetScaffold(
        title: 'Department',
        subtitle: Text(
          'First two letters of the course code',
          style: AppText.sans(size: T.fs12, color: T.ink3),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _deptFilterTile(
              label: 'All departments',
              selected: _dept == null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final d in depts)
              _deptFilterTile(
                label: d,
                selected: _dept == d,
                onTap: () => Navigator.pop(context, d),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _dept = result.isEmpty ? null : result;
      _limit = _pageSize;
    });
  }

  Widget _deptFilterTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? T.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(T.rSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppText.mono(
                      size: T.fs14,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? T.accentInk : T.ink,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, color: T.accentInk, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final catalog = context.watch<ExplorerCatalogProvider>();

    if (catalog.loading && !catalog.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.error != null && !catalog.isReady) {
      return EmptyState(
        message: catalog.error!,
        icon: Icons.cloud_off_outlined,
        action: FilledButton(onPressed: catalog.load, child: const Text('Retry')),
      );
    }

    final depts = (catalog.courses.map((c) => c.department).toSet().toList()..sort());
    final filtered = _filtered(catalog.courses);
    _filteredTotal = filtered.length;
    final cap = _limit.clamp(0, _filteredTotal);
    final visible = filtered.take(cap).toList();

    return Column(
      children: [
        PageHeader(
          eyebrow: 'Catalog',
          title: 'Courses',
          subtitle: Text(
            '${filtered.length} of ${catalog.courses.length} courses'
            '${catalog.offeredCount > 0 ? ' · ${catalog.offeredCount} this sem' : ''}',
            style: AppText.mono(size: T.fs12, color: T.ink3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _searchController,
                  hint: 'Search code, name, or instructor',
                  onChanged: _onSearchChanged,
                  onClear: () => setState(() {
                    _query = '';
                    _limit = _pageSize;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _dept != null ? 'Department: $_dept' : 'Filter by department',
                onPressed: () => _openDepartmentFilter(depts),
                style: _dept != null
                    ? IconButton.styleFrom(
                        backgroundColor: T.accentTint,
                        foregroundColor: T.accentInk,
                      )
                    : null,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
        ),
        if (_dept != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppFilterChip(
                label: _dept!,
                selected: true,
                compact: true,
                icon: Icons.close,
                onTap: () => setState(() {
                  _dept = null;
                  _limit = _pageSize;
                }),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(message: 'No courses match your search.', icon: Icons.search_off)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: visible.length + (visible.length < filtered.length ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= visible.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _courseRow(visible[i], catalog.semesterCode);
                  },
                ),
        ),
      ],
    );
  }

  Widget _courseRow(Course c, String? activeSemesterCode) {
    final semester = courseLinkSemester(c, activeSemesterCode);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () {
        if (isValidSemesterCode(semester)) {
          pushAppRoute(
            context,
            CourseOfferingScreen(courseCode: c.courseCode, semesterCode: semester!),
          );
        } else {
          pushAppRoute(context, CourseDetailScreen(courseCode: c.courseCode));
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(c.courseCode, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
                  if (!c.offeredThisSemester) ...[
                    const SizedBox(width: 6),
                    Pill('Not offered', tint: T.surfaceSunk, edge: T.lineStrong, ink: T.ink3),
                  ],
                  const SizedBox(width: 8),
                  Pill(c.creditStructure, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                ]),
                const SizedBox(height: 2),
                Text(c.courseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs13, color: T.ink2)),
                if ((c.instructor ?? '').isNotEmpty)
                  Text(c.instructor!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(size: T.fs12, color: T.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (c.slot.name != null && c.slot.name!.isNotEmpty)
            Pill(c.slot.name!, tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}
