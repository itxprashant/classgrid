class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.build,
    required this.downloadUrl,
  });

  final String version;
  final int build;
  final String downloadUrl;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    final buildRaw = json['build'];
    final build = buildRaw is int
        ? buildRaw
        : int.tryParse(buildRaw?.toString() ?? '') ?? 0;
    return AppVersionInfo(
      version: (json['version'] ?? '').toString().trim(),
      build: build,
      downloadUrl: (json['downloadUrl'] ?? '').toString().trim(),
    );
  }
}

class AppVersionResponse {
  const AppVersionResponse({this.android});

  final AppVersionInfo? android;

  factory AppVersionResponse.fromJson(Map<String, dynamic> json) {
    final android = json['android'];
    return AppVersionResponse(
      android: android is Map
          ? AppVersionInfo.fromJson(Map<String, dynamic>.from(android))
          : null,
    );
  }
}
