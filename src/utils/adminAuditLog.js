export const AUDIT_ACTIONS = [
    {
        group: 'Shared calendar',
        actions: [
            { id: 'course_event.created', label: 'Course event created' },
            { id: 'course_event.updated', label: 'Course event updated' },
            { id: 'course_event.deleted', label: 'Course event deleted' },
        ],
    },
    {
        group: 'Personal calendar',
        actions: [
            { id: 'personal_event.created', label: 'Personal event created' },
            { id: 'personal_event.updated', label: 'Personal event updated' },
            { id: 'personal_event.deleted', label: 'Personal event deleted' },
        ],
    },
    {
        group: 'Rooms',
        actions: [
            { id: 'occupied_room.marked', label: 'Room marked occupied' },
            { id: 'occupied_room.unmarked', label: 'Room marking removed' },
        ],
    },
    {
        group: 'Course policy',
        actions: [
            { id: 'course_policy.upserted', label: 'Course policy saved' },
        ],
    },
    {
        group: 'Feedback & reports',
        actions: [
            { id: 'feedback.submitted', label: 'Feedback submitted' },
            { id: 'content_report.filed', label: 'Content report filed' },
        ],
    },
    {
        group: 'Admin',
        actions: [
            { id: 'admin.report.reviewed', label: 'Report reviewed' },
            { id: 'admin.course_event.deleted', label: 'Admin deleted course event' },
            { id: 'admin.occupied_room.deleted', label: 'Admin deleted room marking' },
            { id: 'admin.course_policy.deleted', label: 'Admin deleted course policy' },
        ],
    },
    {
        group: 'Auth',
        actions: [
            { id: 'auth.login', label: 'Login' },
            { id: 'auth.logout', label: 'Logout' },
        ],
    },
];

export const AUDIT_TARGET_KINDS = [
    { id: 'course_event', label: 'Course event' },
    { id: 'personal_event', label: 'Personal event' },
    { id: 'occupied_room', label: 'Occupied room' },
    { id: 'course_policy', label: 'Course policy' },
    { id: 'app_feedback', label: 'Feedback' },
    { id: 'content_report', label: 'Content report' },
    { id: 'session', label: 'Session' },
];

const ACTION_LABELS = Object.fromEntries(
    AUDIT_ACTIONS.flatMap((g) => g.actions.map((a) => [a.id, a.label])),
);

const TARGET_KIND_LABELS = Object.fromEntries(
    AUDIT_TARGET_KINDS.map((k) => [k.id, k.label]),
);

export function formatAuditAction(id) {
    return ACTION_LABELS[id] || id || '—';
}

export function formatTargetKind(id) {
    return TARGET_KIND_LABELS[id] || id || '—';
}

function joinParts(parts) {
    return parts.filter(Boolean).join(' · ');
}

export function auditSummary(entry) {
    const meta = entry.metadata || {};

    if (meta.fromStatus && meta.toStatus) {
        return `${meta.fromStatus} → ${meta.toStatus}`;
    }

    if (meta.courseCode && meta.title) {
        return joinParts([meta.courseCode, meta.title]);
    }
    if (meta.courseCode) {
        return meta.courseCode;
    }
    if (meta.title) {
        return meta.title;
    }

    if (meta.room) {
        const date = meta.occupancy_date || meta.date;
        return joinParts([meta.room, date]);
    }

    if (meta.messagePreview) {
        return meta.messagePreview;
    }

    if (meta.reason && meta.targetKind) {
        return joinParts([meta.targetKind, meta.reason]);
    }

    if (meta.semesterCode && meta.courseCode) {
        return `${meta.semesterCode}:${meta.courseCode}`;
    }

    if (entry.targetId && entry.targetId.length <= 48) {
        return entry.targetId;
    }

    return '—';
}

function formatMetaValue(key, value) {
    if (value == null || value === '') return null;
    if (typeof value === 'boolean') return value ? 'yes' : 'no';
    if (typeof value === 'object') return JSON.stringify(value);
    return String(value);
}

const META_LABELS = {
    id: 'Record ID',
    courseCode: 'Course',
    title: 'Title',
    type: 'Type',
    date: 'Date',
    room: 'Room',
    occupancy_date: 'Date',
    start: 'Start',
    end: 'End',
    semesterCode: 'Semester',
    category: 'Category',
    client: 'Client',
    messagePreview: 'Message preview',
    targetKind: 'Report target kind',
    targetId: 'Report target ID',
    reason: 'Reason',
    fromStatus: 'From status',
    toStatus: 'To status',
    created: 'New record',
    hasMarkingScheme: 'Marking scheme',
    hasAttendancePolicy: 'Attendance policy',
    hasAuditWithdrawalPolicy: 'Audit / withdrawal',
    hasOtherNotes: 'Other notes',
    app: 'Mobile app login',
    desktop: 'Desktop app login',
    requestId: 'Request ID',
};

export function auditDetailRows(entry) {
    const rows = [
        { label: 'Event ID', value: entry.id },
        { label: 'When', value: entry.occurredAt },
        { label: 'Action', value: formatAuditAction(entry.action) },
        { label: 'Actor', value: entry.actorKerberos || entry.actorName || '—' },
        { label: 'Target kind', value: formatTargetKind(entry.targetKind) },
        { label: 'Target ID', value: entry.targetId || '—' },
        { label: 'Client', value: entry.client || '—' },
        { label: 'IP', value: entry.ip || '—' },
    ];

    const meta = entry.metadata || {};
    Object.keys(meta).sort().forEach((key) => {
        const value = formatMetaValue(key, meta[key]);
        if (value == null) return;
        rows.push({
            label: META_LABELS[key] || key,
            value,
        });
    });

    return rows;
}

export function auditSiteLinks(entry) {
    const meta = entry.metadata || {};
    const links = [];

    const courseCode = meta.courseCode
        || (entry.targetKind === 'course_policy' && entry.targetId.includes(':')
            ? entry.targetId.split(':').slice(1).join(':')
            : null);

    if (courseCode) {
        links.push({ to: `/course/${encodeURIComponent(courseCode)}`, label: `Course ${courseCode}` });
    }

    if (entry.targetKind === 'course_event' || meta.courseCode) {
        links.push({ to: '/calendar', label: 'Calendar' });
    }

    if (entry.targetKind === 'occupied_room' || meta.room) {
        links.push({ to: '/empty-halls', label: 'Empty halls' });
    }

    return links;
}
