import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// App info, features, and links. Opened from the navigation drawer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _siteUrl = 'https://classgrid.devclub.in';

  Future<void> _openSite(BuildContext context) async {
    final uri = Uri.parse(_siteUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About',
          style: AppText.serif(size: T.fs18, weight: FontWeight.w600, color: T.ink),
        ),
      ),
      body: Material(
        color: T.paper,
        child: ListView(
          children: [
            PageHeader(
              eyebrow: 'ClassGrid',
              title: 'Your semester, on one grid.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ClassGrid helps IIT Delhi students build a weekly plan from '
                'the offered-courses catalog, spot clashes, find free rooms, and keep '
                'course and personal events on one calendar.',
                style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'FEATURES',
                style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: 8),
            _AboutFeature(
              icon: Icons.login,
              title: 'Sign in with IITD',
              body: 'OAuth pulls your registered courses onto the plan (synced when signed in).',
            ),
            _AboutFeature(
              icon: Icons.grid_view,
              title: 'Weekly timetable',
              body: 'Color-coded lecture, tutorial, and lab slots with clash detection.',
            ),
            _AboutFeature(
              icon: Icons.meeting_room_outlined,
              title: 'Empty halls & rooms',
              body: 'See which campus rooms are free at a chosen date and time.',
            ),
            _AboutCalendarSection(),
            _AboutFeature(
              icon: Icons.notifications_outlined,
              title: 'Local reminders',
              body: 'On the Calendar tab, tap a day and use the bell beside a class or timed event. '
                  'You get a local notification before it starts (timing is configurable in Settings). '
                  'When signed in, reminders sync to your account via the API.',
            ),
            _AboutFeature(
              icon: Icons.ios_share_outlined,
              title: 'ICS export',
              body: 'Share your plan as a calendar file from the Plan tab.',
            ),
            const SizedBox(height: 16),
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
                    Text('Website', style: AppText.sans(size: T.fs13, color: T.ink3)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _siteUrl,
                      style: AppText.mono(size: T.fs14, color: T.accentInk),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _openSite(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open ClassGrid'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  final info = snap.data;
                  final appLabel = info == null
                      ? 'Mobile app'
                      : 'Mobile app v${info.version}+${info.buildNumber}';
                  return Text(
                    '$appLabel · API ${AppConfig.apiBase.replaceFirst('https://', '')}',
                    style: AppText.mono(size: T.fs12, color: T.ink4),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep dive on the Calendar tab — matches [CalendarScreen] behaviour.
class _AboutCalendarSection extends StatelessWidget {
  const _AboutCalendarSection();

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.calendar_month_outlined, size: 22, color: T.accentInk),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Calendar',
                  style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A semester month view for deadlines, quizzes, and your own notes. '
            'Open it from the bottom Calendar tab.',
            style: AppText.sans(size: T.fs13, color: T.ink2, height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.surface,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.rLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TWO KINDS OF EVENTS',
                  style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.1),
                ),
                const SizedBox(height: 8),
                _AboutBullet(
                  'Course events are shared for a course code — quizzes, deadlines, exams, '
                  'extra classes, presentations, and more. Anyone planning or enrolled in '
                  'that course can see them. Sign in to add or edit; they are stored on the '
                  'ClassGrid server.',
                ),
                _AboutBullet(
                  'Personal events are private to you — study blocks, reminders, anything '
                  'not tied to a course. Signed-in users sync them to your account; as a '
                  'guest they stay on this device only.',
                ),
                _AboutBullet(
                  'The grid only loads events for courses on your plan plus your enrolled '
                  'courses (when logged in), not the entire catalog.',
                ),
                const SizedBox(height: 14),
                Text(
                  'TAP A DAY',
                  style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.1),
                ),
                const SizedBox(height: 8),
                _AboutBullet(
                  'Opens a summary for that date: institute calendar notes (holiday, '
                  'timetable swap, exam week, or break), your classes, and every event.',
                ),
                _AboutBullet(
                  'Add course event or Add personal event starts the form. Tap an existing '
                  'event to edit or delete it.',
                ),
                _AboutBullet(
                  'When creating an event, pick a schedule: All day, At a time, Timed '
                  '(start–end), or EOD (end of day). Reminders work for At and Timed only.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: T.accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.sans(size: T.fs13, color: T.ink3, height: 1.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: T.accentInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sans(size: T.fs14, weight: FontWeight.w600, color: T.ink)),
                const SizedBox(height: 2),
                Text(body, style: AppText.sans(size: T.fs13, color: T.ink3, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
