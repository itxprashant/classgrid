import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

const List<String> _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday'
];

List<String> _timeOptions() {
  final out = <String>[];
  for (int h = 8; h <= 21; h++) {
    for (final m in ['00', '30']) {
      if (h == 21 && m == '30') continue;
      out.add('${h.toString().padLeft(2, '0')}$m');
    }
  }
  return out;
}

final _timeValues = _timeOptions();

class _Editable {
  String day;
  String start;
  String end;
  String location;
  _Editable({required this.day, required this.start, required this.end, this.location = ''});
}

/// Tutorial/lab session picker. Mirrors the web EditTiming component: add/remove
/// sessions, day + start/end selects (08:00–21:00, 30-min steps), venue input,
/// and a Save that keeps only valid sessions (day picked, start < end).
class EditTimingSheet extends StatefulWidget {
  const EditTimingSheet({
    super.key,
    required this.course,
    required this.current,
  });

  final SelectedCourse course;
  final CourseTimetable current;

  /// Returns the new tutorial/lab lists (null = clear) keyed by 'tutorial'/'lab'.
  static Future<Map<String, List<Session>?>?> show(
    BuildContext context, {
    required SelectedCourse course,
    required CourseTimetable current,
  }) {
    return showModalBottomSheet<Map<String, List<Session>?>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditTimingSheet(course: course, current: current),
    );
  }

  @override
  State<EditTimingSheet> createState() => _EditTimingSheetState();
}

class _EditTimingSheetState extends State<EditTimingSheet> {
  late List<_Editable> _tutorials;
  late List<_Editable> _labs;

  @override
  void initState() {
    super.initState();
    _tutorials = (widget.current.tutorial ?? const [])
        .map((s) => _Editable(day: s.day.isEmpty ? '0' : s.day, start: s.start, end: s.end, location: s.location ?? ''))
        .toList();
    _labs = (widget.current.lab ?? const [])
        .map((s) => _Editable(day: s.day.isEmpty ? '0' : s.day, start: s.start, end: s.end, location: s.location ?? ''))
        .toList();
  }

  List<Session>? _valid(List<_Editable> items) {
    final out = items
        .where((t) =>
            t.day != '0' &&
            t.start.isNotEmpty &&
            t.end.isNotEmpty &&
            int.parse(t.start) < int.parse(t.end))
        .map((t) => Session(day: t.day, start: t.start, end: t.end, location: t.location))
        .toList();
    return out.isEmpty ? null : out;
  }

  void _save() {
    final result = <String, List<Session>?>{};
    if (widget.course.tutorial) result['tutorial'] = _valid(_tutorials);
    if (widget.course.lab) result['lab'] = _valid(_labs);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: T.line, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit sessions', style: AppText.serif(size: T.fs18)),
                        Text(widget.course.courseCode, style: AppText.mono(size: T.fs12, color: T.ink3)),
                      ],
                    ),
                  ),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (widget.course.tutorial)
                    _sessionSection('Tutorials', _tutorials, () {
                      setState(() => _tutorials.add(_Editable(day: '0', start: '0800', end: '0900')));
                    }, (i) => setState(() => _tutorials.removeAt(i))),
                  if (widget.course.lab)
                    _sessionSection('Labs', _labs, () {
                      setState(() => _labs.add(_Editable(day: '0', start: '1400', end: '1600')));
                    }, (i) => setState(() => _labs.removeAt(i))),
                  if (!widget.course.tutorial && !widget.course.lab)
                    Text('This course has no tutorial or lab component.',
                        style: AppText.sans(size: T.fs13, color: T.ink3)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sessionSection(
    String title,
    List<_Editable> items,
    VoidCallback onAdd,
    void Function(int) onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(title, style: AppText.sans(size: T.fs16, weight: FontWeight.w600))),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 16), label: const Text('Add session')),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('No ${title.toLowerCase()} added.', style: AppText.sans(size: T.fs13, color: T.ink3)),
          )
        else
          for (int i = 0; i < items.length; i++) _sessionCard(title, items[i], i, onRemove),
      ],
    );
  }

  Widget _sessionCard(String title, _Editable s, int index, void Function(int) onRemove) {
    final label = title.substring(0, title.length - 1); // Tutorials -> Tutorial
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('$label ${index + 1}', style: AppText.mono(size: T.fs12, color: T.ink2))),
              InkWell(
                onTap: () => onRemove(index),
                child: Text('Remove', style: AppText.sans(size: T.fs12, color: T.danger)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dropdown('Day', s.day, ['0', ..._days], (v) => setState(() => s.day = v!), dayLabels: true)),
              const SizedBox(width: 8),
              Expanded(child: _dropdown('Start', _timeValues.contains(s.start) ? s.start : _timeValues.first, _timeValues, (v) => setState(() => s.start = v!), time: true)),
              const SizedBox(width: 8),
              Expanded(child: _dropdown('End', _timeValues.contains(s.end) ? s.end : _timeValues.last, _timeValues, (v) => setState(() => s.end = v!), time: true)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: s.location,
            onChanged: (v) => s.location = v,
            style: AppText.mono(size: T.fs13),
            decoration: InputDecoration(
              labelText: 'Venue',
              hintText: label == 'Tutorial' ? 'e.g. IIA 201' : 'e.g. LH 111',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged,
      {bool dayLabels = false, bool time = false}) {
    String labelFor(String v) {
      if (dayLabels) return v == '0' ? '—' : v.substring(0, 3);
      if (time) return '${v.substring(0, 2)}:${v.substring(2)}';
      return v;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.sans(size: T.fs12, color: T.ink3)),
        const SizedBox(height: 2),
        DropdownButtonFormField<String>(
          initialValue: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(labelFor(o), style: AppText.mono(size: T.fs12))),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
