import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/occupied_rooms_api.dart';
import '../core/semester_schedule.dart';
import '../models/academic_day.dart';
import '../models/occupied_room.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

String _normalizeRoom(String name) {
  final s = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return '';
  final m = RegExp(r'^LH\s*(.+)$', caseSensitive: false).firstMatch(s);
  if (m != null) return 'LH ${m.group(1)!.trim()}';
  return s;
}

class _HallEntry {
  final String room;
  final bool marked;
  final OccupiedRoom? marking;
  const _HallEntry(this.room, this.marked, this.marking);
}

/// Free lecture-hall finder. Mirrors the web EmptyLectureHalls page: the hall
/// universe is built from the catalog + manual markings, cross-referenced
/// against the live timetable (using the academic effective day) and the static
/// `extra_occupied.json` overlay; remaining halls are free or red-marked.
class EmptyHallsScreen extends StatefulWidget {
  const EmptyHallsScreen({super.key});

  @override
  State<EmptyHallsScreen> createState() => _EmptyHallsScreenState();
}

class _EmptyHallsScreenState extends State<EmptyHallsScreen> {
  TimeOfDay _time = TimeOfDay.now();
  bool _custom = false;
  List<OccupiedRoom> _markings = [];
  List<dynamic> _extraOccupied = [];
  bool _loading = false;
  bool _initialized = false;

  DateTime get _now {
    final base = DateTime.now();
    return DateTime(base.year, base.month, base.day, _time.hour, _time.minute);
  }

  String get _dateKey => formatDateKey(_now);
  int get _timeValue => _time.hour * 100 + _time.minute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadExtra();
      _loadMarkings();
    }
  }

  Future<void> _loadExtra() async {
    try {
      final raw = await rootBundle.loadString('assets/extra_occupied.json');
      final parsed = jsonDecode(raw);
      if (parsed is List && mounted) setState(() => _extraOccupied = parsed);
    } catch (_) {}
  }

  Future<void> _loadMarkings() async {
    setState(() => _loading = true);
    final api = context.read<OccupiedRoomsApi>();
    try {
      final m = await api.fetchOccupiedRooms(date: _dateKey, time: _timeValue);
      if (mounted) setState(() => _markings = m);
    } catch (_) {
      if (mounted) setState(() => _markings = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({List<_HallEntry> entries, int free, int marked, int occupied, int total, AcademicDay academic}) _compute(
      CatalogProvider catalog) {
    final academic = getAcademicDay(_now);
    final effectiveDayCode = academic.hasClasses ? academic.effectiveDayCode : null;
    final tv = _timeValue;

    final allHalls = <String>{};
    for (final c in catalog.courses) {
      final lh = c.lectureHall;
      if (lh != null) {
        for (final h in lh.split(',').map((e) => e.trim())) {
          if (h.startsWith('LH')) allHalls.add(h);
        }
      }
    }
    for (final m in _markings) {
      final room = _normalizeRoom(m.room);
      if (room.startsWith('LH')) allHalls.add(room);
    }

    final timetableOccupied = <String>{};
    if (effectiveDayCode != null) {
      for (final c in catalog.courses) {
        final timing = c.slot.lectureTiming;
        final lh = c.lectureHall;
        if (timing == null || lh == null) continue;
        for (final t in timing.split(',')) {
          if (t.length != 9) continue;
          final day = int.parse(t.substring(0, 1));
          final start = int.parse(t.substring(1, 5));
          final end = int.parse(t.substring(5, 9));
          if (day == effectiveDayCode && tv >= start && tv < end) {
            for (final h in lh.split(',').map((e) => e.trim())) {
              if (h.startsWith('LH')) timetableOccupied.add(h);
            }
          }
        }
      }
    }

    final jsDay = _now.weekday % 7; // Sun=0..Sat=6
    final extraSet = <String>{};
    for (final item in _extraOccupied) {
      if (item is! Map) continue;
      if (item['day'] == jsDay) {
        final start = int.tryParse('${item['startTime']}') ?? 0;
        final end = int.tryParse('${item['endTime']}') ?? 0;
        final hall = '${item['lectureHall']}';
        if (tv >= start && tv < end && hall.startsWith('LH')) extraSet.add(hall);
      }
    }

    final manualByRoom = {for (final m in _markings) _normalizeRoom(m.room): m};

    final entries = <_HallEntry>[];
    var free = 0, marked = 0;
    final sorted = allHalls.toList()..sort();
    for (final room in sorted) {
      if (timetableOccupied.contains(room) || extraSet.contains(room)) continue;
      final marking = manualByRoom[_normalizeRoom(room)];
      if (marking != null) {
        entries.add(_HallEntry(room, true, marking));
        marked++;
      } else {
        entries.add(_HallEntry(room, false, null));
        free++;
      }
    }

    return (
      entries: entries,
      free: free,
      marked: marked,
      occupied: timetableOccupied.length + extraSet.length,
      total: allHalls.length,
      academic: academic,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() {
        _time = picked;
        _custom = true;
      });
      _loadMarkings();
    }
  }

  void _resetTime() {
    setState(() {
      _time = TimeOfDay.now();
      _custom = false;
    });
    _loadMarkings();
  }

  void _onHallTap(_HallEntry entry) {
    if (entry.marked) {
      _showMarking(entry.marking!);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with IITD to mark a room.')),
      );
      return;
    }
    _showMarkDialog(_normalizeRoom(entry.room));
  }

  Future<void> _showMarkDialog(String room) async {
    final startHHMM = '${_time.hour.toString().padLeft(2, '0')}${_time.minute.toString().padLeft(2, '0')}';
    TimeOfDay endTime = TimeOfDay(hour: (_time.hour + 1) % 24, minute: _time.minute);
    final noteController = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final api = context.read<OccupiedRoomsApi>();
            final endHHMM = '${endTime.hour.toString().padLeft(2, '0')}${endTime.minute.toString().padLeft(2, '0')}';
            try {
              await api.createOccupiedRoom(
                room: room,
                date: _dateKey,
                start: startHHMM,
                end: endHHMM,
                note: noteController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadMarkings();
            } catch (e) {
              setLocal(() => error = e is ApiException ? e.message : 'Could not save marking');
            }
          }

          return AlertDialog(
            title: Text('Mark $room occupied', style: AppText.serif(size: T.fs18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For ${DateFormat('EEE, d MMM').format(_now)} from ${_time.format(context)} until the end time below. This date only.',
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Text('Until', style: AppText.sans(size: T.fs13, color: T.ink2)),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final p = await showTimePicker(context: ctx, initialTime: endTime);
                      if (p != null) setLocal(() => endTime = p);
                    },
                    child: Text(endTime.format(context), style: AppText.mono(size: T.fs14)),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. club meeting'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: AppText.sans(size: T.fs12, color: T.danger)),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: submit, child: const Text('Mark occupied')),
            ],
          );
        },
      ),
    );
  }

  void _showMarking(OccupiedRoom m) {
    final auth = context.read<AuthProvider>();
    final canDelete = auth.user?.kerberos != null &&
        m.markedBy?.kerberos != null &&
        m.markedBy!.kerberos!.toLowerCase() == auth.user!.kerberos!.toLowerCase();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.room, style: AppText.serif(size: T.fs18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Occupied — not on the official room allotment.', style: AppText.sans(size: T.fs13, color: T.ink2)),
            const SizedBox(height: 12),
            _metaRow('Date', m.date),
            _metaRow('Time', '${m.start.substring(0, 2)}:${m.start.substring(2)}–${m.end.substring(0, 2)}:${m.end.substring(2)}'),
            if (m.markedBy?.name != null) _metaRow('Marked by', m.markedBy!.name!),
            if ((m.note ?? '').isNotEmpty) _metaRow('Note', m.note!),
          ],
        ),
        actions: [
          if (canDelete)
            TextButton(
              onPressed: () async {
                final api = context.read<OccupiedRoomsApi>();
                try {
                  await api.removeOccupiedRoom(m.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadMarkings();
                } catch (_) {}
              },
              child: Text('Remove marking', style: AppText.sans(color: T.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _metaRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(k, style: AppText.sans(size: T.fs12, color: T.ink3))),
          Expanded(child: Text(v, style: AppText.mono(size: T.fs13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.loading && !catalog.isReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = _compute(catalog);

    // Group by prefix token (e.g. "LH").
    final groups = <String, List<_HallEntry>>{};
    for (final e in r.entries) {
      final key = RegExp(r'^(\w+)').firstMatch(e.room)?.group(1) ?? 'Other';
      (groups[key] ??= []).add(e);
    }
    final groupKeys = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadMarkings,
      child: ListView(
        children: [
          const PageHeader(eyebrow: 'Right now · live', title: 'Free lecture halls'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('DATE', style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1)),
                      Text(DateFormat('EEE, d MMM y').format(_now), style: AppText.mono(size: T.fs14)),
                      if (r.academic.type == AcademicType.swapped)
                        Text('→ ${r.academic.effectiveDay} timetable',
                            style: AppText.mono(size: T.fs12, color: T.accentInk)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_time.format(context), style: AppText.mono(size: T.fs14)),
                ),
                if (_custom)
                  TextButton(onPressed: _resetTime, child: const Text('Now')),
              ],
            ),
          ),
          if (r.academic.type != AcademicType.normal)
            StatusBanner(
              kind: r.academic.hasClasses ? 'warn' : 'ok',
              text: describeAcademicDay(r.academic) +
                  (r.academic.hasClasses ? '' : ' All halls free per the timetable.'),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              _stat('Free', '${r.free}', T.successInk),
              _stat('Marked', '${r.marked}', T.danger),
              _stat('In class', '${r.occupied}', T.ink2),
              _stat('Tracked', '${r.total}', T.ink2),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (r.entries.isEmpty)
            EmptyState(
              message: catalog.courses.every((c) => c.lectureHall == null)
                  ? 'No halls are tracked yet. The catalog has no venue data this semester, so only manually-marked rooms appear here.'
                  : 'Every tracked hall is occupied. Try a different time.',
              icon: Icons.meeting_room_outlined,
            )
          else
            for (final key in groupKeys) _group(key, groups[key]!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Green = free per timetable · Red = marked occupied (not on the allotment chart).',
              style: AppText.sans(size: T.fs12, color: T.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: T.surface,
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.r),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: AppText.mono(size: T.fs18, color: color)),
            Text(label, style: AppText.sans(size: T.fs12, color: T.ink3)),
          ]),
        ),
      );

  Widget _group(String key, List<_HallEntry> entries) {
    entries.sort((a, b) {
      double n(String s) => double.tryParse(s.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return n(a.room).compareTo(n(b.room));
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(key, style: AppText.mono(size: T.fs13, color: T.ink2, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('${entries.length}', style: AppText.mono(size: T.fs12, color: T.ink3)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in entries)
                InkWell(
                  onTap: () => _onHallTap(e),
                  borderRadius: BorderRadius.circular(T.rSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: e.marked ? T.dangerTint : T.successTint,
                      border: Border.all(color: e.marked ? T.dangerEdge : T.successEdge),
                      borderRadius: BorderRadius.circular(T.rSm),
                    ),
                    child: Text(e.room,
                        style: AppText.mono(size: T.fs13, color: e.marked ? T.danger : T.successInk)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
