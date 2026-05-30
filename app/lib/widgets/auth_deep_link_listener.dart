import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';

/// Subscribes to `classgrid://auth/callback` deep links and forwards the session
/// token to [AuthProvider].
class AuthDeepLinkListener extends StatefulWidget {
  const AuthDeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  State<AuthDeepLinkListener> createState() => _AuthDeepLinkListenerState();
}

class _AuthDeepLinkListenerState extends State<AuthDeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _appLinks.uriLinkStream.listen(_onLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _onLink(uri);
    });
  }

  void _onLink(Uri uri) {
    if (!mounted) return;
    context.read<AuthProvider>().handleAuthCallback(uri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
