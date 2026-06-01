/// Compare app version name (e.g. 1.0.0) and build number to server requirements.
bool appVersionIsBehind({
  required String installedVersion,
  required int installedBuild,
  required String requiredVersion,
  required int requiredBuild,
}) {
  final cmp = compareVersionNames(installedVersion, requiredVersion);
  if (cmp < 0) return true;
  if (cmp > 0) return false;
  return installedBuild < requiredBuild;
}

/// Negative if [a] < [b], zero if equal, positive if [a] > [b].
int compareVersionNames(String a, String b) {
  final pa = _parseVersionParts(a);
  final pb = _parseVersionParts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

List<int> _parseVersionParts(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return const [0];
  return s.split('.').map((p) {
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits.isEmpty ? '0' : digits) ?? 0;
  }).toList();
}
