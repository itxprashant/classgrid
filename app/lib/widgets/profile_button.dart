import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/kerberos_meta.dart';
import '../state/auth_provider.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/app_navigation.dart';
import '../widgets/desktop_login_dialog.dart';
import '../screens/settings_screen.dart';

/// App-bar action: opens ClassGrid in the browser for IITD login, or shows the
/// account menu when signed in.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  Future<void> _startLogin(BuildContext context) async {
    if (AppConfig.usesDesktopLogin) {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const DesktopLoginDialog(),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final opened = await auth.startBrowserLogin();
    if (!context.mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in on ClassGrid in your browser, then return here.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return Semantics(
        label: 'Loading account',
        child: const Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (!auth.isLoggedIn) {
      if (auth.awaitingBrowserLogin) {
        return Semantics(
          label: 'Waiting for browser login',
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Waiting for browser…',
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
              ],
            ),
          ),
        );
      }
      return Semantics(
        button: true,
        label: 'IITD login',
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: () => _startLogin(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('IITD login'),
          ),
        ),
      );
    }
    final user = auth.user!;
    return Semantics(
      button: true,
      label: 'Account menu for ${user.displayName}',
      child: PopupMenuButton<String>(
        tooltip: 'Account',
        offset: const Offset(0, 48),
        onSelected: (value) {
          if (value == 'settings') {
            pushAppRoute<void>(context, const SettingsScreen());
          } else if (value == 'logout') {
            auth.logout();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: AppText.sans(weight: FontWeight.w600)),
                if (user.kerberos != null)
                  Text(user.kerberos!, style: AppText.mono(size: T.fs12, color: T.ink3)),
                if (user.hostel != null && user.hostel!.trim().isNotEmpty)
                  Text(formatHostel(user.hostel), style: AppText.sans(size: T.fs12, color: T.ink3)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'settings',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.settings_outlined, size: 18),
              title: Text('Settings'),
            ),
          ),
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, size: 18),
              title: Text('Log out'),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: T.accentTint,
            foregroundImage:
                (user.picture?.isNotEmpty ?? false) ? NetworkImage(user.picture!) : null,
            child: Text(
              (user.displayName.isNotEmpty ? user.displayName[0] : '?').toUpperCase(),
              style: AppText.sans(weight: FontWeight.w600, color: T.accentInk),
            ),
          ),
        ),
      ),
    );
  }
}
