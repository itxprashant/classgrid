import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../storage/reminder_store.dart';
import '../theme/tokens.dart';

/// Bell control for a schedulable calendar row (class or timed event).
class ReminderToggle extends StatelessWidget {
  const ReminderToggle({
    super.key,
    required this.reminderKey,
    required this.canEnable,
    required this.onToggle,
    this.tooltipDisabled = 'No timed start — reminder unavailable',
  });

  final String reminderKey;
  final bool canEnable;
  final Future<ReminderToggleResult> Function() onToggle;
  final String tooltipDisabled;

  static String messageFor(ReminderToggleResult r) {
    switch (r) {
      case ReminderToggleResult.enabled:
        return 'Reminder on · 30 minutes before';
      case ReminderToggleResult.disabled:
        return 'Reminder off';
      case ReminderToggleResult.tooLate:
        return 'Too late to schedule (needs 30+ minutes notice)';
      case ReminderToggleResult.unsupported:
        return 'Reminders need a specific start time';
      case ReminderToggleResult.failed:
        return 'Could not schedule notification — check app permissions';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ReminderStore>();
    final enabled = store.isEnabled(reminderKey);
    final active = enabled && canEnable;

    return IconButton(
      icon: Icon(
        active ? Icons.notifications_active_outlined : Icons.notifications_outlined,
        size: 22,
        color: active ? T.accentInk : (canEnable ? T.ink3 : T.ink4),
      ),
      tooltip: !canEnable
          ? tooltipDisabled
          : (active ? 'Turn off 30‑min reminder' : 'Remind me 30 minutes before'),
      onPressed: !canEnable && !enabled
          ? null
          : () async {
              final result = await onToggle();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(messageFor(result)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
    );
  }
}
