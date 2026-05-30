import 'package:flutter_test/flutter_test.dart';

import 'package:classgrid/core/timing.dart';
import 'package:classgrid/core/clashes.dart';
import 'package:classgrid/core/semester_schedule.dart';
import 'package:classgrid/core/calendar_events.dart';
import 'package:classgrid/core/ics.dart';
import 'package:classgrid/models/academic_day.dart';
import 'package:classgrid/models/plan.dart';
import 'package:classgrid/models/session.dart';

void main() {
  group('parseTimingStr', () {
    test('parses comma-separated DHHMMHHMM chunks', () {
      final sessions = parseTimingStr('209001000,309001000,509001000');
      expect(sessions.length, 3);
      expect(sessions[0].day, 'Tuesday');
      expect(sessions[0].start, '0900');
      expect(sessions[0].end, '1000');
      expect(sessions[2].day, 'Friday');
    });

    test('returns empty for null/empty/short', () {
      expect(parseTimingStr(null), isEmpty);
      expect(parseTimingStr(''), isEmpty);
      expect(parseTimingStr('abc'), isEmpty);
    });

    test('skips unknown day codes', () {
      expect(parseTimingStr('609001000'), isEmpty);
    });
  });

  group('toMinutes', () {
    test('converts HHMM to minutes', () {
      expect(toMinutes('0900'), 540);
      expect(toMinutes('1430'), 870);
    });
  });

  group('conflict detection', () {
    SelectedCourse course(String code, List<Session> lec) => SelectedCourse(
          courseCode: code,
          courseName: code,
          lecture: true,
          tutorial: false,
          lab: false,
          lectureTiming: lec,
          tutorialTiming: const [],
          labTiming: const [],
          creditStructure: '3.0-0.0-0.0',
          totalCredits: 3,
        );

    test('detects overlap across different courses', () {
      final courses = [course('A', const []), course('B', const [])];
      final td = {
        'A': const CourseTimetable(
            lecture: [Session(day: 'Monday', start: '0900', end: '1000')]),
        'B': const CourseTimetable(
            lecture: [Session(day: 'Monday', start: '0930', end: '1030')]),
      };
      expect(countConflicts(courses, td), 1);
      expect(conflictIndices(flattenSessions(courses, td)).length, 2);
    });

    test('ignores same-course and different-day overlaps', () {
      final courses = [course('A', const [])];
      final td = {
        'A': const CourseTimetable(lecture: [
          Session(day: 'Monday', start: '0900', end: '1000'),
          Session(day: 'Monday', start: '0930', end: '1030'),
        ]),
      };
      expect(countConflicts(courses, td), 0);
    });

    test('adjacent sessions do not conflict', () {
      final courses = [course('A', const []), course('B', const [])];
      final td = {
        'A': const CourseTimetable(
            lecture: [Session(day: 'Tuesday', start: '0900', end: '1000')]),
        'B': const CourseTimetable(
            lecture: [Session(day: 'Tuesday', start: '1000', end: '1100')]),
      };
      expect(countConflicts(courses, td), 0);
    });
  });

  group('getAcademicDay', () {
    test('holiday', () {
      final info = getAcademicDay(DateTime(2026, 8, 15));
      expect(info.type, AcademicType.holiday);
      expect(info.hasClasses, false);
      expect(info.name, 'Independence Day');
    });

    test('swap: Saturday runs Wednesday timetable', () {
      final info = getAcademicDay(DateTime(2026, 10, 10));
      expect(info.type, AcademicType.swapped);
      expect(info.effectiveDay, 'Wednesday');
      expect(info.effectiveDayCode, 3);
      expect(info.hasClasses, true);
    });

    test('normal weekday in term', () {
      final info = getAcademicDay(DateTime(2026, 7, 24)); // Friday
      expect(info.type, AcademicType.normal);
      expect(info.effectiveDayCode, 5);
    });

    test('weekend', () {
      final info = getAcademicDay(DateTime(2026, 7, 25)); // Saturday
      expect(info.type, AcademicType.weekend);
      expect(info.hasClasses, false);
    });

    test('break period', () {
      final info = getAcademicDay(DateTime(2026, 9, 15));
      expect(info.type, AcademicType.breakPeriod);
      expect(isExamPeriod(info.name), true);
    });

    test('before and after term', () {
      expect(getAcademicDay(DateTime(2026, 7, 1)).type, AcademicType.beforeTerm);
      expect(getAcademicDay(DateTime(2026, 12, 1)).type, AcademicType.afterTerm);
    });
  });

  group('isDraftScheduleValid', () {
    test('fullday and eod always valid', () {
      expect(isDraftScheduleValid(EventDraft.empty('2026-08-01')), true);
      final d = EventDraft.empty('2026-08-01')..schedule = 'eod';
      expect(isDraftScheduleValid(d), true);
    });

    test('at requires a time', () {
      final d = EventDraft.empty('2026-08-01')..schedule = 'at';
      expect(isDraftScheduleValid(d), false);
      d.time = '14:30';
      expect(isDraftScheduleValid(d), true);
    });

    test('timed requires start < end', () {
      final d = EventDraft.empty('2026-08-01')
        ..schedule = 'timed'
        ..start = '1400'
        ..end = '1300';
      expect(isDraftScheduleValid(d), false);
      d.end = '1500';
      expect(isDraftScheduleValid(d), true);
    });
  });

  group('normalizeHHMM', () {
    test('accepts HH:MM and HHMM', () {
      expect(normalizeHHMM('14:30'), '1430');
      expect(normalizeHHMM('1430'), '1430');
      expect(normalizeHHMM('bad'), null);
      expect(normalizeHHMM(''), null);
    });
  });

  group('generateICS', () {
    test('produces a valid calendar with VTIMEZONE and weekly RRULE', () {
      final courses = [
        const SelectedCourse(
          courseCode: 'COL106',
          courseName: 'DSA',
          lecture: true,
          tutorial: false,
          lab: false,
          lectureTiming: [],
          tutorialTiming: [],
          labTiming: [],
          creditStructure: '3.0-0.0-0.0',
          totalCredits: 5,
          lectureHall: 'LH 111',
        ),
      ];
      final td = {
        'COL106': const CourseTimetable(
            lecture: [Session(day: 'Monday', start: '0900', end: '1000')]),
      };
      final ics = generateICS(courses, td);
      expect(ics.contains('BEGIN:VCALENDAR'), true);
      expect(ics.contains('END:VCALENDAR'), true);
      expect(ics.contains('TZID:Asia/Kolkata'), true);
      expect(ics.contains('RRULE:FREQ=WEEKLY;BYDAY=MO'), true);
      expect(ics.contains('SUMMARY:COL106 Lecture (LH 111)'), true);
      expect(ics.contains('\r\n'), true);
      // CRLF line endings throughout.
      expect(ics.endsWith('\r\n'), true);
    });
  });
}
