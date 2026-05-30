/// Parses pasted OAuth callback input into a `cg_session` JWT.
String? parseSessionTokenInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  Uri? uri = Uri.tryParse(trimmed);
  if (uri != null && uri.queryParameters['token']?.isNotEmpty == true) {
    return uri.queryParameters['token'];
  }

  if (trimmed.contains('token=')) {
    final q = trimmed.contains('?') ? trimmed.split('?').last : trimmed;
    for (final part in q.split('&')) {
      if (part.startsWith('token=')) {
        final t = Uri.decodeComponent(part.substring(6));
        if (t.isNotEmpty) return t;
      }
    }
  }

  // Raw JWT (header.payload.signature)
  if (RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
    return trimmed;
  }

  return null;
}
