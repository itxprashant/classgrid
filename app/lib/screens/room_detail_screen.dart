import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/room_schedule.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/room_week_grid.dart';
import 'course_detail_screen.dart';
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
  List<dynamic> _extraOccupied = const [];
  bool _extraLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadExtra();
  }

  Future<void> _loadExtra() async {
    try {
      final raw = await rootBundle.loadString('assets/extra_occupied.json');
      final parsed = jsonDecode(raw);
      if (parsed is List && mounted) {
        setState(() {
          _extraOccupied = parsed;
          _extraLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _extraLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final normalized = normalizeRoomName(widget.roomName);

    return Scaffold(
      appBar: AppBar(
        title: Text(normalized, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
      ),
      body: !_extraLoaded || (catalog.loading && !catalog.isReady)
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(catalog, normalized),
    );
  }

  Widget _buildBody(CatalogProvider catalog, String normalized) {
    final roomCatalog = buildRoomCatalog(catalog.courses, extraOccupied: _extraOccupied);
    final exists = roomCatalog.rooms.any((r) => r.name == normalized);

    if (!exists) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          roomPrefix(normalized),
          style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          '${sessions.length} session${sessions.length == 1 ? '' : 's'} this semester'
          '${conflicts.isNotEmpty ? ' · ${conflicts.length} overlap${conflicts.length == 1 ? '' : 's'}' : ''}',
          style: AppText.sans(size: T.fs13, color: T.ink2),
        ),
        const SizedBox(height: 16),
        SegmentedButton<_ViewMode>(
          segments: const [
            ButtonSegment(value: _ViewMode.list, label: Text('List')),
            ButtonSegment(value: _ViewMode.calendar, label: Text('Calendar')),
          ],
          selected: {_view},
          onSelectionChanged: (s) => setState(() => _view = s.first),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmptyHallsScreen()),
          ),
          icon: const Icon(Icons.meeting_room_outlined, size: 18),
          label: const Text('Check if free now'),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          const EmptyState(
            message: 'No classes scheduled in this room in the current catalog.',
            icon: Icons.event_busy,
          )
        else if (_view == _ViewMode.calendar)
          RoomWeekGrid(sessions: sessions, conflicts: conflicts)
        else
          ...kDayOrder.keys.map((day) {
            final daySessions = byDay[day] ?? const [];
            if (daySessions.isEmpty) return const SizedBox.shrink();
            return Padding(
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
                    for (var i = 0; i < daySessions.length; i++)
                      _sessionTile(daySessions[i], sessions.indexOf(daySessions[i]), conflicts),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _sessionTile(RoomSession session, int globalIndex, Set<int> conflicts) {
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CourseDetailScreen(courseCode: session.courseCode!),
                          ),
                        ),
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
