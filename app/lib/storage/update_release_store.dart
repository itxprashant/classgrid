import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which release prompts the user has already seen or dismissed.
class UpdateReleaseStore {
  UpdateReleaseStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kSeenReleaseBuild = 'cg_seen_release_build';
  static const _kDismissedOptionalBuild = 'cg_dismissed_optional_build';

  int get seenReleaseBuild => _prefs.getInt(_kSeenReleaseBuild) ?? 0;

  int get dismissedOptionalBuild => _prefs.getInt(_kDismissedOptionalBuild) ?? 0;

  Future<void> markReleaseSeen(int build) async {
    if (build <= seenReleaseBuild) return;
    await _prefs.setInt(_kSeenReleaseBuild, build);
  }

  Future<void> dismissOptionalUpdate(int latestBuild) async {
    if (latestBuild <= dismissedOptionalBuild) return;
    await _prefs.setInt(_kDismissedOptionalBuild, latestBuild);
  }

  bool shouldShowOptionalPrompt(int latestBuild) {
    return latestBuild > dismissedOptionalBuild;
  }
}
