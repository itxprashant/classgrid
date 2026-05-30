import '../models/plan.dart';
import '../models/session.dart';
import 'semester_schedule.dart';

const Map<String, String> _kindLabel = {
  'lecture': 'L',
  'tutorial': 'T',
  'lab': 'Lab',
};

/// A planner class instance resolved onto a calendar date.
class PlannerClass {
  final String id;
  final String courseCode;
  final String kind; // lecture|tutorial|lab
  final String kindLabel;
  final String start;
  final String end;
  final String timeLabel; // HH:MM

  const PlannerClass({
    required this.id,
    required this.courseCode,
    required this.kind,
    required this.kindLabel,
    required this.start,
    required this.end,
    required this.timeLabel,
  });
}

String _formatSessionTime(String start) {
  if (start.length != 4) return start;
  return '${start.substring(0, 2)}:${start.substring(2)}';
}

/// Classes that run on [date] given the plan, honouring the academic calendar
/// (swaps/holidays). Mirrors `getClassesForDate` in `plannerClasses.js`.
List<PlannerClass> getClassesForDate(
  DateTime date,
  List<SelectedCourse> courses,
  Map<String, CourseTimetable> timetableData,
) {
  final academic = getAcademicDay(date);
  if (!academic.hasClasses || academic.effectiveDay == null) return const [];

  final sessions = <PlannerClass>[];
  for (final course in courses) {
    final data = timetableData[course.courseCode];
    if (data == null) continue;

    void addFrom(List<Session>? slots, String kind) {
      if (slots == null) return;
      for (final slot in slots) {
        if (slot.day != academic.effectiveDay) continue;
        sessions.add(PlannerClass(
          id: '${course.courseCode}-$kind-${slot.start}-${slot.end}',
          courseCode: course.courseCode,
          kind: kind,
          kindLabel: _kindLabel[kind] ?? kind,
          start: slot.start,
          end: slot.end,
          timeLabel: _formatSessionTime(slot.start),
        ));
      }
    }

    addFrom(data.lecture, 'lecture');
    addFrom(data.tutorial, 'tutorial');
    addFrom(data.lab, 'lab');
  }

  sessions.sort((a, b) {
    final c = a.start.compareTo(b.start);
    return c != 0 ? c : a.courseCode.compareTo(b.courseCode);
  });
  return sessions;
}

/// Map of dateKey -> classes for a list of dates (only dates with classes).
Map<String, List<PlannerClass>> buildClassesByDate(
  List<DateTime> dates,
  List<SelectedCourse> courses,
  Map<String, CourseTimetable> timetableData,
) {
  final map = <String, List<PlannerClass>>{};
  for (final date in dates) {
    final classes = getClassesForDate(date, courses, timetableData);
    if (classes.isNotEmpty) {
      map[formatDateKey(date)] = classes;
    }
  }
  return map;
}
