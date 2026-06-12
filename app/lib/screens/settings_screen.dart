import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/reminder_schedule.dart';
import '../state/theme_controller.dart';
import '../storage/reminder_store.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/palettes.dart';
import '../theme/tokens.dart';
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
    final themeLabel = AppPalettes.byId(theme.currentId).label;
    final leadTime = formatReminderLeadTime(reminders.minutesBefore);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink),
        ),
      ),
      body: Material(
        color: T.paper,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            PageHeader(
              eyebrow: 'Preferences',
              title: 'Make it yours.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Text(
                'Customize how ClassGrid looks and notifies you.',
                style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
              ),
            ),
            _SettingsSection(
              label: 'APPEARANCE',
              children: [
                _SettingsNavTile(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  subtitle: themeLabel,
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              label: 'NOTIFICATIONS',
              children: [
                _SettingsNavTile(
                  icon: Icons.notifications_outlined,
                  title: 'Class reminders',
                  subtitle: '$leadTime before start',
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            label,
            style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: T.surface,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.rLg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: T.line),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: T.accentInk),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.mono(size: T.fs12, color: T.ink3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: T.ink4),
            ],
          ),
        ),
      ),
    );
  }
}
