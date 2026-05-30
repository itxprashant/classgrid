/// The signed-in user, from `GET /api/me`.
class AppUser {
  final String? kerberos;
  final String? name;
  final String? picture;
  final String? email;

  const AppUser({this.kerberos, this.name, this.picture, this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        kerberos: json['kerberos']?.toString(),
        name: json['name']?.toString(),
        picture: json['picture']?.toString(),
        email: json['email']?.toString(),
      );

  String get displayName => (name?.isNotEmpty ?? false)
      ? name!
      : (kerberos ?? 'IITD user');
}
