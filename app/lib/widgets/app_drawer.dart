import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../core/kerberos_meta.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Drawer route ids for Tools / App screens pushed on top of [HomeShell].
abstract final class AppDrawerRoute {
  static const attendance = 'attendance';
  static const cgpa = 'cgpa';
  static const profExplorer = 'prof-explorer';
  static const studentExplorer = 'student-explorer';
  static const settings = 'settings';
  static const feedback = 'feedback';
  static const about = 'about';
}

class _NavItem {
  final int tabIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem(this.tabIndex, this.label, this.icon, this.selectedIcon);
}

/// Left navigation drawer — main tabs plus shortcuts (e.g. Empty halls).
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.selectedDrawerRoute,
    this.onOpenEmptyHalls,
    this.onOpenAttendance,
    this.onOpenCgpaCalculator,
    this.onOpenProfExplorer,
    this.onOpenStudentExplorer,
    this.onOpenSettings,
    this.onOpenFeedback,
    this.onOpenAbout,
    this.onLoginTap,
  });

  final int selectedIndex;
  final String? selectedDrawerRoute;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onOpenEmptyHalls;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenCgpaCalculator;
  final VoidCallback? onOpenProfExplorer;
  final VoidCallback? onOpenStudentExplorer;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenFeedback;
  final VoidCallback? onOpenAbout;
  final VoidCallback? onLoginTap;

  static const _tabs = [
    _NavItem(0, 'Calendar', Icons.calendar_month_outlined, Icons.calendar_month),
    _NavItem(1, 'Plan', Icons.grid_view_outlined, Icons.grid_view),
    _NavItem(2, 'Courses', Icons.menu_book_outlined, Icons.menu_book),
    _NavItem(3, 'Rooms', Icons.domain_outlined, Icons.domain),
  ];

  void _closeAndSelect(BuildContext context, int index) {
    Navigator.pop(context);
    onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final auth = context.watch<AuthProvider>();
    final drawerRoute = selectedDrawerRoute;

    return Drawer(
      backgroundColor: T.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ClassGrid', style: AppText.serif(size: T.fs26, weight: FontWeight.w600, color: T.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'IIT Delhi · semester planner',
                    style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 0.04),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: T.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'Navigate',
                      style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 0.12),
                    ),
                  ),
                  for (final item in _tabs)
                    _DrawerTile(
                      label: item.label,
                      icon: selectedIndex == item.tabIndex && drawerRoute == null
                          ? item.selectedIcon
                          : item.icon,
                      selected: selectedIndex == item.tabIndex && drawerRoute == null,
                      onTap: () => _closeAndSelect(context, item.tabIndex),
                    ),
                  const SizedBox(height: 8),
                  Divider(height: 1, indent: 20, endIndent: 20, color: T.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      'Tools',
                      style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 0.12),
                    ),
                  ),
                  _DrawerTile(
                    label: 'Empty halls',
                    icon: Icons.meeting_room_outlined,
                    selected: false,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenEmptyHalls?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'Attendance',
                    icon: Icons.fact_check_outlined,
                    selected: drawerRoute == AppDrawerRoute.attendance,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenAttendance?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'CGPA calculator',
                    icon: Icons.school_outlined,
                    selected: drawerRoute == AppDrawerRoute.cgpa,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenCgpaCalculator?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'Prof explorer',
                    icon: Icons.person_search_outlined,
                    selected: drawerRoute == AppDrawerRoute.profExplorer,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenProfExplorer?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'Student explorer',
                    icon: Icons.groups_outlined,
                    selected: drawerRoute == AppDrawerRoute.studentExplorer,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenStudentExplorer?.call();
                    },
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, indent: 20, endIndent: 20, color: T.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      'App',
                      style: AppText.mono(size: T.fs12, color: T.ink3, letterSpacing: 0.12),
                    ),
                  ),
                  _DrawerTile(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    selected: drawerRoute == AppDrawerRoute.settings,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenSettings?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'Suggest a feature',
                    icon: Icons.lightbulb_outline,
                    selected: drawerRoute == AppDrawerRoute.feedback,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenFeedback?.call();
                    },
                  ),
                  _DrawerTile(
                    label: 'About',
                    icon: Icons.info_outline,
                    selected: drawerRoute == AppDrawerRoute.about,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenAbout?.call();
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: T.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: auth.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : auth.isLoggedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user!.displayName,
                              style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (auth.user!.kerberos != null)
                              Text(
                                auth.user!.kerberos!,
                                style: AppText.mono(size: T.fs12, color: T.ink3),
                              ),
                            if (auth.user!.hostel != null && auth.user!.hostel!.trim().isNotEmpty)
                              Text(
                                formatHostel(auth.user!.hostel),
                                style: AppText.sans(size: T.fs12, color: T.ink3),
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in to sync your plan and attendance.',
                              style: AppText.sans(size: T.fs12, color: T.ink3),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                onLoginTap?.call();
                              },
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text('IITD login'),
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, size: 22, color: selected ? T.accentInk : T.ink2),
        title: Text(
          label,
          style: AppText.sans(
            size: T.fs16,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? T.accentInk : T.ink,
          ),
        ),
        selected: selected,
        selectedTileColor: T.accentTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.r)),
        onTap: onTap,
      ),
    );
  }
}
