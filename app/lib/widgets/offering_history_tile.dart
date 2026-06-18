import 'package:flutter/material.dart';

import '../core/timing.dart';
import '../models/course_offering.dart';
import '../models/instructor_ref.dart';
import '../theme/app_palette_scope.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'instructor_links.dart';

/// Human-readable timing summary for a catalog offering row.
String offeringTimingSummary(CourseOffering offering) {
  if ((offering.lectureTimingStr ?? '').trim().isNotEmpty) {
    return offering.lectureTimingStr!.trim();
  }
  final parts = <String>[];
  for (final raw in [
    offering.lectureTiming,
    offering.tutorialTiming,
    offering.labTiming,
  ]) {
    if (raw == null || raw.isEmpty) continue;
    for (final s in parseTimingStr(raw)) {
      parts.add('${s.day} ${s.start.substring(0, 2)}:${s.start.substring(2)}');
    }
  }
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// Course detail lists offerings by semester; prof detail lists by course.
enum OfferingHistoryVariant {
  bySemester,
  byCourse,
}

class OfferingHistoryTile extends StatelessWidget {
  const OfferingHistoryTile({
    super.key,
    required this.offering,
    this.variant = OfferingHistoryVariant.bySemester,
    this.highlight = false,
    this.onTap,
    this.onInstructorTap,
  });

  final CourseOffering offering;
  final OfferingHistoryVariant variant;
  final bool highlight;
  final VoidCallback? onTap;
  final void Function(String email, String name)? onInstructorTap;

  @override
  Widget build(BuildContext context) {
    AppPaletteScope.watch(context);
    final timings = offeringTimingSummary(offering);
    final showInstructors = variant == OfferingHistoryVariant.bySemester;
    final instructors = offering.instructors.isNotEmpty
        ? offering.instructors
        : [
            if (offering.instructor.isNotEmpty)
              InstructorRef(name: offering.instructor, email: offering.instructorEmail),
          ];

    return Material(
      color: highlight ? T.accentTint : T.surface,
      borderRadius: BorderRadius.circular(T.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.r),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: highlight ? T.accentEdge : T.line),
            borderRadius: BorderRadius.circular(T.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: variant == OfferingHistoryVariant.byCourse
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offering.courseCode,
                                style: AppText.mono(size: T.fs14, weight: FontWeight.w600),
                              ),
                              if (offering.courseName.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  offering.courseName,
                                  style: AppText.sans(size: T.fs13, color: T.ink2),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            offering.label,
                            style: AppText.sans(size: T.fs14, weight: FontWeight.w600),
                          ),
                  ),
                  if (offering.isActive)
                    Pill('Current', tint: T.accentTint, edge: T.accentEdge, ink: T.accentInk),
                  if (onTap != null) ...[
                    const SizedBox(width: T.space8),
                    Icon(Icons.chevron_right, size: 20, color: T.ink3),
                  ],
                ],
              ),
              if (showInstructors && instructors.isNotEmpty) ...[
                const SizedBox(height: 6),
                InstructorLinks(
                  instructors: instructors,
                  onTap: onInstructorTap,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: T.space8,
                runSpacing: T.space8,
                children: [
                  if (variant == OfferingHistoryVariant.byCourse && offering.label.isNotEmpty)
                    Pill(offering.label, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                  if ((offering.slotName ?? '').isNotEmpty && offering.slotName != 'X')
                    Pill('Slot ${offering.slotName}', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                  if (offering.credits != null)
                    Pill('${offering.credits!.toStringAsFixed(1)} cr', tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                  if ((offering.lectureHall ?? '').isNotEmpty)
                    Pill(offering.lectureHall!, tint: T.surfaceSunk, edge: T.line, ink: T.ink2),
                ],
              ),
              if (timings != '—') ...[
                const SizedBox(height: 8),
                Text(timings, style: AppText.mono(size: T.fs12, color: T.ink3)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
