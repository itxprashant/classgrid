import 'dart:async';

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
import 'empty_halls_screen.dart';
import 'room_detail_screen.dart';

const int _pageSize = 48;

/// Browse campus rooms and open per-room schedules. Mirrors web `/rooms`.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _building = kDefaultRoomBuildingTab;
  int _limit = _pageSize;
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
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        setState(() => _limit += _pageSize);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final catalog = context.watch<CatalogProvider>();
    final semester = context.watch<SemesterDataProvider>();

    if ((catalog.loading && !catalog.isReady) || (semester.loading && !semester.isReady)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.error != null && !catalog.isReady) {
      return EmptyState(
        message: catalog.error!,
        icon: Icons.cloud_off_outlined,
        action: FilledButton(onPressed: catalog.load, child: const Text('Retry')),
      );
    }

    final roomCatalog = _roomCatalog(catalog, semester);
    final buildingTabs = buildingTabCounts(roomCatalog.rooms);
    final filtered = filterRooms(
      roomCatalog.rooms,
      search: _query,
      building: _building,
    );
    final visible = filtered.take(_limit).toList();
    final lhcSections = _building == kDefaultRoomBuildingTab
        ? groupLhRoomsByFloor(visible)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow: 'Campus',
          title: 'Rooms',
          subtitle: Text(
            roomCatalog.usingCampusRoomFallback && _query.isEmpty
                ? '${filtered.length} campus room${filtered.length == 1 ? '' : 's'} · schedule pending'
                : '${filtered.length} room${filtered.length == 1 ? '' : 's'} from catalog',
            style: AppText.mono(size: T.fs12, color: T.ink3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => pushAppRoute(context, const EmptyHallsScreen()),
                icon: const Icon(Icons.meeting_room_outlined, size: 20),
                label: const Text('Empty halls right now'),
              ),
              const SizedBox(height: 6),
              Text(
                'See which lecture halls are free at a chosen date and time.',
                style: AppText.sans(size: T.fs12, color: T.ink3),
              ),
            ],
          ),
        ),
        if (roomCatalog.usingCampusRoomFallback)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: StatusBanner(
              kind: 'warn',
              text: 'Room allotment for this semester is not released yet. Showing campus rooms from the last allotment chart; weekly schedules will appear when the catalog is updated.',
            ),
          )
        else if (!roomCatalog.catalogHasVenues)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: StatusBanner(
              kind: 'warn',
              text: 'Venues are not in the catalog yet. Wait for Room Allotment Chart of the current semester to be released.',
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppSearchField(
            controller: _searchController,
            hint: 'Search by room name',
            onChanged: _onSearchChanged,
            onClear: () => setState(() {
              _query = '';
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
              for (final tab in buildingTabs)
                _buildingTab(
                  tab.code,
                  tab.count,
                  _building == tab.code,
                  () => setState(() {
                    _building = tab.code;
                    _limit = _pageSize;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  message: 'No rooms in this building match your search.',
                  icon: Icons.meeting_room_outlined,
                )
              : lhcSections != null
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _lhcItemCount(lhcSections, visible.length < filtered.length),
                      itemBuilder: (context, i) => _lhcItem(lhcSections, i),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: visible.length + (visible.length < filtered.length ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= visible.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _roomRow(visible[i], badge: _building == 'LHC' ? 'LHC' : null);
                      },
                    ),
        ),
      ],
    );
  }

  int _lhcItemCount(List<LhFloorSection> sections, bool hasMore) {
    var count = 0;
    for (final section in sections) {
      count += 1 + section.rooms.length;
    }
    if (hasMore) count += 1;
    return count;
  }

  Widget _lhcItem(List<LhFloorSection> sections, int index) {
    var cursor = 0;
    for (final section in sections) {
      if (index == cursor) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            section.label.toUpperCase(),
            style: AppText.mono(size: T.fs11, weight: FontWeight.w600, color: T.ink3),
          ),
        );
      }
      cursor += 1;
      for (final room in section.rooms) {
        if (index == cursor) return _roomRow(room, badge: 'LHC');
        cursor += 1;
      }
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildingTab(String code, int count, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AppChoiceChip(
          label: '$code ($count)',
          selected: selected,
          onSelected: (_) => onTap(),
          compact: true,
        ),
      );

  Widget _roomRow(RoomInfo room, {String? badge}) {
    final pill = badge ?? room.prefix;
    return InkWell(
      onTap: () => pushAppRoute(
        context,
        RoomDetailScreen(roomName: room.name),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: AppText.mono(size: T.fs14, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    room.schedulePending
                        ? 'Schedule pending'
                        : '${room.sessionCount} session${room.sessionCount == 1 ? '' : 's'}',
                    style: AppText.sans(size: T.fs12, color: T.ink3),
                  ),
                ],
              ),
            ),
            Pill(pill, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
