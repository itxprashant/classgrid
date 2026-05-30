import '../models/plan.dart';
import '../models/session.dart';
import 'timing.dart';

/// A session flattened from the plan, tagged with its owning course + type.
class GridSession {
  final String courseCode;
  final String type; // 'Lecture' | 'Tutorial' | 'Lab'
  final String day;
  final String start;
  final String end;
  final String location;

  const GridSession({
    required this.courseCode,
    required this.type,
    required this.day,
    required this.start,
    required this.end,
    required this.location,
  });
}

/// Flattens all valid lecture/tutorial/lab sessions from [timetableData] into
/// [GridSession]s, only including Mon–Fri days. Lecture location falls back to
/// the course's `lectureHall`. Mirrors `TimetableGrid` session collection.
List<GridSession> flattenSessions(
  List<SelectedCourse> courses,
  Map<String, CourseTimetable> timetableData,
) {
  final result = <GridSession>[];
  for (final course in courses) {
    final data = timetableData[course.courseCode];
    if (data == null) continue;

    void collect(List<Session>? arr, String type, String? fallbackHall) {
      if (arr == null) return;
      for (final s in arr) {
        if (!kWeekdays.contains(s.day)) continue;
        result.add(GridSession(
          courseCode: course.courseCode,
          type: type,
          day: s.day,
          start: s.start,
          end: s.end,
          location: (s.location?.isNotEmpty ?? false)
              ? s.location!
              : (fallbackHall ?? ''),
        ));
      }
    }

    collect(data.lecture, 'Lecture', course.lectureHall);
    collect(data.tutorial, 'Tutorial', null);
    collect(data.lab, 'Lab', null);
  }
  return result;
}

/// Indices of [sessions] that conflict with another session (different course,
/// same day, overlapping interval). Mirrors `conflictSet` in `TimetableGrid`.
Set<int> conflictIndices(List<GridSession> sessions) {
  final set = <int>{};
  for (var i = 0; i < sessions.length; i++) {
    for (var j = i + 1; j < sessions.length; j++) {
      final a = sessions[i];
      final b = sessions[j];
      if (a.day != b.day) continue;
      if (a.courseCode == b.courseCode) continue;
      final aStart = toMinutes(a.start);
      final aEnd = toMinutes(a.end);
      final bStart = toMinutes(b.start);
      final bEnd = toMinutes(b.end);
      if (aStart < bEnd && bStart < aEnd) {
        set.add(i);
        set.add(j);
      }
    }
  }
  return set;
}

/// Number of overlapping session pairs across the plan. Mirrors the web's
/// `stats.conflicts` memo (uses raw plan sessions, not the grid fallback).
int countConflicts(
  List<SelectedCourse> courses,
  Map<String, CourseTimetable> timetableData,
) {
  final sessions = <_PlanSession>[];
  for (final course in courses) {
    final cd = timetableData[course.courseCode];
    if (cd == null) continue;
    for (final arr in [cd.lecture, cd.tutorial, cd.lab]) {
      if (arr == null) continue;
      for (final s in arr) {
        if (s.day.isNotEmpty && s.start.isNotEmpty && s.end.isNotEmpty) {
          sessions.add(_PlanSession(course.courseCode, s.day, s.start, s.end));
        }
      }
    }
  }
  var conflicts = 0;
  for (var i = 0; i < sessions.length; i++) {
    for (var j = i + 1; j < sessions.length; j++) {
      final a = sessions[i];
      final b = sessions[j];
      if (a.day != b.day || a.courseCode == b.courseCode) continue;
      if (toMinutes(a.start) < toMinutes(b.end) &&
          toMinutes(b.start) < toMinutes(a.end)) {
        conflicts++;
      }
    }
  }
  return conflicts;
}

/// Total credits across the plan.
double totalCredits(List<SelectedCourse> courses) =>
    courses.fold(0.0, (sum, c) => sum + c.totalCredits);

class _PlanSession {
  final String courseCode;
  final String day;
  final String start;
  final String end;
  _PlanSession(this.courseCode, this.day, this.start, this.end);
}
