import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/apk_update.dart';
import '../models/app_version_info.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'release_notes_body.dart';
import 'sheet_scaffold.dart';

/// Shared download + install logic for update sheets.
class UpdateInstallActions extends StatefulWidget {
  const UpdateInstallActions({
    super.key,
    required this.target,
    this.onInstalled,
  });

  final AppVersionInfo target;
  final VoidCallback? onInstalled;

  @override
  State<UpdateInstallActions> createState() => _UpdateInstallActionsState();
}

class _UpdateInstallActionsState extends State<UpdateInstallActions> {
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
    final url = widget.target.downloadUrl.trim();
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
        cacheBustBuild: widget.target.build,
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
      widget.onInstalled?.call();
    } on ApkUpdateException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_status != null) ...[
          Text(
            _status!,
            style: AppText.sans(size: T.fs13, color: T.accentInk, weight: FontWeight.w600),
          ),
          if (_progress != null) ...[
            const SizedBox(height: T.space8),
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
          const SizedBox(height: T.space12),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            style: AppText.sans(size: T.fs13, color: T.danger, weight: FontWeight.w500),
          ),
          const SizedBox(height: T.space12),
        ],
        FilledButton(
          onPressed: _busy ? null : _downloadAndInstall,
          child: Text(_busy ? 'Please wait…' : 'Download & install'),
        ),
      ],
    );
  }
}

Future<void> showWhatsNewSheet({
  required BuildContext context,
  required String version,
  required int build,
  required String releaseNotes,
}) {
  return SheetScaffold.show(
    context: context,
    child: SheetScaffold(
      title: "What's new",
      subtitle: Text(
        'v$version ($build)',
        style: AppText.mono(size: T.fs12, color: T.ink3),
      ),
      body: releaseNotes.isEmpty
          ? Text(
              'Thanks for updating ClassGrid.',
              style: AppText.sans(size: T.fs14, color: T.ink2),
            )
          : ReleaseNotesBody(notes: releaseNotes),
      primaryLabel: 'Got it',
      onPrimary: () => Navigator.of(context).pop(),
    ),
  );
}

Future<bool?> showOptionalUpdateSheet({
  required BuildContext context,
  required AppVersionInfo latest,
  required String installedVersion,
  required int installedBuild,
  required VoidCallback onDismiss,
}) {
  return SheetScaffold.show<bool>(
    context: context,
    child: SheetScaffold(
      title: 'Update available',
      subtitle: Text(
        'Installed v$installedVersion ($installedBuild) · Latest v${latest.version} (${latest.build})',
        style: AppText.sans(size: T.fs13, color: T.ink2),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A newer ClassGrid build is ready to install.',
            style: AppText.sans(size: T.fs14, color: T.ink2),
          ),
          if (latest.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: T.space16),
            ReleaseNotesBody(notes: latest.releaseNotes),
          ],
          const SizedBox(height: T.space16),
          UpdateInstallActions(target: latest),
        ],
      ),
      primaryAction: TextButton(
        onPressed: () {
          onDismiss();
          Navigator.of(context).pop(false);
        },
        child: const Text('Later'),
      ),
    ),
  );
}
