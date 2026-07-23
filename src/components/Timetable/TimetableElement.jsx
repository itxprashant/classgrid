import React from 'react';
import './Timetable.css';

const TYPE_TO_CLASS = {
    LEC: 'tt-block--lecture',
    TUT: 'tt-block--tutorial',
    LAB: 'tt-block--lab',
    // Legacy labels from older session payloads
    Lecture: 'tt-block--lecture',
    Tutorial: 'tt-block--tutorial',
    Lab: 'tt-block--lab',
};

const TYPE_SHORT = {
    Lecture: 'LEC',
    Tutorial: 'TUT',
    Lab: 'LAB',
    LEC: 'LEC',
    TUT: 'TUT',
    LAB: 'LAB',
};

/** First hall + "+…" when multi-venue (full list stays in title). */
function shortHall(loc) {
    if (!loc) return '';
    const parts = String(loc)
        .split(/\s*,\s*/)
        .map((s) => s.trim())
        .filter(Boolean);
    if (parts.length <= 1) return String(loc).trim();
    return `${parts[0]}+…`;
}

// The grid's hour rail starts at 7 AM (see HOURS in TimetableGrid), so y=0 maps to 7 AM.
const START_HOUR = 7;

function hourOffset(start) {
    const hour = parseInt(start.substring(0, 2), 10);
    const minute = parseInt(start.substring(2, 4), 10);
    return (hour - START_HOUR) + minute / 60;
}

function durationHours(start, end) {
    const startHour = parseInt(start.substring(0, 2), 10);
    const startMinute = parseInt(start.substring(2, 4), 10);
    const endHour = parseInt(end.substring(0, 2), 10);
    const endMinute = parseInt(end.substring(2, 4), 10);
    return (endHour - startHour) + (endMinute - startMinute) / 60;
}

/** Use the same --tt-row token as the grid so blocks stay aligned at every breakpoint. */
function rowMultiple(n) {
    return `calc(var(--tt-row) * ${n})`;
}

const DAY_INDEX = { Monday: 0, Tuesday: 1, Wednesday: 2, Thursday: 3, Friday: 4 };

function getDayShift(day) {
    const idx = DAY_INDEX[day];
    if (idx === undefined) return 0;
    return `calc(100% / 5 * ${idx})`;
}

function formatTime(t) {
    if (!t) return '';
    return `${t.substring(0, 2)}:${t.substring(2, 4)}`;
}

export default function TimetableElement(props) {
    const typeClass = TYPE_TO_CLASS[props.type] || 'tt-block--lecture';
    const typeLabel = TYPE_SHORT[props.type] || props.type;
    const startTime = formatTime(props.data.start);
    const endTime = formatTime(props.data.end);
    const span = durationHours(props.data.start, props.data.end);
    const compact = span < 0.75;
    const short = span < 1.25;
    const hallFull = (props.lectureHall || '').trim();
    const hall = shortHall(hallFull);
    // ≤1h blocks can't fit four lines without clipping — fold LH into type.
    const typeLine = short && hall ? `${typeLabel} · ${hall}` : typeLabel;
    const showLoc = Boolean(hall) && !short && !compact;

    return (
        <div
            className={
                `tt-block ${typeClass}` +
                (props.conflict ? ' tt-block--conflict' : '') +
                (compact ? ' tt-block--compact' : '')
            }
            style={{
                top: rowMultiple(hourOffset(props.data.start)),
                height: rowMultiple(span),
                left: getDayShift(props.data.day),
            }}
            title={`${props.course} ${typeLabel} — ${startTime} to ${endTime}${hallFull ? ` · ${hallFull}` : ''}`}
        >
            <div className="tt-block__body">
                <span className="tt-block__code">{props.course}</span>
                <span className="tt-block__type">{typeLine}</span>
                <span className="tt-block__time mono">{startTime}–{endTime}</span>
            </div>
            {showLoc && (
                <div className="tt-block__loc">{hall}</div>
            )}
        </div>
    );
}
