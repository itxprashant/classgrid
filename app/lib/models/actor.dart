/// Who created/updated/marked a record. `at` is an ISO8601 timestamp.
class Actor {
  final String? kerberos;
  final String? name;
  final String at;

  const Actor({this.kerberos, this.name, required this.at});

  factory Actor.fromJson(Map<String, dynamic> json) => Actor(
        kerberos: json['kerberos']?.toString(),
        name: json['name']?.toString(),
        at: (json['at'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        if (kerberos != null) 'kerberos': kerberos,
        'name': name,
        'at': at,
      };
}
