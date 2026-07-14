import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/room_schedule.dart';
import '../state/catalog_provider.dart';
import '../state/semester_data_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/room_week_grid.dart';
import '../core/course_routes.dart';
import 'course_detail_screen.dart';
import 'course_offering_screen.dart';
import 'empty_halls_screen.dart';

/// Per-room weekly schedule (list + calendar). Mirrors web `/rooms/:roomSlug`.
class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.roomName});

  final String roomName;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  _ViewMode _view = _ViewMode.list;
  RoomCatalog? _cachedCatalog;
  int? _cachedCoursesLen;
  int? _cachedExtraLen;
  int? _cachedCampusLen;

  RoomCatalog _roomCatalog(CatalogProvider catalog, SemesterDataProvider semester) {
    final coursesLen = catalog.courses.length;
    final extraLen = semester.extraOccupied.length;
    final campusLen = semester.campusRooms.length;
    if (_cachedCatalog != null &&
        _cachedCoursesLen == coursesLen &&
        _cachedExtraLen == extraLen &&
        _cachedCampusLen == campusLen) {
      return _cachedCatalog!;
    }
    _cachedCatalog = buildRoomCatalog(
      catalog.courses,
      extraOccupied: semester.extraOccupied,
      campusRooms: semester.campusRooms,
    );
    _cachedCoursesLen = coursesLen;
    _cachedExtraLen = extraLen;
    _cachedCampusLen = campusLen;
    return _cachedCatalog!;
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final catalog = context.watch<CatalogProvider>();
    final semester = context.watch<SemesterDataProvider>();
    final normalized = normalizeRoomName(widget.roomName);

    return ScreenShell(
      eyebrow: roomPrefix(normalized),
      title: normalized,
      subtitle: (catalog.loading && !catalog.isReady) || (semester.loading && !semester.isReady)
          ? null
          : Text(
              _subtitle(catalog, semester, normalized),
              style: AppText.sans(size: T.fs13, color: T.ink2),
            ),
      body: (catalog.loading && !catalog.isReady) || (semester.loading && !semester.isReady)
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(catalog, semester, normalized, semester.schedule?.code),
    );
  }

  String _subtitle(CatalogProvider catalog, SemesterDataProvider semester, String normalized) {
    final roomCatalog = _roomCatalog(catalog, semester);
    final roomMeta = roomCatalog.rooms.where((r) => r.name == normalized).firstOrNull;
    if (roomMeta == null) return 'Not in semester catalog';
    if (roomMeta.schedulePending) {
      return 'Room allotment for this semester is not released yet';
    }

    final sessions = sessionsForRoom(roomCatalog.sessionsByRoom, normalized);
    final conflicts = roomSessionOverlapIndices(sessions);
    return '${sessions.length} session${sessions.length == 1 ? '' : 's'} this semester'
        '${conflicts.isNotEmpty ? ' · ${conflicts.length} overlap${conflicts.length == 1 ? '' : 's'}' : ''}';
  }

  Widget _buildBody(
    CatalogProvider catalog,
    SemesterDataProvider semester,
    String normalized,
    String? activeSemesterCode,
  ) {
    final roomCatalog = _roomCatalog(catalog, semester);
    final roomMeta = roomCatalog.rooms.where((r) => r.name == normalized).firstOrNull;

    if (roomMeta == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            message: '$normalized is not in the semester catalog.',
            icon: Icons.meeting_room_outlined,
            action: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to rooms'),
            ),
          ),
        ),
      );
    }

    final sessions = sessionsForRoom(roomCatalog.sessionsByRoom, normalized);
    final conflicts = roomSessionOverlapIndices(sessions);
    final byDay = groupSessionsByDay(sessions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        AppSegmentedFilters<_ViewMode>(
          selected: _view,
          onChanged: (v) => setState(() => _view = v),
          segments: const [
            AppFilterSegment(
              value: _ViewMode.list,
              label: 'List',
              icon: Icons.format_list_bulleted_rounded,
            ),
            AppFilterSegment(
              value: _ViewMode.calendar,
              label: 'Calendar',
              icon: Icons.calendar_view_week_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => pushAppRoute(context, const EmptyHallsScreen()),
          icon: const Icon(Icons.meeting_room_outlined, size: 18),
          label: const Text('Check if free now'),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          EmptyState(
            message: roomMeta.schedulePending
                ? 'Weekly schedules for this room will appear once the Room Allotment Chart for this semester is published and imported into the catalog.'
                : 'No classes scheduled in this room in the current catalog.',
            icon: Icons.event_busy,
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: _view == _ViewMode.calendar
                ? KeyedSubtree(
                    key: const ValueKey('calendar'),
                    child: RoomWeekGrid(
                      sessions: sessions,
                      conflicts: conflicts,
                      onBlockTap: (session, _) => _openCourse(context, session.courseCode, activeSemesterCode),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('list'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final day in kDayOrder.keys)
                          if ((byDay[day] ?? const []).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: T.surface,
                                  border: Border.all(color: T.line),
                                  borderRadius: BorderRadius.circular(T.rLg),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      color: T.paper2,
                                      child: Text(day, style: AppText.sans(size: T.fs14, weight: FontWeight.w600)),
                                    ),
                                    for (var i = 0; i < (byDay[day] ?? const []).length; i++)
                                      _sessionTile(
                                        (byDay[day] ?? const [])[i],
                                        sessions.indexOf((byDay[day] ?? const [])[i]),
                                        conflicts,
                                        activeSemesterCode,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
      ],
    );
  }

  void _openCourse(BuildContext context, String? courseCode, String? activeSemesterCode) {
    if (courseCode == null || courseCode.isEmpty) return;
    if (isValidSemesterCode(activeSemesterCode)) {
      pushAppRoute(
        context,
        CourseOfferingScreen(courseCode: courseCode, semesterCode: activeSemesterCode!),
      );
    } else {
      pushAppRoute(context, CourseDetailScreen(courseCode: courseCode));
    }
  }

  Widget _sessionTile(
    RoomSession session,
    int globalIndex,
    Set<int> conflicts,
    String? activeSemesterCode,
  ) {
    final conflict = conflicts.contains(globalIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: conflict ? T.dangerTint.withValues(alpha: 0.5) : null,
        border: Border(top: BorderSide(color: T.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '${formatHHMM(session.start)}–${formatHHMM(session.end)}',
              style: AppText.mono(size: T.fs12, color: T.ink2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (session.courseCode != null)
                      InkWell(
                        onTap: () => _openCourse(context, session.courseCode, activeSemesterCode),
                        child: Text(
                          session.courseCode!,
                          style: AppText.mono(size: T.fs13, weight: FontWeight.w600, color: T.accentInk),
                        ),
                      )
                    else
                      Text(session.courseName, style: AppText.mono(size: T.fs13, weight: FontWeight.w600)),
                    Pill(session.type, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                  ],
                ),
                if (session.courseCode != null) ...[
                  const SizedBox(height: 2),
                  Text(session.courseName, style: AppText.sans(size: T.fs13, color: T.ink)),
                ],
                if (session.instructor.isNotEmpty)
                  Text(session.instructor, style: AppText.sans(size: T.fs12, color: T.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ViewMode { list, calendar }
