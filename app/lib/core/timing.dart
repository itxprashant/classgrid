import '../models/session.dart';

const Map<String, String> _dayCodeToName = {
  '1': 'Monday',
  '2': 'Tuesday',
  '3': 'Wednesday',
  '4': 'Thursday',
  '5': 'Friday',
};

const List<String> kWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

/// Parses a `DHHMMHHMM` comma-separated timing string into [Session]s.
/// Mirrors `parseTimingStr` in the web Generator.
List<Session> parseTimingStr(String? timingStr) {
  if (timingStr == null || timingStr.isEmpty) return const [];
  final result = <Session>[];
  for (final t in timingStr.split(',')) {
    if (t.length < 9) continue;
    final dayCode = t[0];
    final start = t.substring(1, 5);
    final end = t.substring(5, 9);
    final day = _dayCodeToName[dayCode];
    if (day == null) continue;
    result.add(Session(day: day, start: start, end: end));
  }
  return result;
}

/// Minutes since midnight from an `HHMM` string.
int toMinutes(String t) {
  if (t.length < 4) return 0;
  return int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(2, 4));
}
