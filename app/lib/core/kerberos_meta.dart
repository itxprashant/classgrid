class KerberosMeta {
  const KerberosMeta({this.branch, this.entryYear});

  final String? branch;
  final String? entryYear;
}

KerberosMeta kerberosMeta(String kerberos) {
  final match = RegExp(r'^([a-z0-9]{3})([0-9]{2})', caseSensitive: false).firstMatch(kerberos.trim());
  if (match == null) {
    return const KerberosMeta();
  }
  return KerberosMeta(
    branch: match.group(1)!.toUpperCase(),
    entryYear: '20${match.group(2)!}',
  );
}

String formatHostel(String? hostel) {
  final value = hostel?.trim() ?? '';
  return value.isEmpty ? '—' : value;
}
