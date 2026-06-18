import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/semester_schedule.dart';
import '../models/academic_day.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/academic_day_colors.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Read-only bottom sheet listing holidays, timetable swaps, and breaks for the
/// semester. Mirrors the web "Holidays & timetable changes" modal.
class AcademicCalendarSheet extends StatelessWidget {
  const AcademicCalendarSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AcademicCalendarSheet(),
    );
  }

  String _fmt(String key) =>
      DateFormat('EEE, d MMM y').format(parseDateKey(key));

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final swaps = kScheduleExceptions.keys.toList()..sort();
    final holidays = kHolidays.keys.toList()..sort();
    final holidayStyle = AcademicDayColors.forType(AcademicType.holiday);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: T.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holidays & timetable changes',
                      style: AppText.serif(size: T.fs21, color: T.ink)),
                  const SizedBox(height: 2),
                  Text(
                    '${Semester.label} · ${_fmt(Semester.classesStart)} – ${_fmt(Semester.lastTeachingDay)}',
                    style: AppText.mono(size: T.fs12, color: T.ink3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _summary(swaps.length, holidays.length),
                  const SizedBox(height: 16),
                  _section('Timetable changes', [
                    for (final key in swaps)
                      _row(_fmt(key),
                          'Runs as per ${kScheduleExceptions[key]} timetable',
                          tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
                  ]),
                  const SizedBox(height: 16),
                  _section('Holidays', [
                    for (final key in holidays)
                      _row(_fmt(key), kHolidays[key]!,
                          tint: holidayStyle.tint,
                          edge: holidayStyle.edge,
                          ink: holidayStyle.ink),
                  ]),
                  const SizedBox(height: 16),
                  _section('Breaks & examinations', [
                    for (final p in kNoClassPeriods)
                      _row(
                        '${_fmt(p.start)} – ${_fmt(p.end)}',
                        p.name,
                        tint: isExamPeriod(p.name) ? T.dangerTint : T.surfaceSunk,
                        edge: isExamPeriod(p.name) ? T.dangerEdge : T.line,
                        ink: isExamPeriod(p.name) ? T.danger : T.ink2,
                      ),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Holiday and working-day changes follow the institute academic calendar and may be revised by government notification.',
                    style: AppText.sans(size: T.fs12, color: T.ink3),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(int swapCount, int holidayCount) {
    Widget card(String label, String value) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.surface,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppText.mono(size: T.fs18, color: T.ink)),
                const SizedBox(height: 2),
                Text(label, style: AppText.sans(size: T.fs12, color: T.ink3)),
              ],
            ),
          ),
        );
    return Row(children: [
      card('Holidays', '$holidayCount'),
      card('Swaps', '$swapCount'),
      card('Breaks', '${kNoClassPeriods.length}'),
    ]);
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          Text('None', style: AppText.sans(size: T.fs13, color: T.ink3))
        else
          ...rows,
      ],
    );
  }

  Widget _row(String date, String label,
      {required Color tint, required Color edge, required Color ink}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: T.surface,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.sans(size: T.fs14)),
                const SizedBox(height: 2),
                Text(date, style: AppText.mono(size: T.fs12, color: T.ink3)),
              ],
            ),
          ),
          Pill('•', tint: tint, edge: edge, ink: ink),
        ],
      ),
    );
  }
}
