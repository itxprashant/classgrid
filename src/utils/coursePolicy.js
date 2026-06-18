import { formatEventActor } from './calendarEvents';

export { formatEventActor };

export const POLICY_FIELDS = [
    { key: 'markingScheme', label: 'Marking scheme', placeholder: 'Midsem, endsem, quiz weights…' },
    { key: 'attendancePolicy', label: 'Attendance policy', placeholder: 'Minimum attendance, penalty rules…' },
    { key: 'auditWithdrawalPolicy', label: 'Audit / withdrawal policy', placeholder: 'Audit criteria, drop deadlines…' },
    { key: 'otherNotes', label: 'Other notes', placeholder: 'Textbooks, TA contacts, links…' },
];

export function emptyPolicyDraft(policy = null) {
    return {
        markingScheme: policy?.markingScheme || '',
        attendancePolicy: policy?.attendancePolicy || '',
        auditWithdrawalPolicy: policy?.auditWithdrawalPolicy || '',
        otherNotes: policy?.otherNotes || '',
        createdBy: policy?.createdBy || null,
        updatedBy: policy?.updatedBy || null,
    };
}

function trimField(value) {
    if (value == null) return '';
    return String(value).trim();
}

export function isPolicySubmittable(draft) {
    if (!draft || typeof draft !== 'object') return false;
    return POLICY_FIELDS.some(({ key }) => trimField(draft[key]).length > 0);
}

export function policyPayload(draft) {
    const out = {};
    for (const { key } of POLICY_FIELDS) {
        out[key] = trimField(draft[key]);
    }
    return out;
}

export function actorsMatch(a, b) {
    if (!a || !b) return false;
    return (
        a.at === b.at &&
        (a.kerberos || a.name) === (b.kerberos || b.name)
    );
}

export function policyHasContent(policy) {
    if (!policy) return false;
    return POLICY_FIELDS.some(({ key }) => trimField(policy[key]).length > 0);
}

export function formatPolicyActorLine(actor) {
    const info = formatEventActor(actor);
    if (!info) return null;
    return `${info.who} · ${info.when}`;
}
