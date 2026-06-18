// Validation and payload helpers for course policy forms.
// Mirrors src/utils/coursePolicy.js.

class PolicyFieldDef {
  const PolicyFieldDef(this.key, this.label, this.placeholder);

  final String key;
  final String label;
  final String placeholder;
}

const kPolicyFields = [
  PolicyFieldDef('markingScheme', 'Marking scheme', 'Midsem, endsem, quiz weights…'),
  PolicyFieldDef('attendancePolicy', 'Attendance policy', 'Minimum attendance, penalty rules…'),
  PolicyFieldDef(
    'auditWithdrawalPolicy',
    'Audit / withdrawal policy',
    'Audit criteria, drop deadlines…',
  ),
  PolicyFieldDef('otherNotes', 'Other notes', 'Textbooks, TA contacts, links…'),
];

String _trim(String? value) => (value ?? '').trim();

bool isPolicySubmittable(CoursePolicyDraftLike draft) {
  return kPolicyFields.any((f) => _trim(draftField(draft, f.key)).isNotEmpty);
}

String draftField(CoursePolicyDraftLike draft, String key) {
  switch (key) {
    case 'markingScheme':
      return draft.markingScheme;
    case 'attendancePolicy':
      return draft.attendancePolicy;
    case 'auditWithdrawalPolicy':
      return draft.auditWithdrawalPolicy;
    case 'otherNotes':
      return draft.otherNotes;
    default:
      return '';
  }
}

void setDraftField(CoursePolicyDraftLike draft, String key, String value) {
  if (key == 'markingScheme') {
    draft.markingScheme = value;
  } else if (key == 'attendancePolicy') {
    draft.attendancePolicy = value;
  } else if (key == 'auditWithdrawalPolicy') {
    draft.auditWithdrawalPolicy = value;
  } else if (key == 'otherNotes') {
    draft.otherNotes = value;
  }
}

Map<String, dynamic> policyPayload(CoursePolicyDraftLike draft) => {
      'markingScheme': _trim(draft.markingScheme),
      'attendancePolicy': _trim(draft.attendancePolicy),
      'auditWithdrawalPolicy': _trim(draft.auditWithdrawalPolicy),
      'otherNotes': _trim(draft.otherNotes),
    };

abstract class CoursePolicyDraftLike {
  String get markingScheme;
  set markingScheme(String value);
  String get attendancePolicy;
  set attendancePolicy(String value);
  String get auditWithdrawalPolicy;
  set auditWithdrawalPolicy(String value);
  String get otherNotes;
  set otherNotes(String value);
}
