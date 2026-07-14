import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/occupied_rooms_api.dart';
import '../core/feedback.dart';
import '../core/empty_halls.dart';
import '../core/room_schedule.dart';
import '../core/semester_schedule.dart';
import '../models/academic_day.dart';
import '../models/occupied_room.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../state/semester_data_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import '../widgets/report_content_sheet.dart';
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
  bool _loading = false;
  bool _initialized = false;
  String? _markingsError;
  String _building = kDefaultRoomBuildingTab;
  EmptyHallsResult? _cachedResult;
  String? _resultCacheKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarDate = DateTime(now.year, now.month, now.day);
  }

  DateTime _termFirst(SemesterScheduleConfig schedule) =>
      _parseYmd(schedule.classesStart);

  DateTime _termLast(SemesterScheduleConfig schedule) =>
      _parseYmd(schedule.lastTeachingDay);

  DateTime _clampToTerm(DateTime date, SemesterScheduleConfig schedule) {
    final d = DateTime(date.year, date.month, date.day);
    final first = _termFirst(schedule);
    final last = _termLast(schedule);
    if (d.isBefore(first)) return first;
    if (d.isAfter(last)) return last;
    return d;
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
    final schedule = context.watch<SemesterDataProvider>().schedule;
    if (schedule != null) {
      final clamped = _clampToTerm(_calendarDate, schedule);
      if (clamped != _calendarDate) {
        _calendarDate = clamped;
      }
    }
    if (!_initialized) {
      _initialized = true;
      _loadMarkings();
    }
  }

  Future<void> _loadMarkings() async {
    setState(() {
      _loading = true;
      _markingsError = null;
    });
    final api = context.read<OccupiedRoomsApi>();
    try {
      final m = await api.fetchOccupiedRooms(date: _dateKey, time: _timeValue);
      if (mounted) {
        setState(() {
          _markings = m;
          _markingsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markings = [];
          _markingsError = e is ApiException
              ? e.message
              : 'Could not load manual room markings. Results may be incomplete.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(SemesterScheduleConfig schedule) async {
    final first = _termFirst(schedule);
    final last = _termLast(schedule);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clampToTerm(_calendarDate, schedule),
      firstDate: first,
      lastDate: last,
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

  void _resetSchedule(SemesterScheduleConfig schedule) {
    final now = DateTime.now();
    setState(() {
      _calendarDate = _clampToTerm(DateTime(now.year, now.month, now.day), schedule);
      _time = TimeOfDay.fromDateTime(now);
      _custom = false;
    });
    _loadMarkings();
  }

  void _openSchedule(String room) {
    pushAppRoute<void>(
      context,
      RoomDetailScreen(roomName: normalizeRoomName(room)),
    );
  }

  EmptyHallsResult _resultFor(CatalogProvider catalog, List<dynamic> extraOccupied) {
    final key = '$_dateKey|$_timeValue|${_markings.length}|${extraOccupied.length}|${catalog.courses.length}';
    if (_resultCacheKey == key && _cachedResult != null) return _cachedResult!;
    final r = computeEmptyHalls(
      courses: catalog.courses,
      extraOccupied: extraOccupied,
      manualMarkings: _markings,
      at: _at,
    );
    _resultCacheKey = key;
    _cachedResult = r;
    return r;
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
            final endHHMM = '${endTime.hour.toString().padLeft(2, '0')}${endTime.minute.toString().padLeft(2, '0')}';
            final startMins = _time.hour * 60 + _time.minute;
            final endMins = endTime.hour * 60 + endTime.minute;
            if (endMins <= startMins) {
              setLocal(() => error = 'End time must be after the selected time.');
              return;
            }
            final api = context.read<OccupiedRoomsApi>();
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
            title: Text('Mark $room occupied', style: AppText.serif(size: T.fs18, color: T.ink)),
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
        title: Text(m.room, style: AppText.serif(size: T.fs18, color: T.ink)),
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
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ReportContentSheet.show(
                  context,
                  targetKind: 'occupied_room',
                  targetId: m.id,
                  contextLabel: reportContextForOccupiedRoom(room: m.room, date: m.date),
                );
              },
              child: const Text('Report marking'),
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
                final confirmed = await confirmDestructive(
                  ctx,
                  title: 'Remove marking?',
                  message: 'This removes your manual occupancy for ${m.room} on ${m.date}.',
                );
                if (!confirmed || !ctx.mounted) return;
                final api = ctx.read<OccupiedRoomsApi>();
                try {
                  await api.removeOccupiedRoom(m.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadMarkings();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          e is ApiException ? e.message : 'Could not remove marking.',
                        ),
                      ),
                    );
                  }
                }
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
    AppPaletteScope.watch(context);
    final catalog = context.watch<CatalogProvider>();
    final semester = context.watch<SemesterDataProvider>();

    return ScreenShell(
      eyebrow: 'Right now · live',
      title: 'Free rooms',
      body: (catalog.loading && !catalog.isReady) || (semester.loading && !semester.isReady)
          ? const Center(child: CircularProgressIndicator())
          : semester.schedule == null
              ? EmptyState(
                  message: semester.error ?? 'Semester data is not available.',
                  icon: Icons.cloud_off_outlined,
                  action: FilledButton(onPressed: semester.load, child: const Text('Retry')),
                )
              : _buildBody(context, catalog, semester),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CatalogProvider catalog,
    SemesterDataProvider semester,
  ) {
    final schedule = semester.schedule!;
    final extraOccupied = semester.extraOccupied;
    final r = _resultFor(catalog, extraOccupied);

    final buildingTabs = buildingTabCountsForRoomNames(r.entries.map((e) => e.room));
    final filteredEntries = filterEntriesByBuilding(
      r.entries,
      _building,
      (e) => e.room,
    );
    final lhcSections = _building == kDefaultRoomBuildingTab
        ? groupLhEntriesByFloor(filteredEntries, (e) => e.room)
        : null;

    return RefreshIndicator(
      onRefresh: _loadMarkings,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(schedule),
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
                  TextButton(onPressed: () => _resetSchedule(schedule), child: const Text('Now')),
              ],
            ),
          ),
          if (_markingsError != null)
            StatusBannerWithRetry(
              kind: 'err',
              text: _markingsError!,
              onRetry: _loadMarkings,
              onClose: () => setState(() => _markingsError = null),
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final tab in buildingTabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AppChoiceChip(
                      label: '${tab.code} (${tab.count})',
                      selected: _building == tab.code,
                      onSelected: (_) => setState(() => _building = tab.code),
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_markingsError != null)
            EmptyState(
              message: 'Could not verify manual markings. Retry before trusting free-room results.',
              icon: Icons.cloud_off_outlined,
              action: FilledButton(onPressed: _loadMarkings, child: const Text('Retry')),
            )
          else if (r.entries.isEmpty)
            EmptyState(
              message: catalog.courses.every((c) => c.lectureHall == null)
                  ? 'No rooms are tracked yet. The catalog has no venue data this semester, so only manually-marked rooms appear here.'
                  : 'Every tracked room is occupied. Try a different date or time.',
              icon: Icons.meeting_room_outlined,
            )
          else if (filteredEntries.isEmpty)
            EmptyState(
              message: 'No rooms in $_building at this time. Try another building tab, date, or time.',
              icon: Icons.meeting_room_outlined,
            )
          else if (lhcSections != null)
            for (final section in lhcSections) _lhcSection(section)
          else
            _blockSection(_building, filteredEntries),
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

  Widget _lhcSection(LhFloorEntrySection<EmptyHallEntry> section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.label.toUpperCase(),
            style: AppText.mono(size: T.fs11, weight: FontWeight.w600, color: T.ink3),
          ),
          const SizedBox(height: 8),
          _hallWrap(section.items),
        ],
      ),
    );
  }

  Widget _blockSection(String building, List<EmptyHallEntry> entries) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(building, style: AppText.mono(size: T.fs13, color: T.ink2, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('${entries.length}', style: AppText.mono(size: T.fs12, color: T.ink3)),
          ]),
          const SizedBox(height: 8),
          _hallWrap(entries),
        ],
      ),
    );
  }

  Widget _hallWrap(List<EmptyHallEntry> entries) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final e in entries) _hallTile(e)],
    );
  }

  Widget _hallTile(EmptyHallEntry e) {
    return Column(
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
            child: Text(
              e.room,
              style: AppText.mono(size: T.fs13, color: e.marked ? T.danger : T.successInk),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => _onMarkTap(e),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: T.space12),
          ),
          child: Text(
            e.marked ? 'Details' : (context.read<AuthProvider>().isLoggedIn ? 'Mark' : 'Sign in'),
            style: AppText.sans(size: T.fs12, color: T.ink3),
          ),
        ),
      ],
    );
  }
}
