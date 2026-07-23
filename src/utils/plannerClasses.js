// Reads the weekly planner from localStorage and resolves which sessions
// run on a given calendar date (respecting holidays, swaps and breaks via
// getAcademicDay).

import { formatDateKey, getAcademicDay } from './semesterSchedule';

const SESSION_KINDS = ['lecture', 'tutorial', 'lab'];

const KIND_LABELS = {
    lecture: 'L',
    tutorial: 'T',
    lab: 'Lab',
};

export function loadPlannerState() {
    try {
        const coursesRaw = localStorage.getItem('selectedCourses');
        const timetableRaw = localStorage.getItem('timetableData');
        const courses = coursesRaw ? JSON.parse(coursesRaw) : [];
        const timetableData = timetableRaw ? JSON.parse(timetableRaw) : {};
        if (!Array.isArray(courses)) {
            return { courses: [], timetableData: {} };
        }
        return { courses, timetableData };
    } catch (e) {
        return { courses: [], timetableData: {} };
    }
}

export function formatSessionTime(hhmm) {
    if (!hhmm || hhmm.length !== 4) return '';
    return `${hhmm.slice(0, 2)}:${hhmm.slice(2)}`;
}

/** Sessions on a calendar date from the planner, sorted by start time. */
export function getClassesForDate(date, courses, timetableData) {
    const academic = getAcademicDay(date);
    if (!academic.hasClasses || !academic.effectiveDay) return [];

    const sessions = [];
    for (const course of courses) {
        if (!course || !course.courseCode) continue;
        const data = timetableData[course.courseCode];
        if (!data) continue;

        for (const kind of SESSION_KINDS) {
            const slots = data[kind];
            if (!Array.isArray(slots)) continue;
            for (const slot of slots) {
                if (!slot || slot.day !== academic.effectiveDay) continue;
                // Match Plan timetable: per-slot location, else course lectureHall for lectures.
                const location =
                    (slot.location && String(slot.location).trim())
                    || (kind === 'lecture' && course.lectureHall
                        ? String(course.lectureHall).trim()
                        : '')
                    || '';
                sessions.push({
                    id: `${course.courseCode}-${kind}-${slot.start}-${slot.end}`,
                    courseCode: course.courseCode,
                    kind,
                    kindLabel: KIND_LABELS[kind],
                    start: slot.start,
                    end: slot.end,
                    timeLabel: formatSessionTime(slot.start),
                    location,
                });
            }
        }
    }

    sessions.sort((a, b) => {
        if (a.start !== b.start) return a.start < b.start ? -1 : 1;
        return a.courseCode.localeCompare(b.courseCode);
    });
    return sessions;
}

/** Map YYYY-MM-DD → session[] for every date in `dates` (Date objects). */
export function buildClassesByDate(dates, courses, timetableData) {
    const map = new Map();
    for (const date of dates) {
        const key = formatDateKey(date);
        const sessions = getClassesForDate(date, courses, timetableData);
        if (sessions.length > 0) map.set(key, sessions);
    }
    return map;
}
