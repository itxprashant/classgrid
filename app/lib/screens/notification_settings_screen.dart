import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/reminder_schedule.dart';
import '../storage/attendance_store.dart';
import '../storage/reminder_store.dart';
import '../state/planner_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Class reminder timing and related notification preferences.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final reminders = context.watch<ReminderStore>();
    final attendance = context.watch<AttendanceStore>();
    final planner = context.read<PlannerStore>();

    return ScreenShell(
      eyebrow: 'Reminders',
      title: 'Notifications',
      subtitle: Text(
        'Class reminders on the Calendar tab fire before a session starts. '
        'Attendance prompts remind you to mark after class ends.',
        style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: T.space32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(T.space16),
              decoration: BoxDecoration(
                color: T.surface,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.rLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remind me before class',
                    style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Currently ${formatReminderLeadTime(reminders.minutesBefore)} before start',
                    style: AppText.mono(size: T.fs12, color: T.ink3),
                  ),
                  const SizedBox(height: T.space12),
                  Wrap(
                    spacing: T.space8,
                    runSpacing: T.space8,
                    children: [
                      for (final minutes in kReminderMinutesOptions)
                        _LeadTimeChip(
                          minutes: minutes,
                          selected: reminders.minutesBefore == minutes,
                          onSelected: () => _selectLeadTime(context, reminders, minutes),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: T.space24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(T.space16),
              decoration: BoxDecoration(
                color: T.surface,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.rLg),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Post-class attendance prompts',
                  style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
                ),
                subtitle: Text(
                  'Local reminder when a planned class ends',
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
                value: attendance.markNotifyEnabled,
                onChanged: (v) async {
                  await attendance.setMarkNotifyEnabled(v);
                  await attendance.onPlannerChanged(
                    courses: planner.selectedCourses,
                    timetableData: planner.timetableData,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectLeadTime(
    BuildContext context,
    ReminderStore store,
    int minutes,
  ) async {
    if (minutes == store.minutesBefore) return;
    await store.setMinutesBefore(minutes);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminders set to ${formatReminderLeadTime(minutes)} before class')),
    );
  }
}

class _LeadTimeChip extends StatelessWidget {
  const _LeadTimeChip({
    required this.minutes,
    required this.selected,
    required this.onSelected,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(T.r),
        child: AnimatedContainer(
          duration: T.tBase,
          curve: T.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: T.space12, vertical: T.space8),
          decoration: BoxDecoration(
            color: selected ? T.accentTint : T.paper2,
            borderRadius: BorderRadius.circular(T.r),
            border: Border.all(
              color: selected ? T.accent : T.lineStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '${minutes}m',
            style: AppText.mono(
              size: T.fs13,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? T.accentInk : T.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
