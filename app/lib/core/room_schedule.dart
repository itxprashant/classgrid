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
  final bool schedulePending;

  const RoomInfo({
    required this.name,
    required this.prefix,
    required this.sessionCount,
    this.schedulePending = false,
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
  final bool usingCampusRoomFallback;

  const RoomCatalog({
    required this.rooms,
    required this.sessionsByRoom,
    required this.catalogHasVenues,
    required this.catalogHasSessions,
    this.usingCampusRoomFallback = false,
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

/// Browse tabs: LHC (lecture halls) + academic blocks I–VI.
const List<String> kRoomBuildingTabs = ['LHC', 'I', 'II', 'III', 'IV', 'V', 'VI'];

const String kDefaultRoomBuildingTab = 'LHC';

String roomBuildingGroup(String name) {
  final n = normalizeRoomName(name);
  if (RegExp(r'^LH\b', caseSensitive: false).hasMatch(n)) return 'LHC';
  if (RegExp(r'^III\b', caseSensitive: false).hasMatch(n)) return 'III';
  if (RegExp(r'^IIA\b', caseSensitive: false).hasMatch(n)) return 'II';
  if (RegExp(r'^II\b', caseSensitive: false).hasMatch(n)) return 'II';
  if (RegExp(r'^IV\b', caseSensitive: false).hasMatch(n)) return 'IV';
  if (RegExp(r'^VI\b', caseSensitive: false).hasMatch(n)) return 'VI';
  if (RegExp(r'^V(?:\s|\d)', caseSensitive: false).hasMatch(n)) return 'V';
  if (RegExp(r'^I(?:\s|\d|LT)', caseSensitive: false).hasMatch(n)) return 'I';
  return 'Other';
}

/// First digit after "LH " is the floor (LH 121 → 1, LH 325 → 3).
int? lhFloor(String name) {
  final m = RegExp(r'^LH\s+(\d)', caseSensitive: false).firstMatch(normalizeRoomName(name));
  return m != null ? int.parse(m.group(1)!) : null;
}

class LhFloorSection {
  final int floor;
  final String label;
  final List<RoomInfo> rooms;

  const LhFloorSection({
    required this.floor,
    required this.label,
    required this.rooms,
  });
}

List<BuildingCount> buildingTabCounts(List<RoomInfo> rooms) {
  final counts = {for (final code in kRoomBuildingTabs) code: 0};
  var other = 0;
  for (final room in rooms) {
    final group = roomBuildingGroup(room.name);
    if (counts.containsKey(group)) {
      counts[group] = counts[group]! + 1;
    } else {
      other += 1;
    }
  }
  final tabs = kRoomBuildingTabs
      .map((code) => BuildingCount(code, counts[code] ?? 0))
      .toList();
  if (other > 0) tabs.add(BuildingCount('Other', other));
  return tabs;
}

List<LhFloorSection> groupLhRoomsByFloor(List<RoomInfo> rooms) {
  final byFloor = <int, List<RoomInfo>>{};
  for (final room in rooms) {
    final floor = lhFloor(room.name) ?? 0;
    byFloor.putIfAbsent(floor, () => []).add(room);
  }
  final floors = byFloor.keys.toList()..sort();
  return floors
      .map(
        (floor) => LhFloorSection(
          floor: floor,
          label: floor > 0 ? 'Floor $floor' : 'Other',
          rooms: byFloor[floor]!..sort((a, b) => _compareRoomNames(a.name, b.name)),
        ),
      )
      .toList();
}

class LhFloorEntrySection<T> {
  final int floor;
  final String label;
  final List<T> items;

  const LhFloorEntrySection({
    required this.floor,
    required this.label,
    required this.items,
  });
}

List<BuildingCount> buildingTabCountsForRoomNames(Iterable<String> roomNames) {
  final counts = {for (final code in kRoomBuildingTabs) code: 0};
  var other = 0;
  for (final name in roomNames) {
    final group = roomBuildingGroup(name);
    if (counts.containsKey(group)) {
      counts[group] = counts[group]! + 1;
    } else {
      other += 1;
    }
  }
  final tabs = kRoomBuildingTabs
      .map((code) => BuildingCount(code, counts[code] ?? 0))
      .toList();
  if (other > 0) tabs.add(BuildingCount('Other', other));
  return tabs;
}

List<T> filterEntriesByBuilding<T>(
  List<T> entries,
  String building,
  String Function(T item) roomName,
) {
  if (building.isEmpty) return entries;
  return entries
      .where((entry) => roomBuildingGroup(roomName(entry)) == building)
      .toList();
}

List<LhFloorEntrySection<T>> groupLhEntriesByFloor<T>(
  List<T> entries,
  String Function(T item) roomName,
) {
  final byFloor = <int, List<T>>{};
  for (final entry in entries) {
    final floor = lhFloor(roomName(entry)) ?? 0;
    byFloor.putIfAbsent(floor, () => []).add(entry);
  }
  final floors = byFloor.keys.toList()..sort();
  return floors
      .map(
        (floor) => LhFloorEntrySection<T>(
          floor: floor,
          label: floor > 0 ? 'Floor $floor' : 'Other',
          items: byFloor[floor]!
            ..sort((a, b) => _compareRoomNames(roomName(a), roomName(b))),
        ),
      )
      .toList();
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
  List<String> campusRooms = const [],
}) {
  final sessionsByRoom = <String, List<RoomSession>>{};
  final roomNames = <String>{};
  final fallbackOnly = <String>{};

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

  final catalogHasVenues = courses.any((c) => (c.lectureHall ?? '').isNotEmpty);
  var usingCampusRoomFallback = false;

  if (!catalogHasVenues && campusRooms.isNotEmpty) {
    usingCampusRoomFallback = true;
    for (final raw in campusRooms) {
      final room = normalizeRoomName(raw);
      if (room.isEmpty) continue;
      if (!roomNames.contains(room)) {
        fallbackOnly.add(room);
      }
      roomNames.add(room);
    }
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
          schedulePending: usingCampusRoomFallback
              && fallbackOnly.contains(name)
              && (sortedSessions[name]?.length ?? 0) == 0,
        ),
      )
      .toList();

  final catalogHasSessions = roomInfos.any((r) => r.sessionCount > 0);

  return RoomCatalog(
    rooms: roomInfos,
    sessionsByRoom: sortedSessions,
    catalogHasVenues: catalogHasVenues,
    catalogHasSessions: catalogHasSessions,
    usingCampusRoomFallback: usingCampusRoomFallback,
  );
}

List<RoomSession> sessionsForRoom(Map<String, List<RoomSession>> byRoom, String roomName) {
  return byRoom[normalizeRoomName(roomName)] ?? const [];
}

List<BuildingCount> roomBuildingCounts(List<RoomInfo> rooms) => buildingTabCounts(rooms);

List<RoomInfo> filterRooms(
  List<RoomInfo> rooms, {
  String search = '',
  String? prefix,
  String? building,
}) {
  final term = search.trim().toLowerCase();
  return rooms.where((room) {
    if (building != null && building.isNotEmpty && roomBuildingGroup(room.name) != building) {
      return false;
    }
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
