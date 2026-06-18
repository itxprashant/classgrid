import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/reminder_schedule.dart';
import '../state/theme_controller.dart';
import '../storage/attendance_store.dart';
import '../storage/reminder_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import 'notification_settings_screen.dart';
import 'theme_settings_screen.dart';

/// Settings hub — categories open dedicated preference screens.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final theme = context.watch<ThemeController>();
    final reminders = context.watch<ReminderStore>();
    final attendance = context.watch<AttendanceStore>();
    final themeLabel = AppPalettes.byId(theme.currentId).label;
    final leadTime = formatReminderLeadTime(reminders.minutesBefore);
    final attendanceNotify = attendance.markNotifyEnabled ? 'On' : 'Off';

    return ScreenShell(
      eyebrow: 'Preferences',
      title: 'Settings',
      subtitle: Text(
        'Customize how ClassGrid looks and notifies you.',
        style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: T.space32),
        children: [
          SettingsSection(
            label: 'Appearance',
            children: [
              SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: themeLabel,
                onTap: () => pushAppRoute<void>(
                  context,
                  const ThemeSettingsScreen(),
                ),
              ),
            ],
          ),
          const SizedBox(height: T.space24),
          SettingsSection(
            label: 'Notifications',
            children: [
              SettingsRow(
                icon: Icons.notifications_outlined,
                title: 'Class reminders',
                subtitle: '$leadTime before start',
                onTap: () => pushAppRoute<void>(
                  context,
                  const NotificationSettingsScreen(),
                ),
              ),
              SettingsRow(
                icon: Icons.fact_check_outlined,
                title: 'Attendance prompts',
                subtitle: attendance.markNotifyEnabled
                    ? 'Post-class mark reminders · $attendanceNotify'
                    : 'Off · enable to get post-class mark reminders',
                onTap: () => pushAppRoute<void>(
                  context,
                  const NotificationSettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
