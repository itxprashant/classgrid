import 'package:flutter/material.dart';

import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Launch branding shown while startup work (e.g. version check) runs.
class IntroScreen extends StatefulWidget {
  const IntroScreen({
    super.key,
    this.installedVersion,
    this.installedBuild,
  });

  final String? installedVersion;
  final int? installedBuild;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();
    final disableAnimations = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration: disableAnimations ? Duration.zero : T.tSlow,
    );
    _titleOpacity = CurvedAnimation(parent: _controller, curve: T.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final versionLabel = (widget.installedVersion != null && widget.installedVersion!.isNotEmpty)
        ? 'v${widget.installedVersion}${widget.installedBuild != null ? '+${widget.installedBuild}' : ''}'
        : null;

    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: T.space32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _titleOpacity,
                  child: Text(
                    'ClassGrid',
                    style: AppText.serif(
                      size: T.fs44,
                      weight: FontWeight.w500,
                      height: 1.05,
                      color: T.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Made by DevClub',
                  style: AppText.mono(
                    size: T.fs13,
                    color: T.ink3,
                    letterSpacing: 0.14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: T.accent,
                  ),
                ),
                const SizedBox(height: T.space16),
                Text(
                  'Checking for updates…',
                  style: AppText.sans(size: T.fs13, color: T.ink3),
                  textAlign: TextAlign.center,
                ),
                if (versionLabel != null) ...[
                  const SizedBox(height: T.space8),
                  Text(
                    versionLabel,
                    style: AppText.mono(size: T.fs12, color: T.ink4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
