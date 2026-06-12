import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../state/catalog_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'course_detail_screen.dart';

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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final catalog = context.watch<CatalogProvider>();

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
          subtitle: Text('${filtered.length} of ${catalog.courses.length} courses',
              style: AppText.mono(size: T.fs12, color: T.ink3)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search code, name, or instructor',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() {
              _query = v;
              _limit = _pageSize;
            }),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _deptChip('All', _dept == null, () => setState(() => _dept = null)),
              for (final d in depts)
                _deptChip(d, _dept == d, () => setState(() {
                      _dept = d;
                      _limit = _pageSize;
                    })),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(message: 'No courses match your search.', icon: Icons.search_off)
              : ListView.builder(
                  controller: _scroll,
                  itemCount: visible.length + (visible.length < filtered.length ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= visible.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _courseRow(visible[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _deptChip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AppChoiceChip(
          label: label,
          selected: selected,
          onSelected: (_) => onTap(),
          compact: true,
        ),
      );

  Widget _courseRow(Course c) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseDetailScreen(courseCode: c.courseCode)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(c.courseCode, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
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
      ),
    );
  }
}
