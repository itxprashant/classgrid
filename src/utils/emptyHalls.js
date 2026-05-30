import { getAcademicDay, DAY_NAME_TO_CODE } from './semesterSchedule';
import { normalizeRoomName, splitRoomNames, parseTimingStr } from './roomSchedule';

const SLOT_TIMINGS = [
    { key: 'lectureTiming', type: 'Lecture' },
    { key: 'tutorialTiming', type: 'Tutorial' },
    { key: 'labTiming', type: 'Lab' },
];

function toMinutes(hhmm) {
    const s = String(hhmm).padStart(4, '0');
    return parseInt(s.slice(0, 2), 10) * 60 + parseInt(s.slice(2, 4), 10);
}

/**
 * Free / marked hall chips for a chosen calendar date and time.
 * Uses lecture, tutorial, and lab timings; all catalog rooms (not LH-only).
 */
export function computeEmptyHallsState({
    courses,
    extraOccupied = [],
    manualMarkings = [],
    at,
}) {
    const academic = getAcademicDay(at);
    const effectiveDayCode = academic.hasClasses ? academic.effectiveDayCode : null;
    const timeValue = at.getHours() * 100 + at.getMinutes();
    const calendarWeekday = at.getDay();
    const atMinutes = toMinutes(
        `${String(at.getHours()).padStart(2, '0')}${String(at.getMinutes()).padStart(2, '0')}`
    );

    const allHalls = new Set();
    courses.forEach((course) => {
        splitRoomNames(course.lectureHall).forEach((hall) => allHalls.add(hall));
    });
    manualMarkings.forEach((m) => {
        const room = normalizeRoomName(m.room);
        if (room) allHalls.add(room);
    });

    const timetableOccupied = new Set();
    if (effectiveDayCode != null) {
        courses.forEach((course) => {
            const halls = splitRoomNames(course.lectureHall);
            if (!halls.length || !course.slot) return;

            SLOT_TIMINGS.forEach(({ key }) => {
                const timingStr = course.slot[key];
                if (!timingStr) return;

                parseTimingStr(timingStr).forEach((slot) => {
                    const dayCode = DAY_NAME_TO_CODE[slot.day];
                    if (dayCode == null || dayCode !== effectiveDayCode) return;
                    const start = toMinutes(slot.start);
                    const end = toMinutes(slot.end);
                    if (atMinutes >= start && atMinutes < end) {
                        halls.forEach((hall) => timetableOccupied.add(hall));
                    }
                });
            });
        });
    }

    const extraOccupiedSet = new Set();
    extraOccupied.forEach((item) => {
        if (item.day !== calendarWeekday) return;
        const start = toMinutes(item.startTime);
        const end = toMinutes(item.endTime);
        if (atMinutes >= start && atMinutes < end) {
            const room = normalizeRoomName(item.lectureHall);
            if (room) extraOccupiedSet.add(room);
        }
    });

    const manualByRoom = new Map();
    manualMarkings.forEach((m) => {
        manualByRoom.set(normalizeRoomName(m.room), m);
    });

    const displayEntries = [];
    let freeCount = 0;
    let markedCount = 0;

    Array.from(allHalls)
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
        .forEach((room) => {
            if (timetableOccupied.has(room) || extraOccupiedSet.has(room)) return;

            const marking = manualByRoom.get(normalizeRoomName(room));
            if (marking) {
                displayEntries.push({ room, status: 'marked', marking });
                markedCount += 1;
            } else {
                displayEntries.push({ room, status: 'free' });
                freeCount += 1;
            }
        });

    return {
        displayEntries,
        allHalls: Array.from(allHalls),
        freeCount,
        markedCount,
        timetableOccupiedCount: timetableOccupied.size + extraOccupiedSet.size,
        academic,
    };
}
