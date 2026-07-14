class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
    this.releaseNotes = '',
  });

  final String version;
  final int build;
  final String downloadUrl;
  final String releaseNotes;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final buildRaw = json['build'];
    final build = buildRaw is int
        ? buildRaw
        : int.tryParse(buildRaw?.toString() ?? '') ?? 0;
    return AppVersionInfo(
      version: (json['version'] ?? '').toString().trim(),
      build: build,
      downloadUrl: (json['downloadUrl'] ?? '').toString().trim(),
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
    );
  }
}

/// Server minimum (force) and latest (optional update) requirements.
class AppReleaseStatus {
  const AppReleaseStatus({
    required this.minimum,
    required this.latest,
  });

  final AppVersionInfo minimum;
  final AppVersionInfo latest;

  factory AppReleaseStatus.fromJson(Map<String, dynamic> json) {
    final minimumRaw = json['minimum'];
    final latestRaw = json['latest'];
    if (minimumRaw is Map && latestRaw is Map) {
      return AppReleaseStatus(
        minimum: AppVersionInfo.fromJson(Map<String, dynamic>.from(minimumRaw)),
        latest: AppVersionInfo.fromJson(Map<String, dynamic>.from(latestRaw)),
      );
    }

    // Legacy flat shape: treat as both minimum and latest.
    final flat = AppVersionInfo.fromJson(json);
    return AppReleaseStatus(minimum: flat, latest: flat);
  }
}

class AppReleaseEntry {
  const AppReleaseEntry({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.releaseNotes,
    this.publishedAt,
  });

  final String version;
  final int build;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime? publishedAt;

  factory AppReleaseEntry.fromJson(Map<String, dynamic> json) {
    final buildRaw = json['build'];
    final build = buildRaw is int
        ? buildRaw
        : int.tryParse(buildRaw?.toString() ?? '') ?? 0;
    final publishedRaw = json['publishedAt'];
    DateTime? publishedAt;
    if (publishedRaw is String && publishedRaw.isNotEmpty) {
      publishedAt = DateTime.tryParse(publishedRaw);
    }
    return AppReleaseEntry(
      version: (json['version'] ?? '').toString().trim(),
      build: build,
      downloadUrl: (json['downloadUrl'] ?? '').toString().trim(),
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
      publishedAt: publishedAt,
    );
  }
}

class AppChangelogPage {
  const AppChangelogPage({
    required this.releases,
    required this.total,
  });

  final List<AppReleaseEntry> releases;
  final int total;

  factory AppChangelogPage.fromJson(Map<String, dynamic> json) {
    final raw = json['releases'];
    final releases = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AppReleaseEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AppReleaseEntry>[];
    final totalRaw = json['total'];
    final total = totalRaw is int
        ? totalRaw
        : int.tryParse(totalRaw?.toString() ?? '') ?? releases.length;
    return AppChangelogPage(releases: releases, total: total);
  }
}

class AppVersionResponse {
  const AppVersionResponse({this.android});

  final AppReleaseStatus? android;

  factory AppVersionResponse.fromJson(Map<String, dynamic> json) {
    final android = json['android'];
    return AppVersionResponse(
      android: android is Map
          ? AppReleaseStatus.fromJson(Map<String, dynamic>.from(android))
          : null,
    );
  }
}
