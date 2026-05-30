import 'package:flutter_test/flutter_test.dart';

import 'package:classgrid/core/timing.dart';
import 'package:classgrid/core/clashes.dart';
import 'package:classgrid/core/semester_schedule.dart';
import 'package:classgrid/core/calendar_events.dart';
import 'package:classgrid/core/ics.dart';
import 'package:classgrid/core/roster.dart';
import 'package:classgrid/core/auth_token.dart';
import 'package:classgrid/core/empty_halls.dart';
import 'package:classgrid/core/reminder_schedule.dart';
import 'package:classgrid/core/room_schedule.dart';
import 'package:classgrid/core/planner_classes.dart';
import 'package:classgrid/models/calendar_event.dart';
import 'package:classgrid/models/course.dart';
import 'package:classgrid/models/academic_day.dart';
import 'package:classgrid/models/enrolled_student.dart';
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

  group('parseSessionTokenInput', () {
    test('accepts raw JWT', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJzZXNzaW9uIn0.sig';
      expect(parseSessionTokenInput(jwt), jwt);
    });

    test('extracts token from deep link', () {
      expect(
        parseSessionTokenInput('classgrid://auth/callback?token=abc.def.ghi'),
        'abc.def.ghi',
      );
    });
  });

  group('room schedule', () {
    Course courseWithHall({
      required String code,
      required String hall,
      String? lectureTiming,
    }) =>
        Course(
          courseCode: code,
          courseName: 'Test $code',
          totalCredits: 3,
          creditStructure: '3.0-0.0-0.0',
          slot: Slot(lectureTiming: lectureTiming),
          lectureHall: hall,
        );

    test('normalizeRoomName standardizes LH spacing', () {
      expect(normalizeRoomName('lh121'), 'LH 121');
      expect(normalizeRoomName('LH  108'), 'LH 108');
    });

    test('buildRoomCatalog maps sessions to each hall', () {
      final catalog = buildRoomCatalog([
        courseWithHall(
          code: 'COL106',
          hall: 'LH 111, LH 121',
          lectureTiming: '109001000',
        ),
      ]);
      expect(catalog.rooms.length, 2);
      expect(catalog.sessionsByRoom['LH 111']!.length, 1);
      expect(catalog.sessionsByRoom['LH 111']!.first.courseCode, 'COL106');
      expect(catalog.sessionsByRoom['LH 121']!.first.day, 'Monday');
    });

    test('filterRooms searches and filters by building', () {
      final catalog = buildRoomCatalog([
        courseWithHall(code: 'A', hall: 'LH 101', lectureTiming: '109001000'),
        courseWithHall(code: 'B', hall: 'NR 201', lectureTiming: '209001000'),
      ]);
      expect(filterRooms(catalog.rooms, search: '121').length, 0);
      expect(filterRooms(catalog.rooms, prefix: 'LH').length, 1);
    });

    test('roomSessionOverlapIndices flags different courses', () {
      final sessions = [
        const RoomSession(
          courseCode: 'A',
          courseName: 'A',
          type: 'Lecture',
          day: 'Monday',
          start: '0900',
          end: '1000',
        ),
        const RoomSession(
          courseCode: 'B',
          courseName: 'B',
          type: 'Lecture',
          day: 'Monday',
          start: '0930',
          end: '1030',
        ),
      ];
      expect(roomSessionOverlapIndices(sessions).length, 2);
    });
  });

  group('empty halls', () {
    Course courseWithSlots({
      required String code,
      required String hall,
      String? lectureTiming,
      String? tutorialTiming,
      String? labTiming,
    }) =>
        Course(
          courseCode: code,
          courseName: 'Test $code',
          totalCredits: 3,
          creditStructure: '3.0-0.0-0.0',
          slot: Slot(
            lectureTiming: lectureTiming,
            tutorialTiming: tutorialTiming,
            labTiming: labTiming,
          ),
          lectureHall: hall,
        );

    test('includes non-LH rooms from catalog', () {
      final at = DateTime(2026, 9, 7, 10, 30); // Monday 10:30
      final r = computeEmptyHalls(
        courses: [
          courseWithSlots(code: 'X', hall: 'NR 201', lectureTiming: '209001100'),
        ],
        at: at,
      );
      expect(r.totalTracked, 1);
      expect(r.freeCount, 1);
    });

    test('tutorial timing marks room occupied', () {
      final at = DateTime(2026, 9, 7, 10, 30);
      final r = computeEmptyHalls(
        courses: [
          courseWithSlots(
            code: 'COL106',
            hall: 'LH 111',
            tutorialTiming: '110001100',
          ),
        ],
        at: at,
      );
      expect(r.freeCount, 0);
      expect(r.timetableOccupiedCount, 1);
    });
  });

  group('reminder schedule', () {
    test('class reminder fires 30 minutes before start', () {
      final day = DateTime(2026, 9, 7);
      const c = PlannerClass(
        id: 'COL106-lecture-0900-1000',
        courseCode: 'COL106',
        kind: 'lecture',
        kindLabel: 'L',
        start: '0900',
        end: '1000',
        timeLabel: '09:00',
      );
      final start = classEventStart(day, c)!;
      expect(start.hour, 9);
      expect(
        start.subtract(const Duration(minutes: kReminderMinutesBefore)).hour,
        8,
      );
      expect(
        start.subtract(const Duration(minutes: kReminderMinutesBefore)).minute,
        30,
      );
    });

    test('timed events can remind; fullday cannot', () {
      final timed = CalendarEvent(
        date: '2026-09-07',
        title: 'Quiz',
        type: 'quiz',
        schedule: 'at',
        time: '1400',
      );
      final allDay = CalendarEvent(
        date: '2026-09-07',
        title: 'Deadline',
        type: 'deadline',
        schedule: 'fullday',
      );
      expect(calendarEventStart(timed)?.hour, 14);
      expect(calendarEventStart(allDay), isNull);
    });
  });

  group('branchCounts', () {
    test('groups by kerberos prefix', () {
      const students = [
        EnrolledStudent(id: 'cs120001', name: 'A'),
        EnrolledStudent(id: 'cs120002', name: 'B'),
        EnrolledStudent(id: 'mt120001', name: 'C'),
      ];
      final rows = branchCounts(students);
      expect(rows.length, 2);
      expect(rows[0].branch, 'CS1');
      expect(rows[0].count, 2);
      expect(rows[1].branch, 'MT1');
    });
  });
}
