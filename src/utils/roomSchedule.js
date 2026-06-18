const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const DAY_ORDER = {
    Monday: 1,
    Tuesday: 2,
    Wednesday: 3,
    Thursday: 4,
    Friday: 5,
};

export function normalizeRoomName(name) {
    const s = String(name || '').trim().replace(/\s+/g, ' ');
    if (!s) return '';
    const m = s.match(/^LH\s*(.+)$/i);
    if (m) return `LH ${m[1].trim()}`;
    return s;
}

export function roomToSlug(room) {
    return encodeURIComponent(normalizeRoomName(room));
}

export function slugToRoom(slug) {
    try {
        return normalizeRoomName(decodeURIComponent(slug || ''));
    } catch {
        return normalizeRoomName(slug || '');
    }
}

export function parseTimingStr(timingStr) {
    if (!timingStr) return [];
    return timingStr.split(',').map((t) => {
        const dayCode = t[0];
        const start = t.slice(1, 5);
        const end = t.slice(5, 9);
        const days = { 1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday' };
        return { day: days[dayCode], start, end };
    }).filter((s) => s.day && s.start && s.end);
}

export function splitRoomNames(lectureHall) {
    if (!lectureHall) return [];
    return lectureHall
        .split(',')
        .map((h) => normalizeRoomName(h.trim()))
        .filter(Boolean);
}

export function formatHHMM(value) {
    const s = String(value).padStart(4, '0');
    return `${s.slice(0, 2)}:${s.slice(2, 4)}`;
}

export function roomPrefix(name) {
    const match = String(name || '').match(/^(\w+)/);
    return match ? match[1] : 'Other';
}

function sortSessions(sessions) {
    return [...sessions].sort((a, b) => {
        const d = (DAY_ORDER[a.day] || 99) - (DAY_ORDER[b.day] || 99);
        if (d !== 0) return d;
        return a.start.localeCompare(b.start);
    });
}

function compareRoomNames(a, b) {
    const pa = roomPrefix(a);
    const pb = roomPrefix(b);
    if (pa !== pb) return pa.localeCompare(pb);
    const na = parseFloat(a.replace(/[^\d.]/g, '')) || 0;
    const nb = parseFloat(b.replace(/[^\d.]/g, '')) || 0;
    return na - nb || a.localeCompare(b);
}

/**
 * Build room index + per-room weekly sessions from the semester catalog.
 */
export function buildRoomCatalog(courses = [], extraOccupied = []) {
    const sessionsByRoom = new Map();
    const roomNames = new Set();

    const addSession = (room, session) => {
        if (!room) return;
        roomNames.add(room);
        if (!sessionsByRoom.has(room)) sessionsByRoom.set(room, []);
        sessionsByRoom.get(room).push(session);
    };

    courses.forEach((course) => {
        const halls = splitRoomNames(course.lectureHall);
        if (halls.length === 0) return;

        halls.forEach((room) => roomNames.add(room));

        const attach = (timingStr, type) => {
            parseTimingStr(timingStr).forEach((slot) => {
                halls.forEach((room) => {
                    addSession(room, {
                        courseCode: course.courseCode,
                        courseName: course.courseName,
                        instructor: course.instructor || '',
                        type,
                        day: slot.day,
                        start: slot.start,
                        end: slot.end,
                    });
                });
            });
        };

        if (course.slot) {
            attach(course.slot.lectureTiming, 'Lecture');
            attach(course.slot.tutorialTiming, 'Tutorial');
            attach(course.slot.labTiming, 'Lab');
        }
    });

    extraOccupied.forEach((item) => {
        const room = normalizeRoomName(item.lectureHall);
        if (!room) return;
        const day = DAY_NAMES[item.day];
        if (!day || !DAY_ORDER[day]) return;
        addSession(room, {
            courseCode: null,
            courseName: item.reason || 'Extra booking',
            instructor: '',
            type: 'Extra',
            day,
            start: String(item.startTime || '').padStart(4, '0'),
            end: String(item.endTime || '').padStart(4, '0'),
            isExtra: true,
        });
    });

    sessionsByRoom.forEach((list, room) => {
        sessionsByRoom.set(room, sortSessions(list));
    });

    const rooms = Array.from(roomNames)
        .sort(compareRoomNames)
        .map((name) => ({
            name,
            prefix: roomPrefix(name),
            sessionCount: (sessionsByRoom.get(name) || []).length,
        }));

    const catalogHasVenues = courses.some((c) => c.lectureHall);
    const catalogHasSessions = rooms.some((r) => r.sessionCount > 0);

    return {
        rooms,
        sessionsByRoom,
        catalogHasVenues,
        catalogHasSessions,
    };
}

export function getSessionsForRoom(sessionsByRoom, roomName) {
    const key = normalizeRoomName(roomName);
    return sessionsByRoom.get(key) || [];
}

export function getRoomPrefixes(rooms) {
    const counts = new Map();
    rooms.forEach(({ prefix }) => {
        counts.set(prefix, (counts.get(prefix) || 0) + 1);
    });
    return Array.from(counts.entries())
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([code, count]) => ({ code, count }));
}

export function filterRooms(rooms, { search = '', prefix = '' } = {}) {
    const term = search.trim().toLowerCase();
    return rooms.filter((room) => {
        if (prefix && room.prefix !== prefix) return false;
        if (!term) return true;
        return room.name.toLowerCase().includes(term);
    });
}

export function groupSessionsByDay(sessions) {
    const groups = {};
    Object.keys(DAY_ORDER).forEach((day) => {
        groups[day] = [];
    });
    sessions.forEach((s) => {
        if (groups[s.day]) groups[s.day].push(s);
    });
    return groups;
}

export function sessionOverlapIndices(sessions) {
    const conflict = new Set();
    for (let i = 0; i < sessions.length; i++) {
        for (let j = i + 1; j < sessions.length; j++) {
            const a = sessions[i];
            const b = sessions[j];
            if (a.day !== b.day) continue;
            if (a.courseCode && b.courseCode && a.courseCode === b.courseCode) continue;
            if (a.start < b.end && b.start < a.end) {
                conflict.add(i);
                conflict.add(j);
            }
        }
    }
    return conflict;
}
