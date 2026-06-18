import '../models/course.dart';

final _semesterCodeRe = RegExp(r'^\d{4}$');

/// Semester code for deep-linking from catalog or room schedule rows.
String? courseLinkSemester(Course course, String? activeSemesterCode) {
  if (!course.offeredThisSemester && _semesterCodeRe.hasMatch(course.semesterCode ?? '')) {
    return course.semesterCode;
  }
  if (_semesterCodeRe.hasMatch(activeSemesterCode ?? '')) {
    return activeSemesterCode;
  }
  if (_semesterCodeRe.hasMatch(course.semesterCode ?? '')) {
    return course.semesterCode;
  }
  return null;
}

bool isValidSemesterCode(String? code) => code != null && _semesterCodeRe.hasMatch(code);
