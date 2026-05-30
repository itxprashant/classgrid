import 'actor.dart';

/// A calendar event — shared (course) or personal. Matches the API JSON and the
/// guest `localStorage` shape. Personal events have no [courseCode] and
/// [isPersonal] = true.
class CalendarEvent {
  final String? id;
  final String date; // YYYY-MM-DD
  final String? courseCode;
  final String title;
  final String type; // quiz|deadline|exam|extra-class|presentation|others
  final String schedule; // fullday|at|timed|eod
  final String? time; // HHMM (schedule == at)
  final String? start; // HHMM (schedule == timed)
  final String? end; // HHMM (schedule == timed)
  final String? note;
  final bool isPersonal;
  final Actor? createdBy;
  final Actor? updatedBy;

  const CalendarEvent({
    this.id,
    required this.date,
    this.courseCode,
    required this.title,
    required this.type,
    required this.schedule,
    this.time,
    this.start,
    this.end,
    this.note,
    this.isPersonal = false,
    this.createdBy,
    this.updatedBy,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id']?.toString(),
        date: (json['date'] ?? '').toString(),
        courseCode: json['courseCode']?.toString(),
        title: (json['title'] ?? '').toString(),
        type: (json['type'] ?? 'others').toString(),
        schedule: (json['schedule'] ?? 'fullday').toString(),
        time: json['time']?.toString(),
        start: json['start']?.toString(),
        end: json['end']?.toString(),
        note: json['note']?.toString(),
        isPersonal: json['isPersonal'] == true,
        createdBy: json['createdBy'] is Map
            ? Actor.fromJson(Map<String, dynamic>.from(json['createdBy']))
            : null,
        updatedBy: json['updatedBy'] is Map
            ? Actor.fromJson(Map<String, dynamic>.from(json['updatedBy']))
            : null,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'date': date,
        if (courseCode != null) 'courseCode': courseCode,
        'title': title,
        'type': type,
        'schedule': schedule,
        if (time != null) 'time': time,
        if (start != null) 'start': start,
        if (end != null) 'end': end,
        if (note != null) 'note': note,
        if (isPersonal) 'isPersonal': true,
        if (createdBy != null) 'createdBy': createdBy!.toJson(),
        if (updatedBy != null) 'updatedBy': updatedBy!.toJson(),
      };
}
