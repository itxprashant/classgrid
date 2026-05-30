import '../models/course.dart';
import 'timing.dart';

const List<String> kDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const Map<String, int> kDayOrder = {
  'Monday': 1,
  'Tuesday': 2,
  'Wednesday': 3,
  'Thursday': 4,
  'Friday': 5,
};

/// Catalog row for the room browse list.
class RoomInfo {
  final String name;
  final String prefix;
  final int sessionCount;

  const RoomInfo({
    required this.name,
    required this.prefix,
    required this.sessionCount,
  });
}

/// A weekly session in a specific room (from catalog or extra overlay).
class RoomSession {
  final String? courseCode;
  final String courseName;
  final String instructor;
  final String type;
  final String day;
  final String start;
  final String end;
  final bool isExtra;

  const RoomSession({
    this.courseCode,
    required this.courseName,
    this.instructor = '',
    required this.type,
    required this.day,
    required this.start,
    required this.end,
    this.isExtra = false,
  });

  String get displayCode => courseCode ?? courseName;
}

class RoomCatalog {
  final List<RoomInfo> rooms;
  final Map<String, List<RoomSession>> sessionsByRoom;
  final bool catalogHasVenues;
  final bool catalogHasSessions;

  const RoomCatalog({
    required this.rooms,
    required this.sessionsByRoom,
    required this.catalogHasVenues,
    required this.catalogHasSessions,
  });
}

class BuildingCount {
  final String code;
  final int count;
  const BuildingCount(this.code, this.count);
}

String normalizeRoomName(String? name) {
  final s = (name ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (s.isEmpty) return '';
  final m = RegExp(r'^LH\s*(.+)$', caseSensitive: false).firstMatch(s);
  if (m != null) return 'LH ${m.group(1)!.trim()}';
  return s;
}

String roomPrefix(String name) {
  final m = RegExp(r'^(\w+)').firstMatch(name);
  return m != null ? m.group(1)! : 'Other';
}

List<String> splitRoomNames(String? lectureHall) {
  if (lectureHall == null || lectureHall.isEmpty) return const [];
  return lectureHall
      .split(',')
      .map((h) => normalizeRoomName(h.trim()))
      .where((h) => h.isNotEmpty)
      .toList();
}

String formatHHMM(String value) {
  final s = value.padLeft(4, '0');
  return '${s.substring(0, 2)}:${s.substring(2, 4)}';
}

int _compareRoomNames(String a, String b) {
  final pa = roomPrefix(a);
  final pb = roomPrefix(b);
  if (pa != pb) return pa.compareTo(pb);
  final na = double.tryParse(a.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  final nb = double.tryParse(b.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  final n = na.compareTo(nb);
  return n != 0 ? n : a.compareTo(b);
}

List<RoomSession> _sortSessions(List<RoomSession> sessions) {
  final copy = [...sessions];
  copy.sort((a, b) {
    final d = (kDayOrder[a.day] ?? 99) - (kDayOrder[b.day] ?? 99);
    if (d != 0) return d;
    return a.start.compareTo(b.start);
  });
  return copy;
}

/// Build room index + per-room weekly sessions. Mirrors [src/utils/roomSchedule.js].
RoomCatalog buildRoomCatalog(
  List<Course> courses, {
  List<dynamic> extraOccupied = const [],
}) {
  final sessionsByRoom = <String, List<RoomSession>>{};
  final roomNames = <String>{};

  void addSession(String room, RoomSession session) {
    if (room.isEmpty) return;
    roomNames.add(room);
    sessionsByRoom.putIfAbsent(room, () => []).add(session);
  }

  for (final course in courses) {
    final halls = splitRoomNames(course.lectureHall);
    if (halls.isEmpty) continue;

    roomNames.addAll(halls);

    void attach(String? timingStr, String type) {
      for (final slot in parseTimingStr(timingStr)) {
        for (final room in halls) {
          addSession(
            room,
            RoomSession(
              courseCode: course.courseCode,
              courseName: course.courseName,
              instructor: course.instructor ?? '',
              type: type,
              day: slot.day,
              start: slot.start,
              end: slot.end,
            ),
          );
        }
      }
    }

    attach(course.slot.lectureTiming, 'Lecture');
    attach(course.slot.tutorialTiming, 'Tutorial');
    attach(course.slot.labTiming, 'Lab');
  }

  for (final item in extraOccupied) {
    if (item is! Map) continue;
    final room = normalizeRoomName(item['lectureHall']?.toString());
    if (room.isEmpty) continue;
    final dayIndex = item['day'];
    if (dayIndex is! int || dayIndex < 0 || dayIndex >= kDayNames.length) continue;
    final day = kDayNames[dayIndex];
    if (!kDayOrder.containsKey(day)) continue;
    final start = (item['startTime']?.toString() ?? '').padLeft(4, '0');
    final end = (item['endTime']?.toString() ?? '').padLeft(4, '0');
    addSession(
      room,
      RoomSession(
        courseName: item['reason']?.toString() ?? 'Extra booking',
        type: 'Extra',
        day: day,
        start: start,
        end: end,
        isExtra: true,
      ),
    );
  }

  final sortedSessions = <String, List<RoomSession>>{};
  for (final e in sessionsByRoom.entries) {
    sortedSessions[e.key] = _sortSessions(e.value);
  }

  final roomList = roomNames.toList()..sort(_compareRoomNames);
  final roomInfos = roomList
      .map(
        (name) => RoomInfo(
          name: name,
          prefix: roomPrefix(name),
          sessionCount: sortedSessions[name]?.length ?? 0,
        ),
      )
      .toList();

  final catalogHasVenues = courses.any((c) => (c.lectureHall ?? '').isNotEmpty);
  final catalogHasSessions = roomInfos.any((r) => r.sessionCount > 0);

  return RoomCatalog(
    rooms: roomInfos,
    sessionsByRoom: sortedSessions,
    catalogHasVenues: catalogHasVenues,
    catalogHasSessions: catalogHasSessions,
  );
}

List<RoomSession> sessionsForRoom(Map<String, List<RoomSession>> byRoom, String roomName) {
  return byRoom[normalizeRoomName(roomName)] ?? const [];
}

List<BuildingCount> roomBuildingCounts(List<RoomInfo> rooms) {
  final counts = <String, int>{};
  for (final r in rooms) {
    counts[r.prefix] = (counts[r.prefix] ?? 0) + 1;
  }
  return counts.entries
      .map((e) => BuildingCount(e.key, e.value))
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));
}

List<RoomInfo> filterRooms(
  List<RoomInfo> rooms, {
  String search = '',
  String? prefix,
}) {
  final term = search.trim().toLowerCase();
  return rooms.where((room) {
    if (prefix != null && prefix.isNotEmpty && room.prefix != prefix) return false;
    if (term.isEmpty) return true;
    return room.name.toLowerCase().contains(term);
  }).toList();
}

Map<String, List<RoomSession>> groupSessionsByDay(List<RoomSession> sessions) {
  final groups = {for (final d in kDayOrder.keys) d: <RoomSession>[]};
  for (final s in sessions) {
    groups[s.day]?.add(s);
  }
  return groups;
}

/// Indices of sessions that overlap in the same room (different courses).
Set<int> roomSessionOverlapIndices(List<RoomSession> sessions) {
  final conflict = <int>{};
  for (var i = 0; i < sessions.length; i++) {
    for (var j = i + 1; j < sessions.length; j++) {
      final a = sessions[i];
      final b = sessions[j];
      if (a.day != b.day) continue;
      if (a.courseCode != null &&
          b.courseCode != null &&
          a.courseCode == b.courseCode) {
        continue;
      }
      if (a.start.compareTo(b.end) < 0 && b.start.compareTo(a.end) < 0) {
        conflict.add(i);
        conflict.add(j);
      }
    }
  }
  return conflict;
}
