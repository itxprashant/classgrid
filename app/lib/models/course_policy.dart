import 'actor.dart';
import '../core/course_policy.dart';

class CoursePolicy {
  const CoursePolicy({
    required this.markingScheme,
    required this.attendancePolicy,
    required this.auditWithdrawalPolicy,
    required this.otherNotes,
    this.createdBy,
    this.updatedBy,
  });

  final String markingScheme;
  final String attendancePolicy;
  final String auditWithdrawalPolicy;
  final String otherNotes;
  final Actor? createdBy;
  final Actor? updatedBy;

  factory CoursePolicy.fromJson(Map<String, dynamic> json) => CoursePolicy(
        markingScheme: (json['markingScheme'] ?? '').toString(),
        attendancePolicy: (json['attendancePolicy'] ?? '').toString(),
        auditWithdrawalPolicy: (json['auditWithdrawalPolicy'] ?? '').toString(),
        otherNotes: (json['otherNotes'] ?? '').toString(),
        createdBy: json['createdBy'] is Map
            ? Actor.fromJson(Map<String, dynamic>.from(json['createdBy']))
            : null,
        updatedBy: json['updatedBy'] is Map
            ? Actor.fromJson(Map<String, dynamic>.from(json['updatedBy']))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'markingScheme': markingScheme,
        'attendancePolicy': attendancePolicy,
        'auditWithdrawalPolicy': auditWithdrawalPolicy,
        'otherNotes': otherNotes,
        if (createdBy != null) 'createdBy': createdBy!.toJson(),
        if (updatedBy != null) 'updatedBy': updatedBy!.toJson(),
      };

  bool get hasContent =>
      markingScheme.trim().isNotEmpty ||
      attendancePolicy.trim().isNotEmpty ||
      auditWithdrawalPolicy.trim().isNotEmpty ||
      otherNotes.trim().isNotEmpty;
}

class CoursePolicyDraft implements CoursePolicyDraftLike {
  CoursePolicyDraft({
    this.markingScheme = '',
    this.attendancePolicy = '',
    this.auditWithdrawalPolicy = '',
    this.otherNotes = '',
    this.createdBy,
    this.updatedBy,
  });

  @override
  String markingScheme;
  @override
  String attendancePolicy;
  @override
  String auditWithdrawalPolicy;
  @override
  String otherNotes;
  Actor? createdBy;
  Actor? updatedBy;

  factory CoursePolicyDraft.fromPolicy(CoursePolicy? policy) => CoursePolicyDraft(
        markingScheme: policy?.markingScheme ?? '',
        attendancePolicy: policy?.attendancePolicy ?? '',
        auditWithdrawalPolicy: policy?.auditWithdrawalPolicy ?? '',
        otherNotes: policy?.otherNotes ?? '',
        createdBy: policy?.createdBy,
        updatedBy: policy?.updatedBy,
      );
}
