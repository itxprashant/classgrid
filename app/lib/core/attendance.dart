import '../models/plan.dart';
import 'planner_classes.dart';

const int kDefaultAttendanceThreshold = 75;
const int kAttendancePromptDaysAhead = 14;

const Set<String> kAttendanceStatuses = {'present', 'absent', 'excused'};
const Set<String> kSessionKinds = {'lecture', 'tutorial', 'lab'};

/// Per (courseCode, sessionKind) attendance bucket with denormalized counters.
class AttendanceBucket {
  final String courseCode;
  final String sessionKind;
  final int present;
  final int absent;
  final int excused;
  final Map<String, String> byDate;

  const AttendanceBucket({
    required this.courseCode,
    required this.sessionKind,
    this.present = 0,
    this.absent = 0,
    this.excused = 0,
    Map<String, String>? byDate,
  }) : byDate = byDate ?? const {};

  AttendanceBucket copyWith({
    int? present,
    int? absent,
    int? excused,
    Map<String, String>? byDate,
  }) {
    return AttendanceBucket(
      courseCode: courseCode,
      sessionKind: sessionKind,
      present: present ?? this.present,
      absent: absent ?? this.absent,
      excused: excused ?? this.excused,
      byDate: byDate ?? this.byDate,
    );
  }

  String bucketKey() => '$courseCode|$sessionKind';

  Map<String, dynamic> toJson() => {
        'courseCode': courseCode,
        'sessionKind': sessionKind,
        'present': present,
        'absent': absent,
        'excused': excused,
        'byDate': byDate,
      };

  factory AttendanceBucket.fromJson(Map<String, dynamic> json) {
    final rawDates = json['byDate'];
    final dates = <String, String>{};
    if (rawDates is Map) {
      for (final e in rawDates.entries) {
        final v = e.value?.toString();
        if (v != null && kAttendanceStatuses.contains(v)) {
          dates[e.key.toString()] = v;
        }
      }
    }
    return AttendanceBucket(
      courseCode: (json['courseCode'] as String).trim(),
      sessionKind: (json['sessionKind'] as String).trim(),
      present: (json['present'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      excused: (json['excused'] as num?)?.toInt() ?? 0,
      byDate: dates,
    );
  }
}

class AttendanceBucketStats {
  final int present;
  final int absent;
  final int excused;
  final int scheduled;
  final int unmarked;
  final double? percent;
  final int safeMissesLeft;

  const AttendanceBucketStats({
    required this.present,
    required this.absent,
    required this.excused,
    required this.scheduled,
    required this.unmarked,
    required this.percent,
    required this.safeMissesLeft,
  });
}

String attendPromptKey(String dateKey, PlannerClass c) =>
    'attend-prompt|$dateKey|${c.id}';

/// Wall-clock end of a planner class on [day].
DateTime? classEventEnd(DateTime day, PlannerClass c) {
  if (c.end.length != 4) return null;
  final h = int.tryParse(c.end.substring(0, 2));
  final m = int.tryParse(c.end.substring(2, 4));
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

AttendanceBucket _adjustCounter(AttendanceBucket bucket, String status, int delta) {
  switch (status) {
    case 'present':
      return bucket.copyWith(present: (bucket.present + delta).clamp(0, 1 << 30));
    case 'absent':
      return bucket.copyWith(absent: (bucket.absent + delta).clamp(0, 1 << 30));
    case 'excused':
      return bucket.copyWith(excused: (bucket.excused + delta).clamp(0, 1 << 30));
    default:
      return bucket;
  }
}

/// Apply a mark transition on [dateKey]; [newStatus] null clears the date.
AttendanceBucket applyMark(
  AttendanceBucket bucket,
  String dateKey, {
  String? newStatus,
}) {
  if (newStatus != null && !kAttendanceStatuses.contains(newStatus)) {
    return bucket;
  }

  final oldStatus = bucket.byDate[dateKey];
  var next = bucket;
  final dates = Map<String, String>.from(bucket.byDate);

  if (oldStatus != null && kAttendanceStatuses.contains(oldStatus)) {
    next = _adjustCounter(next, oldStatus, -1);
    dates.remove(dateKey);
  }

  if (newStatus != null) {
    next = _adjustCounter(next, newStatus, 1);
    dates[dateKey] = newStatus;
  }

  return next.copyWith(byDate: dates);
}

/// Count scheduled sessions per `(courseCode, sessionKind)` from [from] through [to] inclusive.
Map<String, int> countScheduledSessions({
  required DateTime from,
  required DateTime to,
  required List<SelectedCourse> courses,
  required Map<String, CourseTimetable> timetableData,
  DateTime? through,
}) {
  final end = through ?? to;
  final counts = <String, int>{};
  var cursor = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);

  while (!cursor.isAfter(last)) {
    if (!cursor.isAfter(end)) {
      final classes = getClassesForDate(cursor, courses, timetableData);
      for (final c in classes) {
        final key = '${c.courseCode}|${c.kind}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return counts;
}

AttendanceBucketStats computeBucketStats({
  required AttendanceBucket bucket,
  required int scheduledCount,
  int thresholdPercent = kDefaultAttendanceThreshold,
}) {
  final present = bucket.present;
  final absent = bucket.absent;
  final excused = bucket.excused;
  final marked = present + absent + excused;
  final unmarked = (scheduledCount - marked).clamp(0, scheduledCount);

  double? percent;
  final denom = present + absent;
  if (denom > 0) {
    percent = (present / denom) * 100;
  }

  final totalForThreshold = present + absent;
  final maxAbsent = totalForThreshold > 0
      ? ((totalForThreshold * (1 - thresholdPercent / 100)).floor())
      : scheduledCount > 0
          ? ((scheduledCount * (1 - thresholdPercent / 100)).floor())
          : 0;
  final safeMissesLeft = (maxAbsent - absent).clamp(0, 1 << 30);

  return AttendanceBucketStats(
    present: present,
    absent: absent,
    excused: excused,
    scheduled: scheduledCount,
    unmarked: unmarked,
    percent: percent,
    safeMissesLeft: safeMissesLeft,
  );
}

String? statusForSession(
  Map<String, AttendanceBucket> buckets,
  String courseCode,
  String sessionKind,
  String dateKey,
) {
  final bucket = buckets['$courseCode|$sessionKind'];
  return bucket?.byDate[dateKey];
}

AttendanceBucket getOrCreateBucket(
  Map<String, AttendanceBucket> buckets,
  String courseCode,
  String sessionKind,
) {
  final key = '$courseCode|$sessionKind';
  return buckets[key] ??
      AttendanceBucket(courseCode: courseCode, sessionKind: sessionKind);
}

String attendanceMarkPromptTitle(PlannerClass c) => 'Mark attendance · ${c.courseCode}';

String attendanceMarkPromptBody(PlannerClass c) {
  final kind = switch (c.kind) {
    'lecture' => 'Lecture',
    'tutorial' => 'Tutorial',
    'lab' => 'Lab',
    _ => c.kind,
  };
  return '$kind ended · tap to mark present/absent';
}
