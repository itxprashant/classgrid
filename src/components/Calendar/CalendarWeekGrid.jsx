import React, { useMemo } from 'react';
import { getAcademicDay, formatDateKey } from '../../utils/semesterSchedule';
import { formatEventSchedule } from '../../utils/calendarEvents';
import '../Timetable/Timetable.css';
import './CalendarWeekGrid.css';

const HOURS = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const START_HOUR = 7;
const COLS = 7;

const WEEKDAY_SHORT = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const KIND_TYPE = {
    lecture: 'Lecture',
    tutorial: 'Tutorial',
    lab: 'Lab',
};

const TYPE_LABELS = {
    quiz: 'Quiz',
    deadline: 'Deadline',
    exam: 'Exam',
    'extra-class': 'Extra class',
    presentation: 'Presentation',
    others: 'Others',
    other: 'Others',
};

function formatHour(h) {
    const suffix = h >= 12 ? 'PM' : 'AM';
    const hh = h === 0 ? 12 : h > 12 ? h - 12 : h;
    return `${hh} ${suffix}`;
}

function formatTime(t) {
    if (!t || t.length !== 4) return '';
    return `${t.substring(0, 2)}:${t.substring(2, 4)}`;
}

function hourOffset(start) {
    const hour = parseInt(start.substring(0, 2), 10);
    const minute = parseInt(start.substring(2, 4), 10);
    return hour - START_HOUR + minute / 60;
}

function durationHours(start, end) {
    const startHour = parseInt(start.substring(0, 2), 10);
    const startMinute = parseInt(start.substring(2, 4), 10);
    const endHour = parseInt(end.substring(0, 2), 10);
    const endMinute = parseInt(end.substring(2, 4), 10);
    return endHour - startHour + (endMinute - startMinute) / 60;
}

function rowMultiple(n) {
    return `calc(var(--tt-row) * ${n})`;
}

function colLeft(index) {
    return `calc(100% / ${COLS} * ${index})`;
}

function colWidth() {
    return `calc(100% / ${COLS} - (2 * var(--tt-block-inset)))`;
}

function eventTiming(evt) {
    if (evt.schedule === 'timed' && evt.start && evt.end) {
        return { start: evt.start, end: evt.end, allDay: false };
    }
    if (evt.schedule === 'at' && evt.time) {
        const h = parseInt(evt.time.slice(0, 2), 10);
        const m = evt.time.slice(2, 4);
        const endH = Math.min(h + 1, 21);
        return {
            start: evt.time,
            end: `${String(endH).padStart(2, '0')}${m}`,
            allDay: false,
        };
    }
    return { allDay: true };
}

function WeekBlock({ item }) {
    const { colIdx, start, end, compact, className, title, body, sub, onClick } = item;
    const span = durationHours(start, end);

    return (
        <div
            className={
                `tt-block ${className}` +
                (compact ? ' tt-block--compact' : '') +
                (onClick ? ' tt-block--btn' : '')
            }
            style={{
                top: rowMultiple(hourOffset(start)),
                height: rowMultiple(Math.max(span, 0.5)),
                left: colLeft(colIdx),
                width: colWidth(),
            }}
            title={title}
            role={onClick ? 'button' : undefined}
            tabIndex={onClick ? 0 : undefined}
            onClick={onClick}
            onKeyDown={
                onClick
                    ? (e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                              e.preventDefault();
                              onClick(e);
                          }
                      }
                    : undefined
            }
        >
            <div className="tt-block__body">
                <span className="tt-block__code">{body}</span>
                {sub ? <span className="tt-block__type">{sub}</span> : null}
                <span className="tt-block__time mono">
                    {formatTime(start)}–{formatTime(end)}
                </span>
            </div>
        </div>
    );
}

function AllDayPill({ evt, onClick }) {
    const label = evt.isPersonal
        ? evt.title
        : `${evt.courseCode ? `${evt.courseCode} · ` : ''}${evt.title}`;
    return (
        <button
            type="button"
            className={
                'tt__allday-pill' +
                (evt.isPersonal ? ' tt__allday-pill--personal' : ` tt__allday-pill--${evt.type}`)
            }
            onClick={onClick}
            title={formatEventSchedule(evt) || 'All day'}
        >
            {label}
        </button>
    );
}

function isExamPeriod(name) {
    return /examination/i.test(name || '');
}

function academicHeadNote(academic) {
    switch (academic.type) {
        case 'holiday':
            return { text: academic.name, variant: 'holiday' };
        case 'swapped':
            return { text: `→ ${academic.effectiveDay} TT`, variant: 'swap' };
        case 'break':
            return {
                text: academic.name,
                variant: isExamPeriod(academic.name) ? 'exam' : 'break',
            };
        case 'weekend':
            return { text: 'Weekend', variant: 'weekend' };
        case 'before-term':
            return { text: 'Before term', variant: 'break' };
        case 'after-term':
            return { text: 'After term', variant: 'break' };
        default:
            return null;
    }
}

export default function CalendarWeekGrid({
    weekDates,
    classesByDate,
    eventsByDate,
    showClasses,
    todayKey,
    fmtFull,
    openDayView,
    openEdit,
}) {
    const columns = useMemo(
        () =>
            weekDates.map((date, colIdx) => {
                const key = formatDateKey(date);
                const academic = getAcademicDay(date);
                const classes =
                    showClasses && academic.hasClasses
                        ? classesByDate.get(key) || []
                        : [];
                const events = eventsByDate.get(key) || [];
                const timed = [];
                const allDay = [];

                for (const s of classes) {
                    timed.push({
                        id: `c-${s.id}`,
                        kind: 'class',
                        colIdx,
                        start: s.start,
                        end: s.end,
                        className: `tt-block--${s.kind}`,
                        body: s.courseCode,
                        sub: KIND_TYPE[s.kind] || s.kindLabel,
                        title: `${s.courseCode} ${KIND_TYPE[s.kind] || s.kindLabel} — ${formatTime(s.start)} to ${formatTime(s.end)}`,
                    });
                }

                for (const evt of events) {
                    const timing = eventTiming(evt);
                    const dayCtx = { dateKey: key, label: fmtFull(date) };
                    if (timing.allDay) {
                        allDay.push({
                            evt,
                            onClick: (e) => {
                                e.stopPropagation();
                                openEdit(evt, dayCtx);
                            },
                        });
                    } else {
                        const span = durationHours(timing.start, timing.end);
                        timed.push({
                            id: `e-${evt.id}`,
                            kind: 'event',
                            colIdx,
                            start: timing.start,
                            end: timing.end,
                            compact: span < 0.75,
                            className: evt.isPersonal
                                ? 'tt-block--personal'
                                : `tt-block--event tt-block--event-${evt.type}`,
                            body: evt.isPersonal ? 'You' : evt.courseCode || evt.title,
                            sub: evt.isPersonal
                                ? evt.title
                                : `${TYPE_LABELS[evt.type] || evt.type} · ${evt.title}`,
                            title: `${evt.title}${formatEventSchedule(evt) ? ` (${formatEventSchedule(evt)})` : ''}`,
                            onClick: (e) => {
                                e.stopPropagation();
                                openEdit(evt, dayCtx);
                            },
                        });
                    }
                }

                timed.sort((a, b) =>
                    a.start < b.start ? -1 : a.start > b.start ? 1 : 0
                );

                const isExamBreak =
                    academic.type === 'break' && isExamPeriod(academic.name);

                return {
                    date,
                    key,
                    colIdx,
                    academic,
                    headNote: academicHeadNote(academic),
                    isToday: key === todayKey,
                    isWeekend: academic.type === 'weekend',
                    isExamBreak,
                    timed,
                    allDay,
                    dow: WEEKDAY_SHORT[colIdx],
                };
            }),
        [weekDates, classesByDate, eventsByDate, showClasses, todayKey, fmtFull, openEdit]
    );

    const hasAnyTimed = columns.some((c) => c.timed.length > 0);
    const hasAnyAllDay = columns.some((c) => c.allDay.length > 0);
    const hasAnyHeadNote = columns.some((c) => c.headNote);

    return (
        <div className="tt-scroll">
            <div
                className={
                    'tt tt--cal-week' +
                    (hasAnyHeadNote ? ' tt--cal-week-has-notes' : '') +
                    (hasAnyAllDay ? ' tt--cal-week-has-allday' : '')
                }
            >
                <div className="tt__hour-pad tt__hour-pad--cal tt__cal-corner" aria-hidden="true" />

                <div className="tt__days tt__cal-days">
                        {columns.map((col) => {
                            const headClass =
                                'tt__day-head tt__day-head--cal' +
                                (col.isToday ? ' is-today' : '') +
                                (col.isWeekend ? ' is-weekend' : '') +
                                (col.academic.type === 'holiday' ? ' is-holiday' : '') +
                                (col.isExamBreak ? ' is-exam' : '') +
                                (col.academic.type === 'break' && !col.isExamBreak
                                    ? ' is-break'
                                    : '') +
                                (col.academic.type === 'swapped' ? ' is-swap' : '');

                            const headTitle =
                                col.academic.type !== 'normal'
                                    ? col.academic.type === 'swapped'
                                        ? `${col.academic.weekday} runs as ${col.academic.effectiveDay} timetable`
                                        : col.academic.name
                                    : undefined;

                            return (
                                <div
                                    key={col.key}
                                    className={headClass}
                                    title={headTitle}
                                >
                                    <div className="tt__day-head-top">
                                        <button
                                            type="button"
                                            className="tt__day-head-btn"
                                            onClick={() => openDayView(col.key, col.date)}
                                            aria-label={`View ${fmtFull(col.date)}`}
                                        >
                                            <span className="tt__day-abbr">{col.dow}</span>
                                            <span className="tt__day-date tnum">{col.date.getDate()}</span>
                                        </button>
                                        <button
                                            type="button"
                                            className="tt__day-add"
                                            onClick={() => openDayView(col.key, col.date)}
                                            aria-label={`Add event on ${fmtFull(col.date)}`}
                                        >
                                            +
                                        </button>
                                    </div>
                                    {col.headNote ? (
                                        <div
                                            className={
                                                'tt__day-note tt__day-note--' + col.headNote.variant
                                            }
                                            title={col.headNote.text}
                                        >
                                            {col.headNote.text}
                                        </div>
                                    ) : null}
                                </div>
                            );
                        })}
                </div>

                {hasAnyAllDay && (
                    <>
                        <div className="tt__allday-pad" aria-hidden="true" />
                        <div className="tt__allday" aria-label="All-day events">
                            {columns.map((col) => (
                                <div key={col.key} className="tt__allday-col">
                                    {col.allDay.map(({ evt, onClick }) => (
                                        <AllDayPill key={evt.id} evt={evt} onClick={onClick} />
                                    ))}
                                </div>
                            ))}
                        </div>
                    </>
                )}

                <div className="tt__hours tt__cal-hours">
                    {HOURS.map((h) => (
                        <div key={h} className="tt__hour">
                            <span>{formatHour(h)}</span>
                        </div>
                    ))}
                </div>

                <div className="tt__plot tt__cal-plot">
                        <div className="tt__lines" aria-hidden="true">
                            {HOURS.map((h, i) => (
                                <div
                                    key={h}
                                    className={'tt__hline' + (i === 0 ? ' tt__hline--first' : '')}
                                />
                            ))}
                        </div>
                        <div className="tt__cols" aria-hidden="true">
                            {columns.map((col) => (
                                <div key={col.key} className="tt__col" />
                            ))}
                        </div>

                        {columns.map((col) => (
                            <button
                                key={`tap-${col.key}`}
                                type="button"
                                className="tt__col-tap"
                                style={{ left: colLeft(col.colIdx), width: `calc(100% / ${COLS})` }}
                                onClick={() => openDayView(col.key, col.date)}
                                aria-label={`View ${fmtFull(col.date)}`}
                            />
                        ))}

                        {columns.flatMap((col) =>
                            col.timed.map((item) => (
                                <WeekBlock key={item.id} item={item} />
                            ))
                        )}

                        {!hasAnyTimed && !hasAnyAllDay && (
                            <div className="tt__empty">
                                <div className="eyebrow">Nothing this week</div>
                                <p>Click a day header or + to add an event.</p>
                            </div>
                        )}
                </div>
            </div>
        </div>
    );
}
