import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the CGPA calculator (device-only; no API).
class CgpaStore {
  CgpaStore(this._prefs);

  final SharedPreferences _prefs;

  static const _priorCgpaKey = 'cg_prior_cgpa';
  static const _priorCreditsKey = 'cg_prior_credits';
  static const _gradesKey = 'cg_course_grades';

  Timer? _saveTimer;

  double? loadPriorCgpa() {
    final v = _prefs.getString(_priorCgpaKey);
    if (v == null) return null;
    return double.tryParse(v);
  }

  double? loadPriorCredits() {
    final v = _prefs.getString(_priorCreditsKey);
    if (v == null) return null;
    return double.tryParse(v);
  }

  /// Saved grade per course code (`10`–`4`, `W`, `A`, `F`).
  Map<String, String> loadGradeMap() {
    try {
      final raw = _prefs.getString(_gradesKey);
      if (raw == null) return {};
      final parsed = jsonDecode(raw);
      if (parsed is! Map) return {};
      final out = <String, String>{};
      for (final e in parsed.entries) {
        final code = e.key.toString().trim();
        final grade = e.value?.toString().trim().toUpperCase();
        if (code.isEmpty || grade == null || grade.isEmpty) continue;
        out[code] = grade;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  void scheduleSave({
    double? priorCgpa,
    double? priorCredits,
    required Map<String, String> gradesByCode,
  }) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persist(
        priorCgpa: priorCgpa,
        priorCredits: priorCredits,
        gradesByCode: gradesByCode,
      ));
    });
  }

  Future<void> _persist({
    double? priorCgpa,
    double? priorCredits,
    required Map<String, String> gradesByCode,
  }) async {
    if (priorCgpa != null && !priorCgpa.isNaN) {
      await _prefs.setString(_priorCgpaKey, priorCgpa.toString());
    } else {
      await _prefs.remove(_priorCgpaKey);
    }
    if (priorCredits != null && !priorCredits.isNaN) {
      await _prefs.setString(_priorCreditsKey, priorCredits.toString());
    } else {
      await _prefs.remove(_priorCreditsKey);
    }
    await _prefs.setString(_gradesKey, jsonEncode(gradesByCode));
  }

  void dispose() {
    _saveTimer?.cancel();
  }
}
