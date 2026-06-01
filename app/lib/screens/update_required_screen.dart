import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_version_info.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
/// Blocks the app until the user installs a newer APK.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.installedVersion,
    required this.installedBuild,
    required this.required,
    this.onRetry,
  });

  final String installedVersion;
  final int installedBuild;
  final AppVersionInfo required;
  final VoidCallback? onRetry;

  Future<void> _openDownload() async {
    final uri = Uri.tryParse(required.downloadUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Update required',
                style: AppText.serif(size: T.fs26, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                'This build is out of date. Install the latest ClassGrid APK to continue.',
                style: AppText.sans(size: T.fs14, color: T.ink2),
              ),
              const SizedBox(height: 24),
              _VersionRow(
                label: 'Installed',
                value: '$installedVersion ($installedBuild)',
              ),
              const SizedBox(height: 8),
              _VersionRow(
                label: 'Required',
                value: '${required.version} (${required.build})',
                highlight: true,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _openDownload,
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  foregroundColor: T.paper,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(T.r),
                  ),
                ),
                child: Text(
                  'Download update',
                  style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: BorderSide(color: T.lineStrong),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(T.r),
                    ),
                  ),
                  child: Text(
                    'Check again',
                    style: AppText.sans(size: T.fs14, color: T.ink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: AppText.mono(size: T.fs12, color: T.ink3),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppText.mono(
              size: T.fs14,
              color: highlight ? T.accentInk : T.ink,
              weight: highlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
