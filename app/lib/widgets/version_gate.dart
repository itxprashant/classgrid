import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api_client.dart';
import '../api/app_version_api.dart';
import '../config.dart';
import '../core/app_version.dart';
import '../models/app_version_info.dart';
import '../screens/intro_screen.dart';
import '../screens/update_required_screen.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum _VersionGatePhase { intro, ready, updateRequired, checkFailed }

/// Intro screen + GET /api/app/version before showing [child].
class VersionGate extends StatefulWidget {
  const VersionGate({
    super.key,
    required this.apiClient,
    required this.child,
  });

  final ApiClient apiClient;
  final Widget child;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  static const _minIntro = Duration(milliseconds: 1400);

  _VersionGatePhase _phase = _VersionGatePhase.intro;
  AppVersionInfo? _required;
  String _installedVersion = '';
  int _installedBuild = 0;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _runCheck();
  }

  Future<void> _waitMinIntro(DateTime started) async {
    final elapsed = DateTime.now().difference(started);
    final remaining = _minIntro - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> _runCheck() async {
    final started = DateTime.now();

    setState(() {
      _phase = _VersionGatePhase.intro;
      _checkError = null;
    });

    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      _installedVersion = info.version;
      _installedBuild = int.tryParse(info.buildNumber) ?? 0;
      setState(() {});

      if (AppConfig.skipVersionCheck) {
        await _waitMinIntro(started);
        if (!mounted) return;
        setState(() => _phase = _VersionGatePhase.ready);
        return;
      }

      final required = await AppVersionApi(widget.apiClient).fetchAndroidRequirement();
      await _waitMinIntro(started);
      if (!mounted) return;

      if (required == null || required.version.isEmpty) {
        setState(() {
          _checkError = 'Invalid version response from server.';
          _phase = _VersionGatePhase.checkFailed;
        });
        return;
      }

      _required = required;
      final behind = appVersionIsBehind(
        installedVersion: _installedVersion,
        installedBuild: _installedBuild,
        requiredVersion: required.version,
        requiredBuild: required.build,
      );

      setState(() {
        _phase = behind ? _VersionGatePhase.updateRequired : _VersionGatePhase.ready;
      });
    } catch (e) {
      await _waitMinIntro(started);
      if (!mounted) return;
      setState(() {
        _checkError = e.toString();
        _phase = _VersionGatePhase.checkFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _VersionGatePhase.intro:
        return IntroScreen(
          installedVersion: _installedVersion.isEmpty ? null : _installedVersion,
          installedBuild: _installedBuild == 0 ? null : _installedBuild,
        );
      case _VersionGatePhase.ready:
        return widget.child;
      case _VersionGatePhase.updateRequired:
        return UpdateRequiredScreen(
          installedVersion: _installedVersion,
          installedBuild: _installedBuild,
          required: _required!,
          onRetry: _runCheck,
        );
      case _VersionGatePhase.checkFailed:
        return Scaffold(
          backgroundColor: T.paper,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Could not verify app version',
                    style: AppText.serif(size: T.fs26, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ClassGrid needs to check for updates before you can sign in. '
                    'Check your connection and try again.',
                    style: AppText.sans(size: T.fs14, color: T.ink2),
                  ),
                  if (_checkError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _checkError!,
                      style: AppText.mono(size: T.fs12, color: T.ink3),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: _runCheck,
                    style: FilledButton.styleFrom(
                      backgroundColor: T.accent,
                      foregroundColor: T.paper,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
