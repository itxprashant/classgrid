import 'actor.dart';

/// A manual lecture-hall occupancy marking for a specific calendar date.
class OccupiedRoom {
  final String id;
  final String room; // "LH 121"
  final String date; // YYYY-MM-DD
  final String start; // HHMM
  final String end; // HHMM
  final String? note;
  final Actor? markedBy;

  const OccupiedRoom({
    required this.id,
    required this.room,
    required this.date,
    required this.start,
    required this.end,
    this.note,
    this.markedBy,
  });

  factory OccupiedRoom.fromJson(Map<String, dynamic> json) => OccupiedRoom(
        id: (json['id'] ?? '').toString(),
        room: (json['room'] ?? '').toString(),
        date: (json['date'] ?? '').toString(),
        start: (json['start'] ?? '').toString(),
        end: (json['end'] ?? '').toString(),
        note: json['note']?.toString(),
        markedBy: json['markedBy'] is Map
            ? Actor.fromJson(Map<String, dynamic>.from(json['markedBy']))
            : null,
      );
}
