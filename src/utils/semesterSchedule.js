// IIT Delhi academic calendar — Semester 1, 2026-2027 (Fall 2026).
// Source: Institute academic calendar, revised 23-10-2025.
//
// Update this file each semester. Everything downstream (free-room lookup,
// timetable day resolution, ICS export) reads the maps and `getAcademicDay`
// from here so there is a single source of truth for holidays and the
// working-day swaps the institute announces.

export const SEMESTER = {
    code: '2601',
    label: 'Semester 1, 2026–2027',
    classesStart: '2026-07-23', // Commencement of classes (Thursday)
    lastTeachingDay: '2026-11-17', // Last teaching day (Tuesday)
};

// Days the institute runs a *different* day's timetable.
// Format: "YYYY-MM-DD": "<weekday whose timetable is followed>"
export const SCHEDULE_EXCEPTIONS = {
    '2026-09-03': 'Friday', // Thursday 03-09-2026 works as per Friday timetable
    '2026-10-10': 'Wednesday', // Saturday 10-10-2026 works as per Wednesday timetable
};

// Institute holidays within the teaching period — no regular classes.
export const HOLIDAYS = {
    '2026-08-15': 'Independence Day',
    '2026-08-26': 'Milad-un-Nabi',
    '2026-09-04': 'Janmashtami',
    '2026-10-02': "Gandhi's Birthday",
    '2026-10-20': 'Dussehra',
    '2026-11-08': 'Diwali',
    '2026-11-09': 'Govardhan Puja',
    '2026-11-24': "Guru Nanak's Birthday",
    '2026-12-25': 'Christmas',
};

// Inclusive date ranges with no regular timetabled classes (breaks, exam
// weeks where the normal weekly timetable does not run).
export const NO_CLASS_PERIODS = [
    { name: 'Mid-semester examinations', start: '2026-09-12', end: '2026-09-18' },
    { name: 'Semester break', start: '2026-09-28', end: '2026-10-04' },
    { name: 'End-semester examinations', start: '2026-11-18', end: '2026-11-26' },
];

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

// Timetable day codes used across the app: 1=Mon … 5=Fri (see AGENTS.md).
export const DAY_NAME_TO_CODE = {
    Monday: 1,
    Tuesday: 2,
    Wednesday: 3,
    Thursday: 4,
    Friday: 5,
};

export function formatDateKey(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

export function parseDateKey(key) {
    const [y, m, d] = key.split('-').map(Number);
    return new Date(y, m - 1, d);
}

// Midnight-normalised millisecond value, so range checks ignore the time part.
function dayValue(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

function findNoClassPeriod(date) {
    const v = dayValue(date);
    return (
        NO_CLASS_PERIODS.find(
            (p) => v >= dayValue(parseDateKey(p.start)) && v <= dayValue(parseDateKey(p.end))
        ) || null
    );
}

/**
 * Resolve the academic meaning of a calendar date.
 *
 * Returns an object describing what timetable (if any) runs that day:
 *   - type:        'holiday' | 'swapped' | 'break' | 'weekend' | 'before-term'
 *                  | 'after-term' | 'normal'
 *   - weekday:     real calendar weekday name (e.g. "Saturday")
 *   - effectiveDay: weekday whose timetable runs, or null when no classes
 *   - effectiveDayCode: 1–5 for Mon–Fri, or null when no classes
 *   - hasClasses:  whether the weekly timetable runs at all
 *   - name:        holiday/break label when relevant
 */
export function getAcademicDay(date = new Date()) {
    const key = formatDateKey(date);
    const weekday = WEEKDAYS[date.getDay()];

    const base = { weekday, name: null };

    if (HOLIDAYS[key]) {
        return { ...base, type: 'holiday', name: HOLIDAYS[key], effectiveDay: null, effectiveDayCode: null, hasClasses: false };
    }

    if (SCHEDULE_EXCEPTIONS[key]) {
        const effectiveDay = SCHEDULE_EXCEPTIONS[key];
        return { ...base, type: 'swapped', effectiveDay, effectiveDayCode: DAY_NAME_TO_CODE[effectiveDay] || null, hasClasses: true };
    }

    const v = dayValue(date);
    if (v < dayValue(parseDateKey(SEMESTER.classesStart))) {
        return { ...base, type: 'before-term', effectiveDay: null, effectiveDayCode: null, hasClasses: false };
    }
    if (v > dayValue(parseDateKey(SEMESTER.lastTeachingDay))) {
        return { ...base, type: 'after-term', effectiveDay: null, effectiveDayCode: null, hasClasses: false };
    }

    const period = findNoClassPeriod(date);
    if (period) {
        return { ...base, type: 'break', name: period.name, effectiveDay: null, effectiveDayCode: null, hasClasses: false };
    }

    const dow = date.getDay();
    if (dow === 0 || dow === 6) {
        return { ...base, type: 'weekend', effectiveDay: null, effectiveDayCode: null, hasClasses: false };
    }

    return { ...base, type: 'normal', effectiveDay: weekday, effectiveDayCode: DAY_NAME_TO_CODE[weekday] || null, hasClasses: true };
}

// Short human-readable summary for UI banners.
export function describeAcademicDay(info) {
    switch (info.type) {
        case 'holiday':
            return `Holiday — ${info.name}. No classes scheduled.`;
        case 'swapped':
            return `${info.weekday} running as per ${info.effectiveDay} timetable.`;
        case 'break':
            return `${info.name} — no regular classes.`;
        case 'weekend':
            return 'Weekend — no classes scheduled.';
        case 'before-term':
            return `Term starts ${SEMESTER.classesStart}. No classes yet.`;
        case 'after-term':
            return `Teaching ended ${SEMESTER.lastTeachingDay}. No regular classes.`;
        default:
            return `Following ${info.effectiveDay} timetable.`;
    }
}
