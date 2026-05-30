import '../models/academic_day.dart';
import '../models/course.dart';
import '../models/occupied_room.dart';
import 'room_schedule.dart';
import 'semester_schedule.dart';
import 'timing.dart';

/// Result of empty-hall computation for one date/time.
class EmptyHallsResult {
  final List<EmptyHallEntry> entries;
  final int freeCount;
  final int markedCount;
  final int timetableOccupiedCount;
  final int totalTracked;
  final AcademicDay academic;

  const EmptyHallsResult({
    required this.entries,
    required this.freeCount,
    required this.markedCount,
    required this.timetableOccupiedCount,
    required this.totalTracked,
    required this.academic,
  });
}

class EmptyHallEntry {
  final String room;
  final bool marked;
  final OccupiedRoom? marking;

  const EmptyHallEntry({
    required this.room,
    required this.marked,
    this.marking,
  });
}

/// Free / marked halls at [at] using lecture, tutorial, and lab slots; all catalog rooms.
EmptyHallsResult computeEmptyHalls({
  required List<Course> courses,
  List<dynamic> extraOccupied = const [],
  List<OccupiedRoom> manualMarkings = const [],
  required DateTime at,
}) {
  final academic = getAcademicDay(at);
  final effectiveDayCode = academic.hasClasses ? academic.effectiveDayCode : null;
  final atMinutes = toMinutes(
    '${at.hour.toString().padLeft(2, '0')}${at.minute.toString().padLeft(2, '0')}',
  );
  final calendarWeekday = at.weekday % 7;

  final allHalls = <String>{};
  for (final c in courses) {
    for (final h in splitRoomNames(c.lectureHall)) {
      allHalls.add(h);
    }
  }
  for (final m in manualMarkings) {
    final room = normalizeRoomName(m.room);
    if (room.isNotEmpty) allHalls.add(room);
  }

  final timetableOccupied = <String>{};
  if (effectiveDayCode != null) {
    for (final c in courses) {
      final halls = splitRoomNames(c.lectureHall);
      if (halls.isEmpty) continue;

      void check(String? timingStr) {
        if (timingStr == null) return;
        for (final slot in parseTimingStr(timingStr)) {
          final dayCode = kDayOrder[slot.day];
          if (dayCode == null || dayCode != effectiveDayCode) continue;
          final start = toMinutes(slot.start);
          final end = toMinutes(slot.end);
          if (atMinutes >= start && atMinutes < end) {
            for (final h in halls) {
              timetableOccupied.add(h);
            }
          }
        }
      }

      check(c.slot.lectureTiming);
      check(c.slot.tutorialTiming);
      check(c.slot.labTiming);
    }
  }

  final extraSet = <String>{};
  for (final item in extraOccupied) {
    if (item is! Map) continue;
    if (item['day'] != calendarWeekday) continue;
    final start = int.tryParse('${item['startTime']}') ?? 0;
    final end = int.tryParse('${item['endTime']}') ?? 0;
    final startM = toMinutes(start.toString().padLeft(4, '0'));
    final endM = toMinutes(end.toString().padLeft(4, '0'));
    if (atMinutes >= startM && atMinutes < endM) {
      final room = normalizeRoomName(item['lectureHall']?.toString());
      if (room.isNotEmpty) extraSet.add(room);
    }
  }

  final manualByRoom = {for (final m in manualMarkings) normalizeRoomName(m.room): m};

  final entries = <EmptyHallEntry>[];
  var free = 0, marked = 0;
  final sorted = allHalls.toList()..sort();
  for (final room in sorted) {
    if (timetableOccupied.contains(room) || extraSet.contains(room)) continue;
    final marking = manualByRoom[normalizeRoomName(room)];
    if (marking != null) {
      entries.add(EmptyHallEntry(room: room, marked: true, marking: marking));
      marked++;
    } else {
      entries.add(EmptyHallEntry(room: room, marked: false));
      free++;
    }
  }

  return EmptyHallsResult(
    entries: entries,
    freeCount: free,
    markedCount: marked,
    timetableOccupiedCount: timetableOccupied.length + extraSet.length,
    totalTracked: allHalls.length,
    academic: academic,
  );
}
