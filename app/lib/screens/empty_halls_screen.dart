import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/occupied_rooms_api.dart';
import '../core/empty_halls.dart';
import '../core/room_schedule.dart';
import '../core/semester_schedule.dart';
import '../models/academic_day.dart';
import '../models/occupied_room.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import 'room_detail_screen.dart';

/// Free-room finder. Mirrors the web Empty Lecture Halls page.
class EmptyHallsScreen extends StatefulWidget {
  const EmptyHallsScreen({super.key});

  @override
  State<EmptyHallsScreen> createState() => _EmptyHallsScreenState();
}

class _EmptyHallsScreenState extends State<EmptyHallsScreen> {
  late DateTime _calendarDate;
  TimeOfDay _time = TimeOfDay.now();
  bool _custom = false;
  List<OccupiedRoom> _markings = [];
  List<dynamic> _extraOccupied = [];
  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _at => DateTime(
        _calendarDate.year,
        _calendarDate.month,
        _calendarDate.day,
        _time.hour,
        _time.minute,
      );

  String get _dateKey => formatDateKey(_at);
  int get _timeValue => _time.hour * 100 + _time.minute;

  DateTime _parseYmd(String ymd) {
    final p = ymd.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _calendarDate,
      firstDate: _parseYmd(Semester.classesStart),
      lastDate: _parseYmd(Semester.lastTeachingDay),
    );
    if (picked != null) {
      setState(() {
        _calendarDate = DateTime(picked.year, picked.month, picked.day);
        _custom = true;
      });
      await _loadMarkings();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() {
        _time = picked;
        _custom = true;
      });
      await _loadMarkings();
    }
  }

  void _resetSchedule() {
    final now = DateTime.now();
    setState(() {
      _calendarDate = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay.fromDateTime(now);
      _custom = false;
    });
    _loadMarkings();
  }

  void _openSchedule(String room) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomDetailScreen(roomName: normalizeRoomName(room)),
      ),
    );
  }

  void _onMarkTap(EmptyHallEntry entry) {
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
    _showMarkDialog(normalizeRoomName(entry.room));
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
                  'For ${DateFormat('EEE, d MMM y').format(_at)} from ${_time.format(context)} until the end time below. This date only.',
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openSchedule(m.room);
              },
              child: const Text('Weekly schedule'),
            ),
            const SizedBox(height: 8),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Empty halls', style: AppText.serif(size: T.fs18, weight: FontWeight.w600)),
      ),
      body: Material(
        color: T.paper,
        child: catalog.loading && !catalog.isReady
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, catalog),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CatalogProvider catalog) {
    final r = computeEmptyHalls(
      courses: catalog.courses,
      extraOccupied: _extraOccupied,
      manualMarkings: _markings,
      at: _at,
    );

    final groups = <String, List<EmptyHallEntry>>{};
    for (final e in r.entries) {
      final key = RegExp(r'^(\w+)').firstMatch(e.room)?.group(1) ?? 'Other';
      (groups[key] ??= []).add(e);
    }
    final groupKeys = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadMarkings,
      child: ListView(
        children: [
          const PageHeader(eyebrow: 'Right now · live', title: 'Free rooms'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE', style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1)),
                        Text(DateFormat('EEE, d MMM y').format(_at), style: AppText.mono(size: T.fs14)),
                        if (r.academic.type == AcademicType.swapped)
                          Text('→ ${r.academic.effectiveDay} timetable',
                              style: AppText.mono(size: T.fs12, color: T.accentInk)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_time.format(context), style: AppText.mono(size: T.fs14)),
                ),
                if (_custom)
                  TextButton(onPressed: _resetSchedule, child: const Text('Now')),
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
              _stat('Free', '${r.freeCount}', T.successInk),
              _stat('Marked', '${r.markedCount}', T.danger),
              _stat('In class', '${r.timetableOccupiedCount}', T.ink2),
              _stat('Tracked', '${r.totalTracked}', T.ink2),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (r.entries.isEmpty)
            EmptyState(
              message: catalog.courses.every((c) => c.lectureHall == null)
                  ? 'No rooms are tracked yet. The catalog has no venue data this semester, so only manually-marked rooms appear here.'
                  : 'Every tracked room is occupied. Try a different date or time.',
              icon: Icons.meeting_room_outlined,
            )
          else
            for (final key in groupKeys) _group(key, groups[key]!),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Green = free per timetable · Red = marked occupied · Tap room name for weekly schedule.',
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

  Widget _group(String key, List<EmptyHallEntry> entries) {
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _openSchedule(e.room),
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
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _onMarkTap(e),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        e.marked ? 'Details' : (context.read<AuthProvider>().isLoggedIn ? 'Mark' : 'Sign in'),
                        style: AppText.sans(size: T.fs12, color: T.ink3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
