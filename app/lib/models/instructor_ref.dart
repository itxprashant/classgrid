class InstructorRef {
  final String name;
  final String? email;

  const InstructorRef({required this.name, this.email});

  factory InstructorRef.fromJson(Map<String, dynamic> json) {
    final email = json['email']?.toString().trim().toLowerCase();
    return InstructorRef(
      name: (json['name'] ?? '').toString().trim(),
      email: email != null && email.contains('@') ? email : null,
    );
  }
}

List<InstructorRef> instructorsFromOffering(Map<String, dynamic> json) {
  final raw = json['instructors'];
  if (raw is List && raw.isNotEmpty) {
    return raw
        .whereType<Map>()
        .map((e) => InstructorRef.fromJson(Map<String, dynamic>.from(e)))
        .where((i) => i.name.isNotEmpty || i.email != null)
        .toList();
  }
  final name = (json['instructor'] ?? '').toString().trim();
  final email = json['instructorEmail']?.toString().trim().toLowerCase();
  if (name.isEmpty && (email == null || !email.contains('@'))) return [];
  if (name.contains(',') && email != null && email.contains('@')) {
    final parts = name.split(',');
    return parts.asMap().entries.map((entry) {
      return InstructorRef(
        name: entry.value.replaceAll(RegExp(r'\s+'), ' ').trim(),
        email: entry.key == 0 ? email : null,
      );
    }).toList();
  }
  return [InstructorRef(name: name.isNotEmpty ? name : email!, email: email)];
}
