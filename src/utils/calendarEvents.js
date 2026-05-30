// User-event storage for the My Calendar page.
//
// Persists a flat list of personal events (quizzes, deadlines, exams, ...)
// in localStorage under a single namespaced key. Isolated here so that
// swapping to a backend/DB later only touches this module.
//
// Event shape:
//   {
//     id: string,            // crypto.randomUUID()
//     date: 'YYYY-MM-DD',    // matches formatDateKey() from semesterSchedule.js
//     courseCode: string,    // e.g. COL106
//     title: string,
//     type: 'quiz' | 'deadline' | 'exam' | 'extra-class' | 'presentation' | 'others' | 'other',
//     note?: string,
//     schedule?: 'fullday' | 'at' | 'timed' | 'eod',  // defaults to fullday
//     time?: 'HHMM',                          // when schedule === 'at'
//     start?: 'HHMM', end?: 'HHMM',           // when schedule === 'timed'
//     createdBy?: { kerberos?, name, at: ISO8601 },
//     updatedBy?: { kerberos?, name, at: ISO8601 },
//   }

const STORAGE_KEY = 'cg_calendar_events';

export const EVENT_TYPES = ['quiz', 'deadline', 'exam', 'extra-class', 'presentation', 'others'];

const LEGACY_EVENT_TYPES = ['other'];

function isKnownEventType(type) {
    return EVENT_TYPES.includes(type) || LEGACY_EVENT_TYPES.includes(type);
}

function normalizeEventType(type) {
    if (EVENT_TYPES.includes(type)) return type;
    if (type === 'other') return 'others';
    return 'others';
}

export const EVENT_SCHEDULES = ['fullday', 'at', 'timed', 'eod'];

export const SCHEDULE_LABELS = {
    fullday: 'All day',
    at: 'At a time',
    timed: 'Timed',
    eod: 'EOD',
};

function genId() {
    if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
        return crypto.randomUUID();
    }
    return `evt_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function isValidEvent(e) {
    return (
        e &&
        typeof e === 'object' &&
        typeof e.id === 'string' &&
        typeof e.date === 'string' &&
        /^\d{4}-\d{2}-\d{2}$/.test(e.date) &&
        typeof e.title === 'string' &&
        typeof e.type === 'string' &&
        isKnownEventType(e.type) &&
        (typeof e.courseCode === 'undefined' || typeof e.courseCode === 'string') &&
        (typeof e.createdBy === 'undefined' || isActor(e.createdBy)) &&
        (typeof e.updatedBy === 'undefined' || isActor(e.updatedBy)) &&
        (typeof e.schedule === 'undefined' || EVENT_SCHEDULES.includes(e.schedule)) &&
        (typeof e.time === 'undefined' || typeof e.time === 'string') &&
        (typeof e.start === 'undefined' || typeof e.start === 'string') &&
        (typeof e.end === 'undefined' || typeof e.end === 'string')
    );
}

function normalizeCourseCode(code) {
    return String(code || '').trim().toUpperCase();
}

function normalizeHHMM(value) {
    if (value == null || value === '') return undefined;
    const s = String(value).trim();
    const colon = s.match(/^(\d{2}):(\d{2})$/);
    if (colon) return `${colon[1]}${colon[2]}`;
    if (/^\d{4}$/.test(s)) return s;
    return undefined;
}

export function hhmmToInput(hhmm) {
    if (!hhmm || hhmm.length !== 4) return '';
    return `${hhmm.slice(0, 2)}:${hhmm.slice(2)}`;
}

export function inputToHHMM(value) {
    return normalizeHHMM(value) || '';
}

export function formatEventSchedule(event) {
    const schedule = EVENT_SCHEDULES.includes(event.schedule) ? event.schedule : 'fullday';
    if (schedule === 'fullday') return '';
    if (schedule === 'eod') return 'EOD';
    const fmt = (hhmm) => {
        if (!hhmm || hhmm.length !== 4) return '';
        return `${hhmm.slice(0, 2)}:${hhmm.slice(2)}`;
    };
    if (schedule === 'at') return fmt(event.time);
    if (schedule === 'timed' && event.start && event.end) {
        return `${fmt(event.start)} – ${fmt(event.end)}`;
    }
    return '';
}

function scheduleFieldsFromPartial(partial) {
    const schedule = EVENT_SCHEDULES.includes(partial.schedule) ? partial.schedule : 'fullday';
    if (schedule === 'at') {
        return { schedule, time: normalizeHHMM(partial.time) };
    }
    if (schedule === 'timed') {
        return {
            schedule,
            start: normalizeHHMM(partial.start),
            end: normalizeHHMM(partial.end),
        };
    }
    if (schedule === 'eod') {
        return { schedule: 'eod' };
    }
    return { schedule: 'fullday' };
}

function mergeScheduleFields(target, partial) {
    const next = { ...target, schedule: 'fullday' };
    delete next.time;
    delete next.start;
    delete next.end;

    const schedule = EVENT_SCHEDULES.includes(partial.schedule) ? partial.schedule : 'fullday';
    next.schedule = schedule;

    if (schedule === 'at') {
        const time = normalizeHHMM(partial.time);
        if (time) next.time = time;
        return next;
    }
    if (schedule === 'timed') {
        const start = normalizeHHMM(partial.start);
        const end = normalizeHHMM(partial.end);
        if (start) next.start = start;
        if (end) next.end = end;
        return next;
    }
    if (schedule === 'eod') {
        return next;
    }
    return next;
}

export function isDraftScheduleValid(partial) {
    const schedule = EVENT_SCHEDULES.includes(partial.schedule) ? partial.schedule : 'fullday';
    if (schedule === 'at') return !!normalizeHHMM(partial.time);
    if (schedule === 'timed') {
        const start = normalizeHHMM(partial.start);
        const end = normalizeHHMM(partial.end);
        return !!start && !!end && start < end;
    }
    return true;
}

function isActor(a) {
    return a && typeof a === 'object' && typeof a.at === 'string';
}

function normalizeActor(actor) {
    if (!actor || typeof actor !== 'object') {
        return { name: 'Unknown', at: new Date().toISOString() };
    }
    const kerberos = actor.kerberos ? String(actor.kerberos).trim().toLowerCase() : undefined;
    const name = (actor.name || kerberos || 'Unknown').trim();
    return {
        kerberos,
        name,
        at: actor.at || new Date().toISOString(),
    };
}

/** Build a storable actor snapshot from the auth user (or guest). */
export function eventActorFromUser(user) {
    if (!user) {
        return { name: 'Guest', at: new Date().toISOString() };
    }
    return normalizeActor({
        kerberos: user.kerberos,
        name: user.name || 'Unknown',
        at: new Date().toISOString(),
    });
}

export function formatEventActor(actor) {
    if (!isActor(actor)) return null;
    const who = actor.name || actor.kerberos || 'Unknown';
    const when = new Date(actor.at).toLocaleString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
    });
    return { who, when };
}

export function loadEvents() {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return [];
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) return [];
        return parsed.filter(isValidEvent);
    } catch (e) {
        return [];
    }
}

export function saveEvents(events) {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(events));
    } catch (e) {
        // Quota or serialization failure — surface silently; persistence is
        // best-effort and never blocks the UI.
    }
}

export function addEvent(events, partial, actor) {
    const stamp = normalizeActor(actor);
    const next = {
        id: genId(),
        date: partial.date,
        courseCode: normalizeCourseCode(partial.courseCode),
        title: (partial.title || '').trim(),
        type: normalizeEventType(partial.type),
        note: partial.note ? String(partial.note).trim() : undefined,
        createdBy: stamp,
        updatedBy: stamp,
        ...scheduleFieldsFromPartial(partial),
    };
    return [...events, next];
}

export function updateEvent(events, id, patch, actor) {
    const stamp = normalizeActor(actor);
    return events.map((e) => {
        if (e.id !== id) return e;
        let merged = { ...e, ...patch, updatedBy: stamp };
        if (typeof merged.courseCode === 'string') {
            merged.courseCode = normalizeCourseCode(merged.courseCode);
        }
        if (typeof merged.title === 'string') merged.title = merged.title.trim();
        if (!isKnownEventType(merged.type)) merged.type = 'others';
        else merged.type = normalizeEventType(merged.type);
        if (typeof merged.note === 'string') {
            const trimmed = merged.note.trim();
            merged.note = trimmed.length ? trimmed : undefined;
        }
        if (patch.schedule !== undefined || patch.time !== undefined ||
            patch.start !== undefined || patch.end !== undefined) {
            merged = mergeScheduleFields(merged, patch);
        }
        return merged;
    });
}

export function deleteEvent(events, id) {
    return events.filter((e) => e.id !== id);
}
