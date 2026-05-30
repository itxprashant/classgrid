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
import '../widgets/academic_calendar_sheet.dart';
import '../widgets/common.dart';
import '../widgets/event_form_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first day of the visible month
  int _slideDirection = 1; // 1 = forward, -1 = back (for slide animation)
  double _monthSwipeDx = 0;
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
    final days = _gridDays();
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

  void _onMonthSwipeEnd(DragEndDetails details) {
    const minDragPx = 56.0;
    const velocityThreshold = 350.0;
    final v = details.primaryVelocity ?? 0;
    if (_monthSwipeDx <= -minDragPx || v < -velocityThreshold) {
      _changeMonth(1);
    } else if (_monthSwipeDx >= minDragPx || v > velocityThreshold) {
      _changeMonth(-1);
    }
    _monthSwipeDx = 0;
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
    final days = _gridDays();
    final classesByDate = _showClasses
        ? buildClassesByDate(days, planner.selectedCourses, planner.timetableData)
        : const <String, List<PlannerClass>>{};
    final monthKey = '${_month.year}-${_month.month}';

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        children: [
          PageHeader(
            eyebrow: 'Calendar',
            title: DateFormat('MMMM yyyy').format(_month),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
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
          _animatedMonth(byDate, classesByDate, monthKey),
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
          onHorizontalDragUpdate: (details) => _monthSwipeDx += details.delta.dx,
          onHorizontalDragEnd: _onMonthSwipeEnd,
          onHorizontalDragCancel: () => _monthSwipeDx = 0,
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
            trailing: Icon(Icons.chevron_right, size: 20, color: T.ink4),
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
