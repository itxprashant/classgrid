import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../core/room_schedule.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
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
  String _query = '';
  String? _building;
  int _limit = _pageSize;
  List<dynamic> _extraOccupied = const [];
  bool _extraLoaded = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        setState(() => _limit += _pageSize);
      }
    });
    _loadExtra();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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

    if (!_extraLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final roomCatalog = buildRoomCatalog(catalog.courses, extraOccupied: _extraOccupied);
    final buildings = roomBuildingCounts(roomCatalog.rooms);
    final filtered = filterRooms(
      roomCatalog.rooms,
      search: _query,
      prefix: _building,
    );
    final visible = filtered.take(_limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow: 'Campus',
          title: 'Rooms',
          subtitle: Text(
            '${filtered.length} room${filtered.length == 1 ? '' : 's'} from catalog',
            style: AppText.mono(size: T.fs12, color: T.ink3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmptyHallsScreen()),
                ),
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
        if (!roomCatalog.catalogHasVenues)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: StatusBanner(
              kind: 'warn',
              text: 'Venues are not in the catalog yet. Wait for Room Allotment Chart of the current semester to be released.',
            ),
          ),
          
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by room name',
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
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildingChip('All', _building == null, () => setState(() => _building = null)),
              for (final b in buildings)
                _buildingChip(
                  '${b.code} (${b.count})',
                  _building == b.code,
                  () => setState(() {
                    _building = b.code;
                    _limit = _pageSize;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  message: 'No rooms match your search.',
                  icon: Icons.meeting_room_outlined,
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
                    return _roomRow(visible[i]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildingChip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AppChoiceChip(
          label: label,
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _roomRow(RoomInfo room) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomDetailScreen(roomName: room.name)),
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
                    '${room.sessionCount} session${room.sessionCount == 1 ? '' : 's'}',
                    style: AppText.sans(size: T.fs12, color: T.ink3),
                  ),
                ],
              ),
            ),
            Pill(room.prefix, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
