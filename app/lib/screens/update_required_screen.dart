import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/apk_update.dart';
import '../models/app_version_info.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Blocks the app until the user installs a newer APK.
class UpdateRequiredScreen extends StatefulWidget {
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

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  final _apkUpdate = ApkUpdateService();
  CancelToken? _cancelToken;

  bool _busy = false;
  double? _progress;
  String? _status;
  String? _error;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _downloadAndInstall() async {
    final url = widget.required.downloadUrl.trim();
    if (url.isEmpty) {
      setState(() => _error = 'No download URL from server.');
      return;
    }

    if (!Platform.isAndroid) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    setState(() {
      _busy = true;
      _progress = null;
      _status = 'Downloading update…';
      _error = null;
    });

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    try {
      final path = await _apkUpdate.downloadApk(
        url: url,
        cacheBustBuild: widget.required.build,
        cancelToken: _cancelToken,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _progress = received / total;
            _status = 'Downloading… ${((received / total) * 100).round()}%';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'Opening installer…';
      });

      await _apkUpdate.installApk(path);
    } on ApkUpdateException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Update failed. Check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
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
                style: AppText.serif(size: T.fs26, weight: FontWeight.w500, color: T.ink),
              ),
              const SizedBox(height: 12),
              Text(
                Platform.isAndroid
                    ? 'This build is out of date. Download and install the latest ClassGrid APK to continue.'
                    : 'This build is out of date. Install the latest ClassGrid APK to continue.',
                style: AppText.sans(size: T.fs14, color: T.ink2),
              ),
              const SizedBox(height: 24),
              _VersionRow(
                label: 'Installed',
                value: '${widget.installedVersion} (${widget.installedBuild})',
              ),
              const SizedBox(height: 8),
              _VersionRow(
                label: 'Required',
                value: '${widget.required.version} (${widget.required.build})',
                highlight: true,
              ),
              if (_status != null) ...[
                const SizedBox(height: 20),
                Text(
                  _status!,
                  style: AppText.sans(size: T.fs13, color: T.accentInk, weight: FontWeight.w600),
                ),
                if (_progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(T.rSm),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: T.line,
                      color: T.accent,
                    ),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: AppText.sans(size: T.fs13, color: T.danger, weight: FontWeight.w500),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _downloadAndInstall,
                style: FilledButton.styleFrom(
                  backgroundColor: T.accent,
                  foregroundColor: T.paper,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(T.r),
                  ),
                ),
                child: Text(
                  _busy ? 'Please wait…' : 'Download & install',
                  style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                ),
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 10),
                Text(
                  'After download, tap Install on the system screen, then reopen ClassGrid. '
                  'You may need to allow this app to install updates.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: T.fs12, color: T.ink3),
                ),
              ],
              if (widget.onRetry != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : widget.onRetry,
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
    AppPaletteScope.watch(context);
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
