import 'package:flutter/material.dart';

import '../core/calendar_events.dart';
import '../core/feedback.dart';
import '../models/actor.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'report_content_sheet.dart';

class CourseOption {
  final String courseCode;
  final String courseName;
  const CourseOption(this.courseCode, this.courseName);
}

enum EventFormAction { save, delete }

class EventFormResult {
  final EventFormAction action;
  final EventDraft draft;
  const EventFormResult(this.action, this.draft);
}

/// Create/edit form for a calendar event (shared or personal). Replicates the
/// web My Calendar form: type, course (shared only), title, schedule + time
/// fields, note, with the same validation/submit guard.
class EventFormSheet extends StatefulWidget {
  const EventFormSheet({
    super.key,
    required this.draft,
    required this.courseOptions,
    required this.canWrite,
  });

  final EventDraft draft;
  final List<CourseOption> courseOptions;

  /// Whether the user may persist (logged in for personal; always allowed to
  /// attempt shared, but guests are prompted to log in by the caller).
  final bool canWrite;

  static Future<EventFormResult?> show(
    BuildContext context, {
    required EventDraft draft,
    required List<CourseOption> courseOptions,
    required bool canWrite,
  }) {
    return showModalBottomSheet<EventFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFormSheet(
        draft: draft,
        courseOptions: courseOptions,
        canWrite: canWrite,
      ),
    );
  }

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  late EventDraft d;

  @override
  void initState() {
    super.initState();
    d = widget.draft;
  }

  bool get _editing => d.id != null;

  Future<void> _onDelete() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete event?',
      message: 'This removes "${d.title.isNotEmpty ? d.title : 'this event'}" from your calendar.',
      confirmLabel: 'Delete',
    );
    if (confirmed && mounted) {
      Navigator.pop(context, EventFormResult(EventFormAction.delete, d));
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final submittable = isDraftSubmittable(d);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: T.surface,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: T.space8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(T.space16, T.space12, T.space16, T.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_editing ? 'Edit' : 'New'} ${d.isPersonal ? 'personal' : 'course'} event',
                            style: AppText.serif(size: T.fs21, weight: FontWeight.w600, color: T.ink),
                          ),
                          const SizedBox(height: T.space4),
                          Text(d.date, style: AppText.mono(size: T.fs12, color: T.ink3)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 20, color: T.ink3),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              if (_editing &&
                  (widget.draft.createdBy != null || widget.draft.updatedBy != null))
                Padding(
                  padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.draft.createdBy != null)
                        _EventActorLine(
                          label: 'Added by',
                          actor: widget.draft.createdBy!,
                        ),
                      if (widget.draft.updatedBy != null &&
                          !actorsMatch(widget.draft.createdBy, widget.draft.updatedBy))
                        _EventActorLine(
                          label: 'Last edited by',
                          actor: widget.draft.updatedBy!,
                        ),
                    ],
                  ),
                ),
              if (d.isPersonal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space8),
                  child: Text(
                    'Only you can see this event.',
                    style: AppText.sans(size: T.fs12, color: T.ink3),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Type'),
                      DropdownButtonFormField<String>(
                        initialValue: d.type,
                        isExpanded: true,
                        items: [
                          for (final t in kEventTypes)
                            DropdownMenuItem(value: t, child: Text(kEventTypeLabels[t] ?? t)),
                        ],
                        onChanged: (v) => setState(() => d.type = v ?? d.type),
                      ),
                      const SizedBox(height: 12),
                      if (!d.isPersonal) ...[
                        _label('Course'),
                        DropdownButtonFormField<String>(
                          initialValue: widget.courseOptions.any((o) => o.courseCode == d.courseCode)
                              ? d.courseCode
                              : null,
                          isExpanded: true,
                          hint: const Text('Select a course'),
                          items: [
                            for (final o in widget.courseOptions)
                              DropdownMenuItem(
                                value: o.courseCode,
                                child: Text('${o.courseCode} — ${o.courseName}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => d.courseCode = v ?? ''),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _label('Title'),
                      TextFormField(
                        initialValue: d.title,
                        onChanged: (v) => setState(() => d.title = v),
                        decoration: const InputDecoration(hintText: 'e.g. Quiz 2'),
                      ),
                      const SizedBox(height: 12),
                      _label('Schedule'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in kEventSchedules)
                            AppChoiceChip(
                              label: kScheduleLabels[s] ?? s,
                              selected: d.schedule == s,
                              onSelected: (_) => setState(() => d.schedule = s),
                            ),
                        ],
                      ),
                      if (d.schedule == 'at') ...[
                        const SizedBox(height: 12),
                        _label('Time'),
                        _timeField(d.time, (v) => setState(() => d.time = v)),
                      ],
                      if (d.schedule == 'timed') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Start'),
                                  _timeField(d.start, (v) => setState(() => d.start = v)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('End'),
                                  _timeField(d.end, (v) => setState(() => d.end = v)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!isDraftScheduleValid(d))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('End must be after start.',
                                style: AppText.sans(size: T.fs12, color: T.danger)),
                          ),
                      ],
                      const SizedBox(height: 12),
                      _label('Note (optional)'),
                      TextFormField(
                        initialValue: d.note,
                        onChanged: (v) => d.note = v,
                        maxLines: 2,
                        decoration: const InputDecoration(hintText: 'Anything else…'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
                child: Row(
                  children: [
                    if (_editing && !d.isPersonal && d.id != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ReportContentSheet.show(
                            context,
                            targetKind: 'course_event',
                            targetId: d.id!,
                            contextLabel: reportContextForEvent(
                              courseCode: d.courseCode,
                              title: d.title,
                              date: d.date,
                            ),
                          );
                        },
                        icon: Icon(Icons.flag_outlined, size: 18, color: T.ink2),
                        label: Text('Report', style: AppText.sans(color: T.ink2)),
                      ),
                    if (_editing)
                      TextButton.icon(
                        onPressed: _onDelete,
                        icon: Icon(Icons.delete_outline, size: 18, color: T.danger),
                        label: Text('Delete', style: AppText.sans(color: T.danger)),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: submittable
                          ? () => Navigator.pop(
                              context, EventFormResult(EventFormAction.save, d))
                          : null,
                      child: Text(widget.canWrite || d.isPersonal ? 'Save' : 'Log in to add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: AppText.sans(size: T.fs12, color: T.ink2)),
      );

  Widget _timeField(String value, ValueChanged<String> onChanged) {
    return InkWell(
      onTap: () async {
        final initial = value.length == 4
            ? TimeOfDay(hour: int.parse(value.substring(0, 2)), minute: int.parse(value.substring(2)))
            : TimeOfDay.now();
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          onChanged('${picked.hour.toString().padLeft(2, '0')}${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(suffixIcon: Icon(Icons.schedule, size: 18)),
        child: Text(
          value.length == 4 ? hhmmToInput(value) : 'Pick a time',
          style: AppText.mono(size: T.fs14, color: value.length == 4 ? T.ink : T.ink3),
        ),
      ),
    );
  }
}

class _EventActorLine extends StatelessWidget {
  const _EventActorLine({required this.label, required this.actor});

  final String label;
  final Actor actor;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final info = formatEventActor(actor);
    if (info == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: AppText.sans(size: T.fs12, color: T.ink3, height: 1.35),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: info.who,
              style: AppText.mono(size: T.fs12, color: T.ink2),
            ),
            if (info.when.isNotEmpty)
              TextSpan(
                text: '  ${info.when}',
                style: AppText.mono(size: T.fs11, color: T.ink4),
              ),
          ],
        ),
      ),
    );
  }
}
