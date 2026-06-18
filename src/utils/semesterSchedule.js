// Academic calendar helpers — config is loaded from GET /api/semester/schedule
// via SemesterDataProvider (setActiveSemesterSchedule).

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

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

function dayValue(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
}

/**
 * Build schedule helpers from API payload shape:
 * { semester, holidays, scheduleExceptions, noClassPeriods }
 */
export function createSemesterSchedule(config) {
    const SEMESTER = config?.semester || {
        code: '',
        label: '',
        classesStart: '',
        lastTeachingDay: '',
    };
    const HOLIDAYS = config?.holidays || {};
    const SCHEDULE_EXCEPTIONS = config?.scheduleExceptions || {};
    const NO_CLASS_PERIODS = config?.noClassPeriods || [];

    function findNoClassPeriod(date) {
        const v = dayValue(date);
        return (
            NO_CLASS_PERIODS.find(
                (p) => v >= dayValue(parseDateKey(p.start)) && v <= dayValue(parseDateKey(p.end))
            ) || null
        );
    }

    function getAcademicDay(date = new Date()) {
        const key = formatDateKey(date);
        const weekday = WEEKDAYS[date.getDay()];
        const base = { weekday, name: null };

        if (HOLIDAYS[key]) {
            return {
                ...base,
                type: 'holiday',
                name: HOLIDAYS[key],
                effectiveDay: null,
                effectiveDayCode: null,
                hasClasses: false,
            };
        }

        if (SCHEDULE_EXCEPTIONS[key]) {
            const effectiveDay = SCHEDULE_EXCEPTIONS[key];
            return {
                ...base,
                type: 'swapped',
                effectiveDay,
                effectiveDayCode: DAY_NAME_TO_CODE[effectiveDay] || null,
                hasClasses: true,
            };
        }

        const v = dayValue(date);
        if (SEMESTER.classesStart && v < dayValue(parseDateKey(SEMESTER.classesStart))) {
            return {
                ...base,
                type: 'before-term',
                effectiveDay: null,
                effectiveDayCode: null,
                hasClasses: false,
            };
        }
        if (SEMESTER.lastTeachingDay && v > dayValue(parseDateKey(SEMESTER.lastTeachingDay))) {
            return {
                ...base,
                type: 'after-term',
                effectiveDay: null,
                effectiveDayCode: null,
                hasClasses: false,
            };
        }

        const period = findNoClassPeriod(date);
        if (period) {
            return {
                ...base,
                type: 'break',
                name: period.name,
                effectiveDay: null,
                effectiveDayCode: null,
                hasClasses: false,
            };
        }

        const dow = date.getDay();
        if (dow === 0 || dow === 6) {
            return {
                ...base,
                type: 'weekend',
                effectiveDay: null,
                effectiveDayCode: null,
                hasClasses: false,
            };
        }

        return {
            ...base,
            type: 'normal',
            effectiveDay: weekday,
            effectiveDayCode: DAY_NAME_TO_CODE[weekday] || null,
            hasClasses: true,
        };
    }

    function describeAcademicDay(info) {
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

    return {
        SEMESTER,
        HOLIDAYS,
        SCHEDULE_EXCEPTIONS,
        NO_CLASS_PERIODS,
        getAcademicDay,
        describeAcademicDay,
    };
}

let activeSchedule = null;

export function setActiveSemesterSchedule(schedule) {
    activeSchedule = schedule;
}

export function getActiveSemesterSchedule() {
    return activeSchedule;
}

function requireSchedule() {
    if (!activeSchedule) {
        throw new Error('Semester schedule not loaded');
    }
    return activeSchedule;
}

export function getAcademicDay(date) {
    return requireSchedule().getAcademicDay(date);
}

export function describeAcademicDay(info) {
    return requireSchedule().describeAcademicDay(info);
}

export function getSemesterMeta() {
    const s = requireSchedule();
    return {
        SEMESTER: s.SEMESTER,
        HOLIDAYS: s.HOLIDAYS,
        SCHEDULE_EXCEPTIONS: s.SCHEDULE_EXCEPTIONS,
        NO_CLASS_PERIODS: s.NO_CLASS_PERIODS,
    };
}
