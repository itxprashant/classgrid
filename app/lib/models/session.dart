/// A single class session. Mirrors the web's internal session shape:
/// `{ day: 'Monday'..'Friday', start: 'HHMM', end: 'HHMM', location?: string }`.
class Session {
  final String day; // 'Monday'..'Friday'
  final String start; // 'HHMM'
  final String end; // 'HHMM'
  final String? location;

  const Session({
    required this.day,
    required this.start,
    required this.end,
    this.location,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        day: (json['day'] ?? '').toString(),
        start: (json['start'] ?? '').toString(),
        end: (json['end'] ?? '').toString(),
        location: json['location']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'start': start,
        'end': end,
        'location': location ?? '',
      };

  bool get isValid => day.isNotEmpty && start.isNotEmpty && end.isNotEmpty;
}
