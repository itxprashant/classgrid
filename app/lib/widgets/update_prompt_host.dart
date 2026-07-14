import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../core/app_update_check.dart';
import '../core/app_version.dart';
import '../models/app_version_info.dart';
import '../storage/update_release_store.dart';
import 'update_sheets.dart';

/// Runs startup What's New / optional update prompts.
class UpdatePromptHost extends StatefulWidget {
  const UpdatePromptHost({
    super.key,
    required this.apiClient,
    required this.releaseStore,
    required this.installedVersion,
    required this.installedBuild,
    required this.initialStatus,
    required this.child,
  });

  final ApiClient apiClient;
  final UpdateReleaseStore releaseStore;
  final String installedVersion;
  final int installedBuild;
  final AppReleaseStatus? initialStatus;
  final Widget child;

  @override
  State<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends State<UpdatePromptHost> {
  bool _startupHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupPrompts());
  }

  Future<void> _runStartupPrompts() async {
    if (_startupHandled || !mounted) return;
    _startupHandled = true;

    final status = widget.initialStatus;
    if (status == null) return;

    if (shouldShowWhatsNew(
      seenReleaseBuild: widget.releaseStore.seenReleaseBuild,
      installedBuild: widget.installedBuild,
    )) {
      final notes = await releaseNotesForBuild(
        apiClient: widget.apiClient,
        build: widget.installedBuild,
        status: status,
      );
      if (!mounted) return;
      await showWhatsNewSheet(
        context: context,
        version: widget.installedVersion,
        build: widget.installedBuild,
        releaseNotes: notes,
      );
      await widget.releaseStore.markReleaseSeen(widget.installedBuild);
      return;
    }

    if (isOptionalUpdateAvailable(
          status: status,
          installedVersion: widget.installedVersion,
          installedBuild: widget.installedBuild,
        ) &&
        widget.releaseStore.shouldShowOptionalPrompt(status.latest.build)) {
      if (!mounted) return;
      await showOptionalUpdateSheet(
        context: context,
        latest: status.latest,
        installedVersion: widget.installedVersion,
        installedBuild: widget.installedBuild,
        onDismiss: () => widget.releaseStore.dismissOptionalUpdate(status.latest.build),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
