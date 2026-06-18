import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/common.dart';
import 'feedback_screen.dart';

/// App info, features, and links. Opened from the navigation drawer.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static const _siteUrl = 'https://classgrid.devclub.in';
  static final Future<PackageInfo> packageInfoFuture = PackageInfo.fromPlatform();

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Future<void> _openSite() async {
    final uri = Uri.parse(AboutScreen._siteUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the website.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return ScreenShell(
      eyebrow: 'ClassGrid',
      title: 'Your semester, on one grid.',
      body: ListView(
        padding: const EdgeInsets.only(bottom: T.space32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16),
            child: Text(
              'ClassGrid helps IIT Delhi students build a weekly plan from '
              'the offered-courses catalog, spot clashes, find free rooms, and keep '
              'course and personal events on one calendar.',
              style: AppText.sans(size: T.fs14, color: T.ink2, height: 1.45),
            ),
          ),
          const SizedBox(height: T.space24),
          const SectionHeader('Features'),
          const SizedBox(height: T.space4),
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
          _AboutFeature(
            icon: Icons.fact_check_outlined,
            title: 'Attendance tracker',
            body: 'Mark present, absent, or excused per session. Syncs when signed in.',
          ),
          _AboutFeature(
            icon: Icons.calculate_outlined,
            title: 'CGPA calculator',
            body: 'Project semester SGPA and cumulative CGPA from your plan credits.',
          ),
          const _AboutCalendarSection(),
          _AboutFeature(
            icon: Icons.notifications_outlined,
            title: 'Local reminders',
            body: 'On the Calendar tab, tap a day and use the bell beside a class or timed event. '
                'Timing is configurable in Settings. When signed in, reminders sync via the API.',
          ),
          _AboutFeature(
            icon: Icons.palette_outlined,
            title: 'Themes',
            body: 'Pick from several paper-planner palettes in Settings.',
          ),
          _AboutFeature(
            icon: Icons.ios_share_outlined,
            title: 'ICS export',
            body: 'Share your plan as a calendar file from the Plan tab.',
          ),
          const SizedBox(height: T.space16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space16),
            child: AppCard(
              padding: const EdgeInsets.all(T.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Website', style: AppText.sans(size: T.fs13, color: T.ink3)),
                  const SizedBox(height: T.space4),
                  SelectableText(
                    AboutScreen._siteUrl,
                    style: AppText.mono(size: T.fs14, color: T.accentInk),
                  ),
                  const SizedBox(height: T.space12),
                  FilledButton.icon(
                    onPressed: _openSite,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open ClassGrid'),
                  ),
                  const SizedBox(height: T.space12),
                  TextButton(
                    onPressed: () => pushAppRoute<void>(context, const FeedbackScreen()),
                    child: const Text('Suggest a feature'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: T.space16),
          Padding(
            padding: const EdgeInsets.fromLTRB(T.space16, 0, T.space16, T.space32),
            child: FutureBuilder<PackageInfo>(
              future: AboutScreen.packageInfoFuture,
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
    );
  }
}

class _AboutCalendarSection extends StatelessWidget {
  const _AboutCalendarSection();

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.space16, T.space12, T.space16, T.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.calendar_month_outlined, size: 22, color: T.accentInk),
              const SizedBox(width: T.space12),
              Expanded(
                child: Text(
                  'Calendar',
                  style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: T.space8),
          Text(
            'Month and week views for deadlines, quizzes, and personal notes.',
            style: AppText.sans(size: T.fs13, color: T.ink2, height: 1.45),
          ),
          const SizedBox(height: T.space12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TWO KINDS OF EVENTS',
                  style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.1),
                ),
                const SizedBox(height: T.space8),
                const _AboutBullet(
                  'Course events are shared per course code. Sign in to add or edit.',
                ),
                const _AboutBullet(
                  'Personal events are private. Signed-in users sync them to your account.',
                ),
                const SizedBox(height: T.space12),
                Text(
                  'TAP A DAY',
                  style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 1.1),
                ),
                const SizedBox(height: T.space8),
                const _AboutBullet(
                  'See institute calendar notes, your classes, and events for that date.',
                ),
                const _AboutBullet(
                  'Add course or personal events. Tap an existing event to edit.',
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
      padding: const EdgeInsets.only(bottom: T.space8),
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
      padding: const EdgeInsets.fromLTRB(T.space16, T.space4, T.space16, T.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: T.accentInk),
          const SizedBox(width: T.space12),
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
