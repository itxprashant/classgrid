import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/reminder_schedule.dart';
import '../storage/reminder_store.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink),
        ),
      ),
      body: Material(
        color: T.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            PageHeader(
              eyebrow: 'Reminders',
              title: 'Before class',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Class reminders on the Calendar tab fire this long before a session starts. '
                'Notifications show the course, session type, venue, and start time.',
                style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
          ],
        ),
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
