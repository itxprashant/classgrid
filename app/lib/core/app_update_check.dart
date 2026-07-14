import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/app_version_api.dart';
import '../storage/update_release_store.dart';
import '../widgets/update_sheets.dart';
import 'app_version.dart';
import '../models/app_version_info.dart';

enum UpdateCheckResult {
  upToDate,
  optionalAvailable,
  forceRequired,
  failed,
}

/// Fetches release status and shows update UI when needed.
Future<UpdateCheckResult> checkForAppUpdates({
  required BuildContext context,
  required ApiClient apiClient,
  required UpdateReleaseStore releaseStore,
  required String installedVersion,
  required int installedBuild,
}) async {
  try {
    final status = await AppVersionApi(apiClient).fetchAndroidReleaseStatus();
    if (!context.mounted || status == null) return UpdateCheckResult.failed;

    if (isForceUpdateRequired(
      status: status,
      installedVersion: installedVersion,
      installedBuild: installedBuild,
    )) {
      if (!context.mounted) return UpdateCheckResult.forceRequired;
      await showOptionalUpdateSheet(
        context: context,
        latest: status.latest,
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        onDismiss: () {},
      );
      return UpdateCheckResult.forceRequired;
    }

    if (isOptionalUpdateAvailable(
      status: status,
      installedVersion: installedVersion,
      installedBuild: installedBuild,
    )) {
      if (!context.mounted) return UpdateCheckResult.optionalAvailable;
      await showOptionalUpdateSheet(
        context: context,
        latest: status.latest,
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        onDismiss: () => releaseStore.dismissOptionalUpdate(status.latest.build),
      );
      return UpdateCheckResult.optionalAvailable;
    }

    return UpdateCheckResult.upToDate;
  } catch (_) {
    return UpdateCheckResult.failed;
  }
}

Future<String> releaseNotesForBuild({
  required ApiClient apiClient,
  required int build,
  required AppReleaseStatus status,
}) async {
  if (build == status.latest.build && status.latest.releaseNotes.isNotEmpty) {
    return status.latest.releaseNotes;
  }
  try {
    final page = await AppVersionApi(apiClient).fetchChangelog(limit: 50);
    for (final entry in page.releases) {
      if (entry.build == build) return entry.releaseNotes;
    }
  } catch (_) {}
  return status.latest.releaseNotes;
}
