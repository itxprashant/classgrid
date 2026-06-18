import 'package:flutter/widgets.dart';

import '../models/academic_day.dart';
import 'tokens.dart';

/// Canonical tint/edge/ink triples for academic-day markers across calendar,
/// week grid, and academic calendar sheet. Holiday = success (positive day off);
/// exam/deadline periods = danger; swaps = accent; breaks = tutorial.
class AcademicDayStyle {
  const AcademicDayStyle({
    required this.tint,
    required this.edge,
    required this.ink,
  });

  final Color tint;
  final Color edge;
  final Color ink;
}

class AcademicDayColors {
  AcademicDayColors._();

  static AcademicDayStyle forType(AcademicType type, {String? periodName}) {
    switch (type) {
      case AcademicType.holiday:
        return AcademicDayStyle(
          tint: T.successTint,
          edge: T.successEdge,
          ink: T.successInk,
        );
      case AcademicType.swapped:
        return AcademicDayStyle(
          tint: T.accentTint,
          edge: T.accentEdge,
          ink: T.accentInk,
        );
      case AcademicType.breakPeriod:
        if (periodName != null &&
            (periodName.toLowerCase().contains('exam') ||
                periodName.toLowerCase().contains('end sem'))) {
          return AcademicDayStyle(
            tint: T.dangerTint,
            edge: T.dangerEdge,
            ink: T.danger,
          );
        }
        return AcademicDayStyle(
          tint: T.tutorialTint,
          edge: T.tutorialEdge,
          ink: T.tutorialInk,
        );
      case AcademicType.weekend:
      case AcademicType.beforeTerm:
      case AcademicType.afterTerm:
        return AcademicDayStyle(
          tint: T.paper2,
          edge: T.line,
          ink: T.ink3,
        );
      case AcademicType.normal:
        return AcademicDayStyle(
          tint: T.surface,
          edge: T.line,
          ink: T.ink2,
        );
    }
  }

  static AcademicDayStyle forDay(AcademicDay day) =>
      forType(day.type, periodName: day.name);

  /// Legend dot color for a category label.
  static Color legendDot(String label) {
    switch (label.toLowerCase()) {
      case 'holiday':
        return T.success;
      case 'course':
        return T.accent;
      case 'personal':
        return T.labEdge;
      case 'class':
        return T.lectureInk;
      case 'exam':
        return T.danger;
      default:
        return T.ink3;
    }
  }
}
