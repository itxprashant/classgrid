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
import 'package:classgrid/core/attendance.dart';
import 'package:classgrid/core/app_version.dart';
import 'package:classgrid/models/app_version_info.dart';
import 'package:classgrid/core/cgpa.dart';
import 'package:classgrid/core/course_policy.dart';
import 'package:classgrid/core/feedback.dart';
import 'package:classgrid/models/course_policy.dart';
import 'package:classgrid/models/calendar_event.dart';
import 'package:classgrid/models/course.dart';
import 'package:classgrid/models/academic_day.dart';
import 'package:classgrid/models/enrolled_student.dart';
import 'package:classgrid/models/plan.dart';
import 'package:classgrid/models/session.dart';

void main() {
  setUpAll(() {
    setActiveSemesterSchedule(testSemesterScheduleConfig());
  });

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

  group('academicWeekHeadLabel', () {
    test('holiday and swap labels', () {
      expect(
        academicWeekHeadLabel(getAcademicDay(DateTime(2026, 8, 26))),
        'Milad-un-Nabi',
      );
      expect(
        academicWeekHeadLabel(getAcademicDay(DateTime(2026, 9, 3))),
        '→ Friday TT',
      );
      expect(
        academicWeekHeadLabel(getAcademicDay(DateTime(2026, 7, 25))),
        'Weekend',
      );
    });
  });

  group('getClassesForDate', () {
    test('returns empty on institute holiday', () {
      const courses = [
        SelectedCourse(
          courseCode: 'MTL106',
          courseName: 'X',
          lecture: true,
          tutorial: false,
          lab: false,
          lectureTiming: [],
          tutorialTiming: [],
          labTiming: [],
          creditStructure: '3-0-0',
          totalCredits: 3,
        ),
      ];
      const timetable = {
        'MTL106': CourseTimetable(
          lecture: [Session(day: 'Wednesday', start: '0900', end: '1000')],
        ),
      };
      final classes = getClassesForDate(
        DateTime(2026, 8, 26),
        courses,
        timetable,
      );
      expect(classes, isEmpty);
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

  group('eventSortKey', () {
    test('orders timed and at events by start time', () {
      final at = CalendarEvent(
        date: '2026-06-02',
        title: 'Quiz',
        type: 'quiz',
        schedule: 'at',
        time: '1430',
      );
      final timed = CalendarEvent(
        date: '2026-06-02',
        title: 'Talk',
        type: 'others',
        schedule: 'timed',
        start: '0900',
        end: '1000',
      );
      expect(eventSortKey(timed).compareTo(eventSortKey(at)), lessThan(0));
    });

    test('eod sorts after timed starts', () {
      final eod = CalendarEvent(
        date: '2026-06-02',
        title: 'Due',
        type: 'deadline',
        schedule: 'eod',
      );
      expect(eventSortKey(eod), '2400');
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

    test('buildRoomCatalog merges campus rooms when catalog has no venues', () {
      final catalog = buildRoomCatalog(
        [
          courseWithHall(
            code: 'COL106',
            hall: '',
            lectureTiming: '109001000',
          ),
        ],
        campusRooms: const ['LH 111', 'NR 201'],
      );
      expect(catalog.catalogHasVenues, isFalse);
      expect(catalog.usingCampusRoomFallback, isTrue);
      expect(catalog.rooms.length, 2);
      expect(catalog.rooms.every((r) => r.schedulePending), isTrue);
      expect(catalog.rooms.every((r) => r.sessionCount == 0), isTrue);
      expect(catalog.sessionsByRoom['LH 111'], isNull);
    });

    test('roomBuildingGroup maps LH to LHC and academic blocks', () {
      expect(roomBuildingGroup('LH 121'), 'LHC');
      expect(roomBuildingGroup('V707'), 'V');
      expect(roomBuildingGroup('IIA 305'), 'II');
      expect(roomBuildingGroup('VI LT 1'), 'VI');
      expect(roomBuildingGroup('DH'), 'Other');
    });

    test('lhFloor uses first digit after LH', () {
      expect(lhFloor('LH 121'), 1);
      expect(lhFloor('LH 325'), 3);
      expect(lhFloor('LH 413.1'), 4);
    });

    test('filterRooms searches and filters by building tab', () {
      final catalog = buildRoomCatalog([
        courseWithHall(code: 'A', hall: 'LH 101', lectureTiming: '109001000'),
        courseWithHall(code: 'B', hall: 'V 344', lectureTiming: '209001000'),
      ]);
      expect(filterRooms(catalog.rooms, search: '121').length, 0);
      expect(filterRooms(catalog.rooms, building: 'LHC').length, 1);
      expect(filterRooms(catalog.rooms, building: 'V').length, 1);
    });

    test('groupLhRoomsByFloor groups lecture halls by floor', () {
      final catalog = buildRoomCatalog([
        courseWithHall(code: 'A', hall: 'LH 121, LH 325', lectureTiming: '109001000'),
      ]);
      final sections = groupLhRoomsByFloor(catalog.rooms);
      expect(sections.length, 2);
      expect(sections[0].floor, 1);
      expect(sections[1].floor, 3);
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
        location: 'LH 121',
      );
      final start = classEventStart(day, c)!;
      expect(start.hour, 9);
      final notifyAt = reminderNotifyAt(start, kDefaultReminderMinutesBefore)!;
      expect(notifyAt.hour, 8);
      expect(notifyAt.minute, 30);
    });

    test('class reminder body includes type venue and time', () {
      final day = DateTime(2026, 9, 7);
      const c = PlannerClass(
        id: 'COL106-lecture-0900-1000',
        courseCode: 'COL106',
        kind: 'lecture',
        kindLabel: 'L',
        start: '0900',
        end: '1000',
        timeLabel: '09:00',
        location: 'LH 121',
      );
      expect(classReminderTitle(c), 'COL106');
      expect(classReminderBody(c, day), 'Lecture · LH 121 · 09:00');
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

  group('appVersionIsBehind', () {
    test('same version and build is current', () {
      expect(
        appVersionIsBehind(
          installedVersion: '1.0.0',
          installedBuild: 2,
          requiredVersion: '1.0.0',
          requiredBuild: 2,
        ),
        isFalse,
      );
    });

    test('older build on same version requires update', () {
      expect(
        appVersionIsBehind(
          installedVersion: '1.0.0',
          installedBuild: 1,
          requiredVersion: '1.0.0',
          requiredBuild: 2,
        ),
        isTrue,
      );
    });

    test('older version name requires update', () {
      expect(
        appVersionIsBehind(
          installedVersion: '1.0.0',
          installedBuild: 9,
          requiredVersion: '1.0.1',
          requiredBuild: 1,
        ),
        isTrue,
      );
    });

    test('newer install passes', () {
      expect(
        appVersionIsBehind(
          installedVersion: '1.1.0',
          installedBuild: 1,
          requiredVersion: '1.0.0',
          requiredBuild: 99,
        ),
        isFalse,
      );
    });
  });

  group('release status helpers', () {
    AppReleaseStatus status({
      String minVer = '1.0.0',
      int minBuild = 2,
      String latestVer = '1.1.0',
      int latestBuild = 5,
    }) {
      return AppReleaseStatus(
        minimum: AppVersionInfo(
          version: minVer,
          build: minBuild,
          downloadUrl: 'https://example.com/min.apk',
        ),
        latest: AppVersionInfo(
          version: latestVer,
          build: latestBuild,
          downloadUrl: 'https://example.com/latest.apk',
          releaseNotes: '### Added\n- Feature',
        ),
      );
    }

    test('force update when below minimum', () {
      expect(
        isForceUpdateRequired(
          status: status(),
          installedVersion: '1.0.0',
          installedBuild: 1,
        ),
        isTrue,
      );
    });

    test('optional update when above minimum but below latest', () {
      final s = status();
      expect(
        isOptionalUpdateAvailable(
          status: s,
          installedVersion: '1.0.0',
          installedBuild: 2,
        ),
        isTrue,
      );
      expect(
        isForceUpdateRequired(
          status: s,
          installedVersion: '1.0.0',
          installedBuild: 2,
        ),
        isFalse,
      );
    });

    test('no optional update when already on latest', () {
      expect(
        isOptionalUpdateAvailable(
          status: status(),
          installedVersion: '1.1.0',
          installedBuild: 5,
        ),
        isFalse,
      );
    });

    test('shouldShowWhatsNew when build increased', () {
      expect(shouldShowWhatsNew(seenReleaseBuild: 4, installedBuild: 5), isTrue);
      expect(shouldShowWhatsNew(seenReleaseBuild: 5, installedBuild: 5), isFalse);
    });
  });

  group('AppReleaseStatus.fromJson', () {
    test('parses nested minimum and latest', () {
      final parsed = AppReleaseStatus.fromJson({
        'minimum': {'version': '1.0.0', 'build': 2, 'downloadUrl': 'a'},
        'latest': {
          'version': '1.1.0',
          'build': 5,
          'downloadUrl': 'b',
          'releaseNotes': 'Notes',
        },
      });
      expect(parsed.minimum.build, 2);
      expect(parsed.latest.releaseNotes, 'Notes');
    });

    test('legacy flat shape uses same minimum and latest', () {
      final parsed = AppReleaseStatus.fromJson({
        'version': '1.0.0',
        'build': 3,
        'downloadUrl': 'c',
      });
      expect(parsed.minimum.build, 3);
      expect(parsed.latest.build, 3);
    });
  });

  group('attendance', () {
    AttendanceBucket emptyBucket() =>
        const AttendanceBucket(courseCode: 'COL106', sessionKind: 'lecture');

    test('applyMark increments and transitions counters', () {
      var b = emptyBucket();
      b = applyMark(b, '2026-08-04', newStatus: 'present');
      expect(b.present, 1);
      expect(b.byDate['2026-08-04'], 'present');

      b = applyMark(b, '2026-08-04', newStatus: 'absent');
      expect(b.present, 0);
      expect(b.absent, 1);

      b = applyMark(b, '2026-08-04');
      expect(b.absent, 0);
      expect(b.byDate.containsKey('2026-08-04'), isFalse);
    });

    test('computeBucketStats excludes excused from percent', () {
      final bucket = const AttendanceBucket(
        courseCode: 'COL106',
        sessionKind: 'lecture',
        present: 3,
        absent: 1,
        excused: 2,
      );
      final stats = computeBucketStats(bucket: bucket, scheduledCount: 10);
      expect(stats.percent, closeTo(75, 0.01));
      expect(stats.unmarked, 4);
      expect(stats.safeMissesLeft, greaterThanOrEqualTo(0));
    });

    test('classEventEnd parses session end time', () {
      const c = PlannerClass(
        id: 'COL106-lecture-09001000',
        courseCode: 'COL106',
        kind: 'lecture',
        kindLabel: 'L',
        start: '0900',
        end: '1000',
        timeLabel: '09:00',
      );
      final end = classEventEnd(DateTime(2026, 8, 4), c);
      expect(end?.hour, 10);
      expect(end?.minute, 0);
    });
  });

  group('cgpa', () {
    const rows = [
      CgpaCourseRow(code: 'COL106', credits: 5, gradeSelection: '9'),
      CgpaCourseRow(code: 'MTL100', credits: 4, gradeSelection: '8'),
      CgpaCourseRow(code: 'PYL101', credits: 3, gradeSelection: '10'),
    ];

    test('computeSgpa weighted average of graded rows', () {
      // (9*5 + 8*4 + 10*3) / 12 = 107/12
      expect(computeSgpa(rows), closeTo(107 / 12, 0.001));
    });

    test('computeSgpa ignores rows without grade', () {
      final partial = [
        ...rows,
        const CgpaCourseRow(code: 'XXX', credits: 2),
      ];
      expect(computeSgpa(partial), closeTo(107 / 12, 0.001));
    });

    test('computeSgpa returns null when no graded credits', () {
      expect(
        computeSgpa(const [CgpaCourseRow(code: 'A', credits: 3)]),
        isNull,
      );
    });

    test('computeCgpa combines prior record with semester', () {
      // prior: 8.5 over 60 credits; semester points 107 over 12
      final cgpa = computeCgpa(
        priorCgpa: 8.5,
        priorCredits: 60,
        rows: rows,
      );
      expect(cgpa, closeTo((8.5 * 60 + 107) / 72, 0.001));
    });

    test('W and A are excluded from SGPA and CGPA', () {
      const withdrawn = [
        CgpaCourseRow(code: 'A', credits: 4, gradeSelection: '9'),
        CgpaCourseRow(code: 'B', credits: 3, gradeSelection: 'W'),
        CgpaCourseRow(code: 'C', credits: 2, gradeSelection: 'A'),
      ];
      expect(computeSgpa(withdrawn), closeTo(9.0, 0.001));
      expect(
        computeCgpa(priorCgpa: 8.0, priorCredits: 20, rows: withdrawn),
        closeTo((8.0 * 20 + 9 * 4) / 24, 0.001),
      );
    });

    test('F counts as 0 in SGPA but is excluded from CGPA', () {
      const failed = [
        CgpaCourseRow(code: 'A', credits: 5, gradeSelection: '9'),
        CgpaCourseRow(code: 'B', credits: 4, gradeSelection: 'F'),
      ];
      // SGPA: (9*5 + 0*4) / 9
      expect(computeSgpa(failed), closeTo(45 / 9, 0.001));
      // CGPA: only the passing course counts this semester
      expect(
        computeCgpa(priorCgpa: 8.0, priorCredits: 60, rows: failed),
        closeTo((8.0 * 60 + 9 * 5) / 65, 0.001),
      );
    });

    test('normalizeGradeSelection accepts numeric and special grades', () {
      expect(normalizeGradeSelection('9'), '9');
      expect(normalizeGradeSelection('w'), 'W');
      expect(normalizeGradeSelection('F'), 'F');
      expect(normalizeGradeSelection('3'), isNull);
      expect(normalizeGradeSelection('11'), isNull);
    });
  });

  group('course policy', () {
    test('isPolicySubmittable requires at least one non-empty field', () {
      final empty = CoursePolicyDraft();
      expect(isPolicySubmittable(empty), isFalse);

      empty.markingScheme = '  Midsem 30%  ';
      expect(isPolicySubmittable(empty), isTrue);
    });

    test('policyPayload trims fields', () {
      final draft = CoursePolicyDraft()
        ..markingScheme = '  A  '
        ..attendancePolicy = ''
        ..auditWithdrawalPolicy = ' B '
        ..otherNotes = '  ';
      expect(policyPayload(draft), {
        'markingScheme': 'A',
        'attendancePolicy': '',
        'auditWithdrawalPolicy': 'B',
        'otherNotes': '',
      });
    });
  });

  group('feedback', () {
    test('isFeedbackSubmittable enforces min length', () {
      expect(isFeedbackSubmittable(''), isFalse);
      expect(isFeedbackSubmittable('123456789'), isFalse);
      expect(isFeedbackSubmittable('1234567890'), isTrue);
    });
  });
}
