import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

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
    this.onOpenEmptyHalls,
    this.onOpenAbout,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onOpenEmptyHalls;
  final VoidCallback? onOpenAbout;

  static const _tabs = [
    _NavItem(0, 'Plan', Icons.grid_view_outlined, Icons.grid_view),
    _NavItem(1, 'Courses', Icons.menu_book_outlined, Icons.menu_book),
    _NavItem(2, 'Rooms', Icons.domain_outlined, Icons.domain),
    _NavItem(3, 'Calendar', Icons.calendar_month_outlined, Icons.calendar_month),
  ];

  void _closeAndSelect(BuildContext context, int index) {
    Navigator.pop(context);
    onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
                  Text('ClassGrid', style: AppText.serif(size: T.fs26, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'IIT Delhi timetable',
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
                      icon: selectedIndex == item.tabIndex ? item.selectedIcon : item.icon,
                      selected: selectedIndex == item.tabIndex,
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
                    label: 'About',
                    icon: Icons.info_outline,
                    selected: false,
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
                          ],
                        )
                      : Text(
                          'Sign in from the app bar to sync your plan.',
                          style: AppText.sans(size: T.fs12, color: T.ink3),
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
