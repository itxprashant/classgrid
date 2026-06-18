import { reportContextLabel } from '../../utils/feedback';

export function snapshotHeading(snapshot, targetKind) {
    return reportContextLabel(snapshot, targetKind || '');
}

export function snapshotFields(snapshot, targetKind) {
    if (!snapshot || typeof snapshot !== 'object') {
        return [{ label: 'Target', value: targetKind || '—' }];
    }

    const kind = snapshot.kind || targetKind;
    const rows = [];

    if (kind === 'course_event') {
        if (snapshot.courseCode) rows.push({ label: 'Course', value: snapshot.courseCode });
        if (snapshot.title) rows.push({ label: 'Event', value: snapshot.title });
        if (snapshot.date) rows.push({ label: 'Date', value: snapshot.date });
        if (snapshot.type) rows.push({ label: 'Type', value: snapshot.type });
        if (snapshot.schedule) rows.push({ label: 'Schedule', value: snapshot.schedule });
    } else if (kind === 'course_policy') {
        if (snapshot.courseCode) rows.push({ label: 'Course', value: snapshot.courseCode });
        if (snapshot.semesterCode) rows.push({ label: 'Semester', value: snapshot.semesterCode });
    } else if (kind === 'occupied_room') {
        if (snapshot.room) rows.push({ label: 'Room', value: snapshot.room });
        if (snapshot.date) rows.push({ label: 'Date', value: snapshot.date });
        if (snapshot.start && snapshot.end) {
            rows.push({ label: 'Time', value: `${snapshot.start}–${snapshot.end}` });
        }
        if (snapshot.note) rows.push({ label: 'Note', value: snapshot.note });
    } else if (kind === 'other') {
        if (snapshot.label) rows.push({ label: 'Label', value: snapshot.label });
        if (snapshot.pageContext) rows.push({ label: 'Page', value: snapshot.pageContext });
    }

    if (rows.length === 0) {
        rows.push({ label: 'Kind', value: kind || '—' });
    }

    return rows;
}
