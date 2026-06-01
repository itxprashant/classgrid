import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/calendar_events_api.dart';
import '../api/personal_events_api.dart';
import '../api/planner_api.dart';
import '../core/calendar_events.dart';
import '../core/planner_classes.dart';
import '../core/semester_schedule.dart';
import '../models/academic_day.dart';
import '../models/calendar_event.dart';
import '../state/auth_provider.dart';
import '../state/catalog_provider.dart';
import '../state/planner_store.dart';
import '../storage/local_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../core/reminder_schedule.dart';
import '../storage/reminder_store.dart';
import '../widgets/academic_calendar_sheet.dart';
import '../widgets/common.dart';
import '../widgets/event_form_sheet.dart';
import '../widgets/reminder_toggle.dart';

enum _CalendarViewMode { month, week }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first day of the visible month
  late DateTime _weekAnchor; // any day in the visible week
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  int _slideDirection = 1; // 1 = forward, -1 = back (for slide animation)
  double _periodSwipeDx = 0;
  List<CalendarEvent> _shared = [];
  List<CalendarEvent> _personal = [];
  List<String> _enrolledCodes = [];
  bool _loading = false;
  bool _showClasses = false;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _weekAnchor = DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final offset = (d.weekday - DateTime.monday) % 7;
    return d.subtract(Duration(days: offset));
  }

  List<DateTime> _weekDates() {
    final start = _startOfWeek(_weekAnchor);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<DateTime> _visibleDays() =>
      _viewMode == _CalendarViewMode.week ? _weekDates() : _gridDays();

  String _fmtWeekRange(DateTime start, DateTime end) {
    final sameMonth = start.month == end.month && start.year == end.year;
    final startStr = DateFormat('d MMM').format(start);
    final endStr = DateFormat(sameMonth ? 'd' : 'd MMM').format(end);
    return '$startStr – $endStr';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _reload();
    }
  }

  List<DateTime> _gridDaysFor(DateTime month) {
    // Monday-first grid with leading/trailing padding to fill whole weeks.
    final first = DateTime(month.year, month.month, 1);
    final lead = (first.weekday - DateTime.monday) % 7; // 0..6
    final start = first.subtract(Duration(days: lead));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = (((lead + daysInMonth) / 7).ceil()) * 7;
    return List.generate(totalCells, (i) => start.add(Duration(days: i)));
  }

  List<DateTime> _gridDays() => _gridDaysFor(_month);

  Future<void> _reload() async {
    final days = _visibleDays();
    final from = formatDateKey(days.first);
    final to = formatDateKey(days.last);

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final planner = context.read<PlannerStore>();
    final apiClient = context.read<ApiClient>();
    final sharedApi = context.read<CalendarEventsApi>();
    final personalApi = context.read<PersonalEventsApi>();
    final localStore = context.read<LocalStore>();

    try {
      // Enrolled codes (logged-in only), to widen the shared-event filter.
      if (auth.isLoggedIn && _enrolledCodes.isEmpty) {
        try {
          _enrolledCodes = await PlannerApi(apiClient).fetchEnrolledCourses();
        } catch (_) {}
      }
      final plannerCodes =
          planner.selectedCourses.map((c) => c.courseCode).toList();
      final filterCodes = {...plannerCodes, ..._enrolledCodes}.toList();

      // Shared events: skip when there are no course codes (avoids 414 / full
      // catalog fetch).
      List<CalendarEvent> shared = [];
      if (filterCodes.isNotEmpty) {
        shared = await sharedApi.fetchEvents(from: from, to: to, courses: filterCodes);
      }

      // Personal events: API when logged in, local store for guests.
      List<CalendarEvent> personal;
      if (auth.isLoggedIn) {
        personal = await personalApi.fetchPersonalEvents(from: from, to: to);
      } else {
        personal = localStore.loadLocalPersonalEvents(from: from, to: to);
      }

      if (!mounted) return;
      setState(() {
        _shared = shared;
        _personal = personal;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load events';
      });
    }
  }

  void _changeMonth(int delta) {
    if (delta == 0) return;
    setState(() {
      _slideDirection = delta > 0 ? 1 : -1;
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
    _reload();
  }

  void _changePeriod(int delta) {
    if (delta == 0) return;
    if (_viewMode == _CalendarViewMode.week) {
      setState(() {
        _slideDirection = delta > 0 ? 1 : -1;
        _weekAnchor = _startOfWeek(_weekAnchor).add(Duration(days: 7 * delta));
      });
      _reload();
      return;
    }
    _changeMonth(delta);
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _weekAnchor = DateTime(now.year, now.month, now.day);
      _month = DateTime(now.year, now.month, 1);
    });
    _reload();
  }

  void _switchView(_CalendarViewMode mode) {
    if (mode == _viewMode) return;
    if (mode == _CalendarViewMode.week) {
      final now = DateTime.now();
      final inMonth = now.year == _month.year && now.month == _month.month;
      setState(() {
        _weekAnchor = inMonth
            ? DateTime(now.year, now.month, now.day)
            : DateTime(_month.year, _month.month, 1);
        _viewMode = mode;
      });
    } else {
      final rep = _startOfWeek(_weekAnchor).add(const Duration(days: 3));
      setState(() {
        _month = DateTime(rep.year, rep.month, 1);
        _viewMode = mode;
      });
    }
    _reload();
  }

  void _onPeriodSwipeEnd(DragEndDetails details) {
    const minDragPx = 56.0;
    const velocityThreshold = 350.0;
    final v = details.primaryVelocity ?? 0;
    if (_periodSwipeDx <= -minDragPx || v < -velocityThreshold) {
      _changePeriod(1);
    } else if (_periodSwipeDx >= minDragPx || v > velocityThreshold) {
      _changePeriod(-1);
    }
    _periodSwipeDx = 0;
  }

  Map<String, List<CalendarEvent>> _eventsByDate() {
    final map = <String, List<CalendarEvent>>{};
    for (final e in [..._shared, ..._personal]) {
      (map[e.date] ??= []).add(e);
    }
    return map;
  }

  List<CourseOption> _courseOptions() {
    final planner = context.read<PlannerStore>();
    final catalog = context.read<CatalogProvider>();
    if (planner.selectedCourses.isNotEmpty) {
      return planner.selectedCourses
          .map((c) => CourseOption(c.courseCode, c.courseName))
          .toList();
    }
    return catalog.courses
        .map((c) => CourseOption(c.courseCode, c.courseName))
        .toList();
  }

  Future<void> _onDayTap(DateTime day) async {
    final dateKey = formatDateKey(day);
    final events = List<CalendarEvent>.from(_eventsByDate()[dateKey] ?? const []);
    events.sort((a, b) {
      if (a.isPersonal != b.isPersonal) return a.isPersonal ? 1 : -1;
      return a.title.compareTo(b.title);
    });

    final planner = context.read<PlannerStore>();
    final classes = getClassesForDate(
      day,
      planner.selectedCourses,
      planner.timetableData,
    );
    final academic = getAcademicDay(day);

    if (!mounted) return;
    final action = await showDialog<_DayDialogResult>(
      context: context,
      builder: (ctx) => _DayEventsDialog(
        day: day,
        academic: academic,
        events: events,
        classes: classes,
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _DayDialogEdit(:final event):
        await _openForm(EventDraft.fromEvent(event));
      case _DayDialogAdd(:final mode):
        await _openForm(EventDraft.empty(
          dateKey,
          mode: mode,
          defaultCourseCode: mode == 'shared'
              ? (_courseOptions().isNotEmpty ? _courseOptions().first.courseCode : '')
              : '',
        ));
    }
  }

  Future<void> _openForm(EventDraft draft) async {
    final auth = context.read<AuthProvider>();
    final result = await EventFormSheet.show(
      context,
      draft: draft,
      courseOptions: _courseOptions(),
      canWrite: auth.isLoggedIn,
    );
    if (result == null || !mounted) return;

    // Shared events require login; guests can keep personal events locally.
    if (!draft.isPersonal && !auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with IITD to add course events.')),
      );
      return;
    }

    final sharedApi = context.read<CalendarEventsApi>();
    final personalApi = context.read<PersonalEventsApi>();
    final localStore = context.read<LocalStore>();
    final payload = draftPayload(result.draft);

    try {
      if (result.action == EventFormAction.delete && result.draft.id != null) {
        if (result.draft.isPersonal) {
          if (auth.isLoggedIn) {
            await personalApi.removePersonalEvent(result.draft.id!);
          } else {
            await localStore.deleteLocalPersonalEvent(result.draft.id!);
          }
        } else {
          await sharedApi.removeEvent(result.draft.id!);
        }
      } else if (result.draft.isPersonal) {
        if (auth.isLoggedIn) {
          if (result.draft.id != null) {
            await personalApi.patchPersonalEvent(result.draft.id!, payload);
          } else {
            await personalApi.createPersonalEvent(payload);
          }
        } else {
          final event = CalendarEvent.fromJson({...payload, 'isPersonal': true});
          if (result.draft.id != null) {
            await localStore.updateLocalPersonalEvent(result.draft.id!, event);
          } else {
            await localStore.addLocalPersonalEvent(event);
          }
        }
      } else {
        if (result.draft.id != null) {
          await sharedApi.patchEvent(result.draft.id!, payload);
        } else {
          await sharedApi.createEvent(payload);
        }
      }
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${e is ApiException ? e.message : e}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planner = context.watch<PlannerStore>();
    final byDate = _eventsByDate();
    final days = _visibleDays();
    final weekDates = _weekDates();
    final classesByDate = _showClasses
        ? buildClassesByDate(days, planner.selectedCourses, planner.timetableData)
        : const <String, List<PlannerClass>>{};
    final periodKey = _viewMode == _CalendarViewMode.week
        ? '${weekDates.first.year}-${weekDates.first.month}-${weekDates.first.day}'
        : '${_month.year}-${_month.month}';
    final headerTitle = _viewMode == _CalendarViewMode.week
        ? _fmtWeekRange(weekDates.first, weekDates.last)
        : DateFormat('MMMM yyyy').format(_month);

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        children: [
          PageHeader(
            eyebrow: 'Calendar',
            title: headerTitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _changePeriod(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => _changePeriod(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(spacing: 8, children: [
                    _legendDot('Course', T.accent),
                    _legendDot('Personal', T.labEdge),
                    _legendDot('Holiday', T.success),
                  ]),
                ),
                TextButton.icon(
                  onPressed: () => AcademicCalendarSheet.show(context),
                  icon: const Icon(Icons.event_note_outlined, size: 18),
                  label: const Text('Holidays'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                SegmentedButton<_CalendarViewMode>(
                  segments: const [
                    ButtonSegment(value: _CalendarViewMode.month, label: Text('Month')),
                    ButtonSegment(value: _CalendarViewMode.week, label: Text('Week')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (s) => _switchView(s.first),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _goToday,
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _showClasses,
              onChanged: (v) => setState(() => _showClasses = v),
              title: Text('Show classes', style: AppText.sans(size: T.fs14)),
              subtitle: Text('Overlay your planned classes', style: AppText.sans(size: T.fs12, color: T.ink3)),
            ),
          ),
          if (_error != null)
            StatusBanner(kind: 'err', text: _error!, onClose: () => setState(() => _error = null)),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_viewMode == _CalendarViewMode.month)
            _animatedMonth(byDate, classesByDate, periodKey)
          else
            _animatedWeek(byDate, classesByDate, periodKey),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _legendDot(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: AppText.sans(size: T.fs12, color: T.ink3)),
        ],
      );

  Widget _weekdayHeader() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (final l in labels)
            Expanded(
              child: Center(
                child: Text(l, style: AppText.mono(size: T.fs12, color: T.ink3)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _animatedMonth(
    Map<String, List<CalendarEvent>> byDate,
    Map<String, List<PlannerClass>> classesByDate,
    String monthKey,
  ) {
    final days = _gridDays();
    return Column(
      children: [
        _weekdayHeader(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _periodSwipeDx += details.delta.dx,
          onHorizontalDragEnd: _onPeriodSwipeEnd,
          onHorizontalDragCancel: () => _periodSwipeDx = 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final key = child.key as ValueKey<String>?;
              final isEntering = key?.value == monthKey;
              final dir = _slideDirection.toDouble();
              final offset = Tween<Offset>(
                begin: isEntering ? Offset(dir, 0) : Offset.zero,
                end: isEntering ? Offset.zero : Offset(-dir, 0),
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return ClipRect(
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(monthKey),
              child: _monthGrid(days, _month, byDate, classesByDate),
            ),
          ),
        ),
      ],
    );
  }

  Widget _animatedWeek(
    Map<String, List<CalendarEvent>> byDate,
    Map<String, List<PlannerClass>> classesByDate,
    String weekKey,
  ) {
    final days = _weekDates();
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => _periodSwipeDx += details.delta.dx,
      onHorizontalDragEnd: _onPeriodSwipeEnd,
      onHorizontalDragCancel: () => _periodSwipeDx = 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final key = child.key as ValueKey<String>?;
          final isEntering = key?.value == weekKey;
          final dir = _slideDirection.toDouble();
          final offset = Tween<Offset>(
            begin: isEntering ? Offset(dir, 0) : Offset.zero,
            end: isEntering ? Offset.zero : Offset(-dir, 0),
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return ClipRect(
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(weekKey),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 600;
              if (stacked) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      for (var i = 0; i < days.length; i++)
                        _WeekDayColumn(
                          day: days[i],
                          weekdayLabel: weekdayLabels[i],
                          academic: getAcademicDay(days[i]),
                          events: byDate[formatDateKey(days[i])] ?? const [],
                          classes: classesByDate[formatDateKey(days[i])] ?? const [],
                          onDayTap: () => _onDayTap(days[i]),
                          onEventTap: (e) => _openForm(EventDraft.fromEvent(e)),
                          stacked: true,
                        ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: _WeekDayColumn(
                            day: days[i],
                            weekdayLabel: weekdayLabels[i],
                            academic: getAcademicDay(days[i]),
                            events: byDate[formatDateKey(days[i])] ?? const [],
                            classes: classesByDate[formatDateKey(days[i])] ?? const [],
                            onDayTap: () => _onDayTap(days[i]),
                            onEventTap: (e) => _openForm(EventDraft.fromEvent(e)),
                            stacked: false,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _monthGrid(
    List<DateTime> days,
    DateTime visibleMonth,
    Map<String, List<CalendarEvent>> byDate,
    Map<String, List<PlannerClass>> classesByDate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: days.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.62,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemBuilder: (context, i) {
          final day = days[i];
          final inMonth = day.month == visibleMonth.month && day.year == visibleMonth.year;
          final key = formatDateKey(day);
          final academic = getAcademicDay(day);
          final events = byDate[key] ?? const [];
          final classes = classesByDate[key] ?? const [];
          return _DayCell(
            day: day,
            inMonth: inMonth,
            academic: academic,
            events: events,
            classes: classes,
            onTap: () => _onDayTap(day),
            onEventTap: (e) => _openForm(EventDraft.fromEvent(e)),
          );
        },
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.weekdayLabel,
    required this.academic,
    required this.events,
    required this.classes,
    required this.onDayTap,
    required this.onEventTap,
    required this.stacked,
  });

  final DateTime day;
  final String weekdayLabel;
  final AcademicDay academic;
  final List<CalendarEvent> events;
  final List<PlannerClass> classes;
  final VoidCallback onDayTap;
  final void Function(CalendarEvent) onEventTap;
  final bool stacked;

  Color? get _dayTint {
    switch (academic.type) {
      case AcademicType.holiday:
        return T.successTint;
      case AcademicType.swapped:
        return T.accentTint;
      case AcademicType.breakPeriod:
        return isExamPeriod(academic.name) ? T.dangerTint : T.surfaceSunk;
      case AcademicType.weekend:
        return T.surfaceSunk;
      default:
        return null;
    }
  }

  ({Color tint, Color ink})? get _academicChipColors {
    switch (academic.type) {
      case AcademicType.holiday:
        return (tint: T.successTint, ink: T.successInk);
      case AcademicType.swapped:
        return (tint: T.tutorialTint, ink: T.tutorialInk);
      case AcademicType.breakPeriod:
        return isExamPeriod(academic.name)
            ? (tint: T.dangerTint, ink: T.danger)
            : (tint: T.surfaceSunk, ink: T.ink3);
      default:
        return null;
    }
  }

  List<({String kind, String sortKey, Object data})> _sortedItems() {
    final items = <({String kind, String sortKey, Object data})>[
      for (final c in classes) (kind: 'class', sortKey: c.start, data: c),
      for (final e in events) (kind: 'event', sortKey: eventSortKey(e), data: e),
    ];
    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  (Color tint, Color ink) _classColors(String kind) {
    switch (kind) {
      case 'tutorial':
        return (T.tutorialTint, T.tutorialInk);
      case 'lab':
        return (T.labTint, T.labInk);
      default:
        return (T.lectureTint, T.lectureInk);
    }
  }

  Widget _weekChipForItem(({String kind, String sortKey, Object data}) item) {
    if (item.kind == 'class') {
      final c = item.data as PlannerClass;
      final colors = _classColors(c.kind);
      return _WeekChip(
        text: '${c.courseCode} ${c.kindLabel} ${c.timeLabel}',
        tint: colors.$1,
        ink: colors.$2,
      );
    }
    final e = item.data as CalendarEvent;
    final schedule = formatEventSchedule(e);
    final label = e.isPersonal
        ? 'You · ${e.title}'
        : (e.courseCode != null && e.courseCode!.isNotEmpty)
            ? '${e.courseCode}: ${e.title}'
            : e.title;
    return _WeekChip(
      text: schedule.isEmpty ? label : '$label · $schedule',
      tint: e.isPersonal ? T.labTint : T.accentTint,
      ink: e.isPersonal ? T.labInk : T.accentInk,
      onTap: () => onEventTap(e),
    );
  }

  Widget _weekItemsBody(List<({String kind, String sortKey, Object data})> items) {
    if (items.isEmpty) {
      return SizedBox(
        height: stacked ? 44 : null,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDayTap,
            child: Center(child: Icon(Icons.add, size: 20, color: T.ink4)),
          ),
        ),
      );
    }
    final chips = [for (final item in items) _weekChipForItem(item)];
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: chips,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = formatDateKey(day) == formatDateKey(DateTime.now());
    final items = _sortedItems();
    final academicLabel = academicCellLabel(academic);
    final academicColors = _academicChipColors;

    final decoration = BoxDecoration(
      color: _dayTint ?? T.surface,
      border: Border.all(
        color: isToday ? T.accent : T.line,
        width: isToday ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(stacked ? T.r : T.rSm),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    weekdayLabel.toUpperCase(),
                    style: AppText.mono(
                      size: T.fs12,
                      color: T.ink3,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${day.day}',
                    style: AppText.mono(
                      size: T.fs16,
                      color: isToday ? T.accentInk : T.ink,
                      weight: isToday ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onDayTap,
                    icon: Icon(Icons.add, size: 18, color: T.ink3),
                    tooltip: 'Add event',
                  ),
                ],
              ),
              if (academicLabel != null && academicColors != null) ...[
                const SizedBox(height: 6),
                _WeekChip(
                  text: academicLabel,
                  tint: academicColors.tint,
                  ink: academicColors.ink,
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        if (stacked)
          _weekItemsBody(items)
        else
          Expanded(child: _weekItemsBody(items)),
      ],
    );

    if (stacked) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: decoration,
        child: column,
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: decoration,
      child: column,
    );
  }
}

class _WeekChip extends StatelessWidget {
  const _WeekChip({
    required this.text,
    required this.tint,
    required this.ink,
    this.onTap,
    this.maxLines = 3,
  });

  final String text;
  final Color tint;
  final Color ink;
  final VoidCallback? onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(T.rSm),
          border: Border.all(color: T.line.withValues(alpha: 0.6)),
        ),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppText.sans(size: T.fs12, color: ink, height: 1.25),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.academic,
    required this.events,
    required this.classes,
    required this.onTap,
    required this.onEventTap,
  });

  final DateTime day;
  final bool inMonth;
  final AcademicDay academic;
  final List<CalendarEvent> events;
  final List<PlannerClass> classes;
  final VoidCallback onTap;
  final void Function(CalendarEvent) onEventTap;

  Color? get _dayTint {
    switch (academic.type) {
      case AcademicType.holiday:
        return T.successTint;
      case AcademicType.swapped:
        return T.accentTint;
      case AcademicType.breakPeriod:
        return isExamPeriod(academic.name) ? T.dangerTint : T.surfaceSunk;
      case AcademicType.weekend:
        return T.surfaceSunk;
      default:
        return null;
    }
  }

  ({Color tint, Color ink})? get _academicChipColors {
    switch (academic.type) {
      case AcademicType.holiday:
        return (tint: T.successTint, ink: T.successInk);
      case AcademicType.swapped:
        return (tint: T.tutorialTint, ink: T.tutorialInk);
      case AcademicType.breakPeriod:
        return isExamPeriod(academic.name)
            ? (tint: T.dangerTint, ink: T.danger)
            : (tint: T.surfaceSunk, ink: T.ink3);
      default:
        return null;
    }
  }

  Widget? _academicChip() {
    final label = academicCellLabel(academic);
    final colors = _academicChipColors;
    if (label == null || colors == null) return null;
    return _chip(label, colors.tint, colors.ink, null, maxLines: 2);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = formatDateKey(day) == formatDateKey(DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(T.rSm),
      child: Container(
        decoration: BoxDecoration(
          color: inMonth ? (_dayTint ?? T.surface) : T.paper2,
          border: Border.all(color: isToday ? T.accent : T.line, width: isToday ? 1.5 : 1),
          borderRadius: BorderRadius.circular(T.rSm),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${day.day}',
                    style: AppText.mono(
                        size: T.fs12,
                        color: inMonth ? T.ink : T.ink4,
                        weight: isToday ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (_academicChip() case final tag?) tag,
                  for (final c in classes.take(2))
                    _chip('${c.kindLabel} ${c.courseCode}', T.lectureTint, T.lectureInk, null),
                  for (final e in events.take(3))
                    _chip(
                      e.isPersonal ? e.title : '${e.courseCode}: ${e.title}',
                      e.isPersonal ? T.labTint : T.accentTint,
                      e.isPersonal ? T.labInk : T.accentInk,
                      () => onEventTap(e),
                    ),
                  if (events.length > 3)
                    Text('+${events.length - 3}', style: AppText.sans(size: 8, color: T.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color tint, Color ink, VoidCallback? onTap, {int maxLines = 1}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: T.line.withValues(alpha: 0.6)),
        ),
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: AppText.sans(size: 8, color: ink, height: 1.2),
        ),
      ),
    );
  }
}

sealed class _DayDialogResult {}

class _DayDialogEdit extends _DayDialogResult {
  _DayDialogEdit(this.event);
  final CalendarEvent event;
}

class _DayDialogAdd extends _DayDialogResult {
  _DayDialogAdd(this.mode);
  final String mode; // shared | personal
}

/// Day tap: lists classes and events on that date; tap an event to edit.
class _DayEventsDialog extends StatelessWidget {
  const _DayEventsDialog({
    required this.day,
    required this.academic,
    required this.events,
    required this.classes,
  });

  final DateTime day;
  final AcademicDay academic;
  final List<CalendarEvent> events;
  final List<PlannerClass> classes;

  static ({String title, String subtitle, IconData icon, Color iconColor})? _academicEntry(
    AcademicDay info,
  ) {
    switch (info.type) {
      case AcademicType.holiday:
        return (
          title: info.name ?? 'Holiday',
          subtitle: 'Institute holiday · No classes',
          icon: Icons.event_busy_outlined,
          iconColor: T.successInk,
        );
      case AcademicType.swapped:
        return (
          title: 'Timetable swap',
          subtitle: describeAcademicDay(info),
          icon: Icons.swap_horiz,
          iconColor: T.tutorialInk,
        );
      case AcademicType.breakPeriod:
        return (
          title: info.name ?? 'No classes',
          subtitle: 'No regular classes scheduled',
          icon: isExamPeriod(info.name) ? Icons.quiz_outlined : Icons.beach_access_outlined,
          iconColor: isExamPeriod(info.name) ? T.danger : T.ink3,
        );
      case AcademicType.beforeTerm:
      case AcademicType.afterTerm:
        return (
          title: info.type == AcademicType.beforeTerm ? 'Before term' : 'After term',
          subtitle: describeAcademicDay(info),
          icon: Icons.info_outline,
          iconColor: T.ink3,
        );
      default:
        return null;
    }
  }

  void _addSectionDivider(List<Widget> items) {
    if (items.isEmpty) return;
    items.add(const SizedBox(height: 12));
    items.add(const Divider(height: 1));
    items.add(const SizedBox(height: 8));
  }

  static String _classKindLabel(String kind) {
    switch (kind) {
      case 'lecture':
        return 'Lecture';
      case 'tutorial':
        return 'Tutorial';
      case 'lab':
        return 'Lab';
      default:
        return kind;
    }
  }

  static String _classTimeRange(PlannerClass c) {
    String fmt(String hhmm) {
      if (hhmm.length != 4) return hhmm;
      return '${hhmm.substring(0, 2)}:${hhmm.substring(2)}';
    }

    return '${fmt(c.start)} – ${fmt(c.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (showAcademicInDayDialog(academic)) {
      final entry = _academicEntry(academic);
      if (entry != null) {
        items.add(Text(
          'Institute calendar',
          style: AppText.sans(size: T.fs12, color: T.ink3, weight: FontWeight.w600),
        ));
        items.add(const SizedBox(height: 4));
        items.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(entry.icon, color: entry.iconColor, size: 22),
            title: Text(
              entry.title,
              style: AppText.sans(weight: FontWeight.w600, size: T.fs14),
            ),
            subtitle: Text(
              entry.subtitle,
              style: AppText.sans(size: T.fs12, color: T.ink3),
            ),
          ),
        );
      }
    }

    if (classes.isNotEmpty) {
      _addSectionDivider(items);
      items.add(Text('Classes', style: AppText.sans(size: T.fs12, color: T.ink3, weight: FontWeight.w600)));
      items.add(const SizedBox(height: 4));
      for (final c in classes) {
        final dateKey = formatDateKey(day);
        final rKey = classReminderKey(dateKey, c);
        items.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule_outlined, color: T.lectureInk, size: 22),
            title: Text(
              c.courseCode,
              style: AppText.mono(weight: FontWeight.w600, size: T.fs14),
            ),
            subtitle: Text(
              '${_classKindLabel(c.kind)} · ${_classTimeRange(c)}',
              style: AppText.sans(size: T.fs12, color: T.ink3),
            ),
            trailing: ReminderToggle(
              reminderKey: rKey,
              canEnable: canRemindClass(c, day),
              onToggle: () => context.read<ReminderStore>().toggleClass(c, day),
            ),
          ),
        );
      }
    }

    if (events.isNotEmpty) {
      _addSectionDivider(items);
      items.add(Text('Events', style: AppText.sans(size: T.fs12, color: T.ink3, weight: FontWeight.w600)));
      items.add(const SizedBox(height: 4));
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        final schedule = formatEventSchedule(e);
        final typeLabel = kEventTypeLabels[e.type] ?? e.type;
        if (i > 0) items.add(const Divider(height: 1));
        final eKey = eventReminderKey(e);
        items.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.isPersonal ? Icons.person_outline : Icons.school_outlined,
              color: e.isPersonal ? T.labInk : T.accentInk,
              size: 22,
            ),
            title: Text(
              e.title,
              style: AppText.sans(weight: FontWeight.w600, size: T.fs14),
            ),
            subtitle: Text(
              [
                if (!e.isPersonal && (e.courseCode?.isNotEmpty ?? false)) e.courseCode!,
                typeLabel,
                if (schedule.isNotEmpty) schedule,
              ].join(' · '),
              style: AppText.sans(size: T.fs12, color: T.ink3),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReminderToggle(
                  reminderKey: eKey,
                  canEnable: canRemindEvent(e),
                  tooltipDisabled: 'All-day / EOD events have no start-time reminder',
                  onToggle: () => context.read<ReminderStore>().toggleEvent(e),
                ),
                Icon(Icons.chevron_right, size: 20, color: T.ink4),
              ],
            ),
            onTap: () => Navigator.pop(context, _DayDialogEdit(e)),
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(Text(
        'Nothing scheduled on this day.',
        style: AppText.sans(size: T.fs14, color: T.ink3),
      ));
    }

    return AlertDialog(
      title: Text(DateFormat('EEEE, d MMMM').format(day), style: AppText.serif(size: T.fs18)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: items,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _DayDialogAdd('shared')),
          child: const Text('Add course event'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DayDialogAdd('personal')),
          child: const Text('Add personal event'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
