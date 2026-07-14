import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
    formatDateKey,
    getAcademicDay,
    describeAcademicDay,
    parseDateKey,
} from '../utils/semesterSchedule';
import { buildClassesByDate, formatSessionTime, loadPlannerState } from '../utils/plannerClasses';
import {
    EVENT_TYPES,
    EVENT_SCHEDULES,
    SCHEDULE_LABELS,
    formatEventActor,
    formatEventSchedule,
    hhmmToInput,
    inputToHHMM,
    isDraftScheduleValid,
} from '../utils/calendarEvents';
import {
    createEvent,
    fetchEvents,
    patchEvent,
    removeEvent,
} from '../utils/calendarEventsApi';
import {
    createPersonalEvent,
    fetchPersonalEvents,
    patchPersonalEvent,
    removePersonalEvent,
} from '../utils/personalEventsApi';
import {
    createLocalPersonalEvent,
    loadLocalPersonalEvents,
    migrateLocalPersonalEvents,
    patchLocalPersonalEvent,
    removeLocalPersonalEvent,
} from '../utils/personalEventsLocal';
import { useDialogA11y } from '../utils/useDialogA11y';
import {
    eventActorFromUser,
} from '../utils/calendarEvents';
import AcademicCalendarButton from '../components/AcademicCalendar/AcademicCalendarButton';
import AndroidAppPromo from '../components/AndroidAppPromo/AndroidAppPromo';
import CalendarWeekGrid from '../components/Calendar/CalendarWeekGrid';
import { useAuth, apiFetch } from '../auth/AuthContext';
import { useSemesterData } from '../data/SemesterDataContext';
import SemesterDataGate from '../data/SemesterDataGate';
import ReportContentPanel from '../components/ReportContent/ReportContentPanel';
import FormField from '../components/FormField/FormField';
import './MyCalendar.css';

const MONTH_NAMES = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
];

const WEEK_HEADERS = [
    { full: 'Mon', short: 'M' },
    { full: 'Tue', short: 'T' },
    { full: 'Wed', short: 'W' },
    { full: 'Thu', short: 'T' },
    { full: 'Fri', short: 'F' },
    { full: 'Sat', short: 'S' },
    { full: 'Sun', short: 'S' },
];

const MAX_CELL_EVENTS = 2;
const MAX_CELL_CLASSES = 2;

const TYPE_LABELS = {
    quiz: 'Quiz',
    deadline: 'Deadline',
    exam: 'Exam',
    'extra-class': 'Extra class',
    presentation: 'Presentation',
    others: 'Others',
    other: 'Others',
};

function isExamPeriod(name) {
    return /examination/i.test(name || '');
}

function todayMidnight() {
    const n = new Date();
    return new Date(n.getFullYear(), n.getMonth(), n.getDate());
}

function fmtFull(date) {
    return date.toLocaleDateString('en-IN', {
        weekday: 'short',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
    });
}

function fmtDayHeader(date) {
    return {
        weekday: date.toLocaleDateString('en-IN', { weekday: 'short' }),
        cal: date.toLocaleDateString('en-IN', {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
        }),
    };
}

function academicDayBanner(info) {
    switch (info.type) {
        case 'holiday':
            return {
                label: 'Holiday',
                title: info.name,
                detail: 'No regular classes scheduled.',
            };
        case 'swapped':
            return {
                label: 'Schedule',
                title: null,
                detail: `${info.weekday} follows ${info.effectiveDay} timetable.`,
            };
        case 'break':
            return {
                label: 'Break',
                title: info.name,
                detail: 'No regular classes during this period.',
            };
        case 'weekend':
            return {
                label: 'Weekend',
                title: null,
                detail: 'No institute classes on weekends.',
            };
        case 'before-term':
            return {
                label: 'Before term',
                title: null,
                detail: describeAcademicDay(info),
            };
        case 'after-term':
            return {
                label: 'After term',
                title: null,
                detail: describeAcademicDay(info),
            };
        default:
            return null;
    }
}

// Build the rectangular Mon–Sun grid for a given month. Pads with the tail
// of the previous month and the head of the next so every row has 7 cells.
function buildMonthGrid(year, month) {
    const first = new Date(year, month, 1);
    // Mon = 0 … Sun = 6.
    const leading = (first.getDay() + 6) % 7;
    const daysInMonth = new Date(year, month + 1, 0).getDate();

    const cells = [];
    for (let i = leading - 1; i >= 0; i--) {
        const d = new Date(year, month, -i);
        cells.push({ date: d, inMonth: false });
    }
    for (let day = 1; day <= daysInMonth; day++) {
        cells.push({ date: new Date(year, month, day), inMonth: true });
    }
    while (cells.length % 7 !== 0) {
        const last = cells[cells.length - 1].date;
        cells.push({
            date: new Date(last.getFullYear(), last.getMonth(), last.getDate() + 1),
            inMonth: false,
        });
    }

    const weeks = [];
    for (let i = 0; i < cells.length; i += 7) {
        weeks.push(cells.slice(i, i + 7));
    }
    return weeks;
}

// Monday at 00:00 of the week containing `date`.
function startOfWeek(date) {
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const offset = (d.getDay() + 6) % 7; // Mon = 0 … Sun = 6
    d.setDate(d.getDate() - offset);
    return d;
}

function addDays(date, n) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n);
}

function buildWeekDates(weekStart) {
    const out = [];
    for (let i = 0; i < 7; i++) out.push(addDays(weekStart, i));
    return out;
}

// Chronological sort key for a day's events. Full-day items lead, end-of-day
// items trail, timed/at items sort by their start.
function eventSortKey(e) {
    if (e.schedule === 'at') return e.time || '0000';
    if (e.schedule === 'timed') return e.start || '0000';
    if (e.schedule === 'eod') return '2400';
    return '0000';
}

function fmtWeekRange(start, end) {
    const sameMonth = start.getMonth() === end.getMonth();
    const startStr = start.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
    const endStr = end.toLocaleDateString(
        'en-IN',
        sameMonth ? { day: 'numeric' } : { month: 'short', day: 'numeric' }
    );
    return `${startStr} – ${endStr}`;
}

function loadPlannerCourses() {
    try {
        const raw = localStorage.getItem('selectedCourses');
        if (!raw) return [];
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) return [];
        return parsed.filter((c) => c && c.courseCode);
    } catch (e) {
        return [];
    }
}

function buildCourseOptions(catalogCourses) {
    const planner = loadPlannerCourses();
    const source =
        planner.length > 0
            ? planner
            : catalogCourses.filter((c) => c && c.courseCode);

    return source
        .map((c) => ({
            courseCode: c.courseCode,
            courseName: c.courseName || c.courseCode,
        }))
        .sort((a, b) => a.courseCode.localeCompare(b.courseCode));
}

function EventActorLine({ label, actor }) {
    const info = formatEventActor(actor);
    if (!info) return null;
    return (
        <p className="mycal__form-meta-line">
            <span className="mycal__form-meta-label">{label}</span>
            <span className="mycal__form-meta-value mono">
                {info.who}
                <span className="mycal__form-meta-when">{info.when}</span>
            </span>
        </p>
    );
}

function actorsMatch(a, b) {
    if (!a || !b) return false;
    return (
        a.at === b.at &&
        (a.kerberos || a.name) === (b.kerberos || b.name)
    );
}


function MycalDayModalContent({
    modal,
    closeModal,
    showClasses,
    eventsByDate,
    classesByDate,
    openEdit,
    chooseCreateMode,
    dayDelightClass = '',
    weekdayLabel = '',
    timelineLists = false,
}) {
    const key = modal.dateKey;
    const date = parseDateKey(key);
    const academic = getAcademicDay(date);
    const dayEvents = [...(eventsByDate.get(key) || [])].sort((a, b) => {
        const ka = eventSortKey(a);
        const kb = eventSortKey(b);
        return ka < kb ? -1 : ka > kb ? 1 : 0;
    });
    const dayClasses =
        showClasses && academic.hasClasses ? classesByDate.get(key) || [] : [];
    const delight = dayDelightClass ? ` ${dayDelightClass}` : '';
    const useTimeline =
        timelineLists ||
        dayClasses.length > 1 ||
        dayEvents.length > 1;
    const dayHeader = fmtDayHeader(date);
    const academicBanner = academic.type !== 'normal' ? academicDayBanner(academic) : null;
    const instituteClasses = academic.hasClasses;
    const isQuietDay =
        !dayEvents.length &&
        !(showClasses && dayClasses.length > 0);

    return (
        <>
            <div className={`mycal__modal-head${delight ? `${delight}-head` : ''}`}>
                <div className="mycal__modal-head-main">
                    {dayDelightClass === 'mycal__ld3' && (
                        <p className="mycal__ld3-kicker mono">Day overview</p>
                    )}
                    <h2 id="mycal-modal-title" className="mycal__modal-title">
                        <span className="mycal__modal-title-row">
                            <span className="mycal__modal-title-dow mono">
                                {dayHeader.weekday}
                            </span>
                            <span className="mycal__modal-title-cal">
                                {dayHeader.cal}
                            </span>
                        </span>
                    </h2>
                    {weekdayLabel ? (
                        <span className="mycal__ld2-weekday mono">{weekdayLabel}</span>
                    ) : null}
                    {isQuietDay && !instituteClasses ? (
                        <p className="mycal__day-summary mono">Quiet day</p>
                    ) : (showClasses && dayClasses.length > 0) || dayEvents.length > 0 ? (
                        <p className="mycal__day-summary mono">
                            {showClasses && dayClasses.length > 0
                                ? `${dayClasses.length} class${dayClasses.length === 1 ? '' : 'es'}`
                                : null}
                            {showClasses &&
                            dayClasses.length > 0 &&
                            dayEvents.length > 0
                                ? ' · '
                                : null}
                            {dayEvents.length > 0
                                ? `${dayEvents.length} event${dayEvents.length === 1 ? '' : 's'}`
                                : null}
                        </p>
                    ) : null}
                </div>
                <button
                    type="button"
                    className="btn btn--sm btn--ghost mycal__modal-close"
                    onClick={closeModal}
                    aria-label="Close"
                >
                    ×
                </button>
            </div>

            <div
                className={
                    'mycal__day-body' +
                    (isQuietDay && !instituteClasses ? ' mycal__day-body--quiet' : '')
                }
            >
            <div className="mycal__day-scroll">
                {academicBanner && (
                    <div
                        className={
                            'mycal__day-academic' +
                            (academic.type === 'holiday'
                                ? ' mycal__day-academic--holiday'
                                : '') +
                            (academic.type === 'swapped'
                                ? ' mycal__day-academic--swap'
                                : '') +
                            (academic.type === 'break'
                                ? ' mycal__day-academic--break'
                                : '') +
                            (academic.type === 'weekend'
                                ? ' mycal__day-academic--weekend'
                                : '')
                        }
                    >
                        <span className="mycal__day-academic-label mono">
                            {academicBanner.label}
                        </span>
                        {academicBanner.title ? (
                            <p className="mycal__day-academic-title">
                                {academicBanner.title}
                            </p>
                        ) : null}
                        <p className="mycal__day-academic-text">
                            {academicBanner.detail}
                        </p>
                    </div>
                )}

                <section className="mycal__day-section">
                    <div className="mycal__day-section-head">
                        <h3 className="mycal__day-section-title mono">
                            Classes
                        </h3>
                        {showClasses && dayClasses.length > 0 ? (
                            <span className="mycal__day-section-count mono">
                                {dayClasses.length}
                            </span>
                        ) : null}
                    </div>
                    {!instituteClasses ? (
                        <p className="mycal__day-empty">
                            No institute classes today.
                        </p>
                    ) : !showClasses ? (
                        <p className="mycal__day-empty mycal__day-empty--hint">
                            Enable <strong>Show classes</strong> in the toolbar
                            to overlay your planner timetable here.
                        </p>
                    ) : dayClasses.length === 0 ? (
                        <p className="mycal__day-empty">No classes on this day.</p>
                    ) : (
                        <ul
                            className={
                                'mycal__day-list' +
                                (useTimeline ? ' mycal__day-list--timeline' : '')
                            }
                        >
                            {dayClasses.map((s) => (
                                <li
                                    key={s.id}
                                    className={`mycal__day-item mycal__day-item--${s.kind}`}
                                >
                                    <span
                                        className={`mycal__day-item-kind mycal__day-item-kind--${s.kind} mono`}
                                        aria-hidden="true"
                                    >
                                        {s.kind === 'lecture'
                                            ? 'L'
                                            : s.kind === 'tutorial'
                                              ? 'T'
                                              : s.kind === 'lab'
                                                ? 'Lab'
                                                : s.kindLabel}
                                    </span>
                                    <span className="mycal__day-item-main">
                                        <span className="mycal__day-item-title mono">
                                            {s.courseCode}
                                        </span>
                                        <span className="mycal__day-item-meta mono">
                                            {s.timeLabel}–
                                            {formatSessionTime(s.end)}
                                            {s.location
                                                ? ` · ${s.location}`
                                                : ''}
                                        </span>
                                    </span>
                                </li>
                            ))}
                        </ul>
                    )}
                </section>

                <section className="mycal__day-section">
                    <div className="mycal__day-section-head">
                        <h3 className="mycal__day-section-title mono">
                            Events
                        </h3>
                        {dayEvents.length > 0 ? (
                            <span className="mycal__day-section-count mono">
                                {dayEvents.length}
                            </span>
                        ) : null}
                    </div>
                    {dayEvents.length === 0 ? (
                        <p
                            className={
                                'mycal__day-empty' +
                                (isQuietDay
                                    ? ' mycal__day-empty--quiet'
                                    : ' mycal__day-empty--action')
                            }
                        >
                            {isQuietDay && !instituteClasses
                                ? 'Your calendar is clear. Add a personal reminder below if you need one.'
                                : 'No events yet. Add a course or personal event below.'}
                        </p>
                    ) : (
                        <ul
                            className={
                                'mycal__day-list' +
                                (useTimeline ? ' mycal__day-list--timeline' : '')
                            }
                        >
                            {dayEvents.map((evt) => (
                                <li key={evt.id}>
                                    <button
                                        type="button"
                                        className={
                                            'mycal__day-item mycal__day-item--btn' +
                                            (evt.isPersonal
                                                ? ' mycal__day-item--personal'
                                                : ` mycal__day-item--${evt.type}`)
                                        }
                                        onClick={() =>
                                            openEdit(evt, {
                                                dateKey: key,
                                                label: modal.label,
                                            })
                                        }
                                    >
                                        <span className="mycal__day-item-kind mono">
                                            {evt.isPersonal
                                                ? 'You'
                                                : TYPE_LABELS[evt.type] ||
                                                  evt.type}
                                        </span>
                                        <span className="mycal__day-item-main">
                                            <span className="mycal__day-item-title">
                                                {evt.title}
                                            </span>
                                            <span className="mycal__day-item-meta mono">
                                                {evt.isPersonal
                                                    ? ''
                                                    : evt.courseCode
                                                      ? `${evt.courseCode} · `
                                                      : ''}
                                                {formatEventSchedule(evt) ||
                                                    'All day'}
                                            </span>
                                        </span>
                                        <span
                                            className="mycal__day-item-chevron"
                                            aria-hidden="true"
                                        >
                                            ›
                                        </span>
                                    </button>
                                </li>
                            ))}
                        </ul>
                    )}
                </section>
            </div>

            <div className="mycal__day-add">
                <h3 className="mycal__day-section-title mono">Add event</h3>
                <div className="mycal__picker-options">
                    <button
                        type="button"
                        className="mycal__picker-option mycal__picker-option--shared"
                        onClick={() => chooseCreateMode('shared')}
                    >
                        <span className="mycal__picker-option-label mono">
                            Shared
                        </span>
                        <span className="mycal__picker-option-body">
                            <span className="mycal__picker-option-title">
                                Course event
                            </span>
                            <span className="mycal__picker-option-desc">
                                Synced for everyone on that course — quiz,
                                deadline, exam, …
                            </span>
                        </span>
                    </button>
                    <button
                        type="button"
                        className="mycal__picker-option mycal__picker-option--personal"
                        onClick={() => chooseCreateMode('personal')}
                    >
                        <span className="mycal__picker-option-label mono">
                            Private
                        </span>
                        <span className="mycal__picker-option-body">
                            <span className="mycal__picker-option-title">
                                Personal event
                            </span>
                            <span className="mycal__picker-option-desc">
                                Only you see this; not tied to a course
                            </span>
                        </span>
                    </button>
                </div>
            </div>
            </div>
        </>
    );
}

function emptyDraft(dateKey, defaultCourseCode = '', mode = 'shared') {
    return {
        id: null,
        mode,
        date: dateKey,
        courseCode: defaultCourseCode,
        title: '',
        type: mode === 'personal' ? 'others' : 'quiz',
        schedule: 'fullday',
        time: '',
        start: '',
        end: '',
        note: '',
    };
}

export default function MyCalendar() {
    const { user, login } = useAuth();
    const { courses: catalogCourses } = useSemesterData();
    const today = todayMidnight();
    const [viewMode, setViewMode] = useState('week');
    const [viewYear, setViewYear] = useState(today.getFullYear());
    const [viewMonth, setViewMonth] = useState(today.getMonth());
    const [weekAnchor, setWeekAnchor] = useState(today);

    const [events, setEvents] = useState([]);
    const [eventsLoading, setEventsLoading] = useState(true);
    const [eventsError, setEventsError] = useState(null);
    const [saving, setSaving] = useState(false);
    const [modal, setModal] = useState(null);
    const [eventFormView, setEventFormView] = useState('form');
    const [reportingEvent, setReportingEvent] = useState(null);
    const [showClasses, setShowClasses] = useState(false);
    const [enrolledCodes, setEnrolledCodes] = useState([]);
    const migratedLocalRef = useRef(false);
    const modalDialogRef = useRef(null);
    const reportDialogRef = useRef(null);

    const plannerCourses = useMemo(() => loadPlannerCourses(), []);
    const courseOptions = useMemo(() => buildCourseOptions(catalogCourses), [catalogCourses]);
    const usesPlannerCourses = plannerCourses.length > 0;
    const defaultCourseCode = courseOptions[0]?.courseCode || '';

    // Only fetch events for planner + OAuth-enrolled courses — never the full catalog
    // (putting every course code in the query string hits HTTP 414).
    const fetchCourseCodes = useMemo(() => {
        const codes = new Set(
            plannerCourses.map((c) => c.courseCode).filter(Boolean)
        );
        for (const code of enrolledCodes) {
            if (code) codes.add(code);
        }
        return [...codes];
    }, [plannerCourses, enrolledCodes]);

    useEffect(() => {
        if (!user) {
            setEnrolledCodes([]);
            return;
        }
        let cancelled = false;
        (async () => {
            try {
                const res = await apiFetch('/api/me/courses');
                if (!res.ok) return;
                const data = await res.json();
                if (!cancelled && Array.isArray(data.courses)) {
                    setEnrolledCodes(data.courses);
                }
            } catch (e) {
                // ignore — planner courses still work
            }
        })();
        return () => {
            cancelled = true;
        };
    }, [user]);

    const weeks = useMemo(
        () => buildMonthGrid(viewYear, viewMonth),
        [viewYear, viewMonth]
    );

    const weekStart = useMemo(() => startOfWeek(weekAnchor), [weekAnchor]);
    const weekDates = useMemo(() => buildWeekDates(weekStart), [weekStart]);

    const gridDates = useMemo(
        () =>
            viewMode === 'week'
                ? weekDates
                : weeks.flat().map((c) => c.date),
        [viewMode, weekDates, weeks]
    );

    const includePlannerClasses = viewMode === 'week' || showClasses;

    const fetchRange = useMemo(() => {
        if (gridDates.length === 0) return null;
        return {
            from: formatDateKey(gridDates[0]),
            to: formatDateKey(gridDates[gridDates.length - 1]),
        };
    }, [gridDates]);

    const reloadEvents = useCallback(async () => {
        if (!fetchRange) {
            setEvents([]);
            setEventsLoading(false);
            setEventsError(null);
            return;
        }
        setEventsLoading(true);
        setEventsError(null);
        try {
            const sharedPromise =
                fetchCourseCodes.length > 0
                    ? fetchEvents({
                          from: fetchRange.from,
                          to: fetchRange.to,
                          courses: fetchCourseCodes,
                      })
                    : Promise.resolve([]);
            const personalPromise = user
                ? fetchPersonalEvents({ from: fetchRange.from, to: fetchRange.to })
                : Promise.resolve(
                      loadLocalPersonalEvents({
                          from: fetchRange.from,
                          to: fetchRange.to,
                      })
                  );
            const [shared, personal] = await Promise.all([sharedPromise, personalPromise]);
            setEvents([...shared, ...personal]);
        } catch (e) {
            const msg =
                e.status === 414
                    ? 'Too many courses in the request — add courses on the Plan page first.'
                    : e.message || 'Could not load events';
            setEventsError(msg);
            setEvents([]);
        } finally {
            setEventsLoading(false);
        }
    }, [fetchRange, fetchCourseCodes, user]);

    useEffect(() => {
        reloadEvents();
    }, [reloadEvents]);

    useEffect(() => {
        if (!user || migratedLocalRef.current) return undefined;
        let cancelled = false;
        (async () => {
            try {
                const count = await migrateLocalPersonalEvents(createPersonalEvent);
                if (cancelled || count === 0) return;
                migratedLocalRef.current = true;
                await reloadEvents();
            } catch (e) {
                // Keep local copies if migration fails (offline, etc.)
            }
        })();
        return () => {
            cancelled = true;
        };
    }, [user, reloadEvents]);

    const classesByDate = useMemo(() => {
        if (!includePlannerClasses) return new Map();
        const { courses, timetableData } = loadPlannerState();
        return buildClassesByDate(gridDates, courses, timetableData);
    }, [includePlannerClasses, gridDates]);

    const plannerCourseCount = useMemo(() => {
        if (!includePlannerClasses) return 0;
        return loadPlannerState().courses.length;
    }, [includePlannerClasses]);

    // Index events by date key for O(1) cell lookup.
    const eventsByDate = useMemo(() => {
        const map = new Map();
        for (const e of events) {
            if (!map.has(e.date)) map.set(e.date, []);
            map.get(e.date).push(e);
        }
        return map;
    }, [events]);

    const upcoming = useMemo(() => {
        const todayKey = formatDateKey(today);
        return [...events]
            .filter((e) => e.date >= todayKey)
            .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
    }, [events, today]);

    const goPrev = () => {
        if (viewMode === 'week') {
            setWeekAnchor((d) => addDays(startOfWeek(d), -7));
            return;
        }
        if (viewMonth === 0) {
            setViewMonth(11);
            setViewYear((y) => y - 1);
        } else {
            setViewMonth((m) => m - 1);
        }
    };
    const goNext = () => {
        if (viewMode === 'week') {
            setWeekAnchor((d) => addDays(startOfWeek(d), 7));
            return;
        }
        if (viewMonth === 11) {
            setViewMonth(0);
            setViewYear((y) => y + 1);
        } else {
            setViewMonth((m) => m + 1);
        }
    };
    const goToday = () => {
        setWeekAnchor(today);
        setViewYear(today.getFullYear());
        setViewMonth(today.getMonth());
    };

    // Switch view, carrying the visible range across so the user stays oriented.
    const switchView = (mode) => {
        if (mode === viewMode) return;
        if (mode === 'week') {
            const inViewedMonth =
                today.getFullYear() === viewYear && today.getMonth() === viewMonth;
            setWeekAnchor(inViewedMonth ? today : new Date(viewYear, viewMonth, 1));
        } else {
            const rep = addDays(weekStart, 3); // Thursday → the week's dominant month
            setViewYear(rep.getFullYear());
            setViewMonth(rep.getMonth());
        }
        setViewMode(mode);
    };

    const closeModal = () => {
        setModal(null);
        setEventFormView('form');
    };

    useDialogA11y(modalDialogRef, { onClose: closeModal, active: !!modal });

    const closeReportDialog = () => setReportingEvent(null);
    useDialogA11y(reportDialogRef, { onClose: closeReportDialog, active: !!reportingEvent });

    const updateModalDraft = (updater) => {
        setModal((prev) => {
            if (!prev || prev.type !== 'form') return prev;
            const draft = typeof updater === 'function' ? updater(prev.draft) : updater;
            return { ...prev, draft };
        });
    };

    const openDayView = (dateKey, date) => {
        setModal({ type: 'day', dateKey, label: fmtFull(date) });
    };

    const chooseCreateMode = (mode) => {
        setModal((prev) => {
            if (!prev || prev.type !== 'day') return prev;
            return {
                type: 'form',
                pickCtx: { dateKey: prev.dateKey, label: prev.label },
                draft: emptyDraft(prev.dateKey, defaultCourseCode, mode),
            };
        });
    };

    const goBackToDay = () => {
        setModal((prev) => {
            if (!prev || prev.type !== 'form' || !prev.pickCtx) return prev;
            return { type: 'day', ...prev.pickCtx };
        });
    };

    const openEdit = (evt, dayCtx = null) => {
        setEventFormView('form');
        setModal({
            type: 'form',
            pickCtx: dayCtx,
            draft: {
                id: evt.id,
                mode: evt.isPersonal ? 'personal' : 'shared',
                date: evt.date,
                courseCode: evt.courseCode || defaultCourseCode,
                title: evt.title,
                type: evt.type,
                schedule: evt.schedule || 'fullday',
                time: evt.time || '',
                start: evt.start || '',
                end: evt.end || '',
                note: evt.note || '',
                createdBy: evt.createdBy || null,
                updatedBy: evt.updatedBy || null,
            },
        });
    };

    const handleSave = async (e) => {
        e.preventDefault();
        if (!modal || modal.type !== 'form' || saving) return;
        const draft = modal.draft;
        const title = draft.title.trim();
        const isPersonal = draft.mode === 'personal';
        const courseCode = draft.courseCode.trim();
        if (!title || !isDraftScheduleValid(draft)) return;
        if (!isPersonal && !courseCode) return;

        if (!user) {
            if (!isPersonal) {
                login();
                return;
            }
            const payload = {
                date: draft.date,
                title,
                type: draft.type,
                schedule: draft.schedule,
                time: draft.time,
                start: draft.start,
                end: draft.end,
                note: draft.note,
            };
            const actor = eventActorFromUser(null);
            setSaving(true);
            setEventsError(null);
            try {
                if (draft.id) {
                    patchLocalPersonalEvent(draft.id, payload, actor);
                } else {
                    createLocalPersonalEvent(payload, actor);
                }
                closeModal();
                await reloadEvents();
            } catch (err) {
                setEventsError(err.message || 'Could not save event');
            } finally {
                setSaving(false);
            }
            return;
        }

        const payload = {
            date: draft.date,
            title,
            type: draft.type,
            schedule: draft.schedule,
            time: draft.time,
            start: draft.start,
            end: draft.end,
            note: draft.note,
        };
        if (!isPersonal) {
            payload.courseCode = courseCode;
        }

        setSaving(true);
        setEventsError(null);
        try {
            if (draft.id) {
                if (isPersonal) {
                    await patchPersonalEvent(draft.id, payload);
                } else {
                    await patchEvent(draft.id, payload);
                }
            } else if (isPersonal) {
                await createPersonalEvent(payload);
            } else {
                await createEvent(payload);
            }
            closeModal();
            await reloadEvents();
        } catch (err) {
            if (err.code === 'not_authenticated') {
                login();
            } else {
                setEventsError(err.message || 'Could not save event');
            }
        } finally {
            setSaving(false);
        }
    };

    const handleDelete = async () => {
        if (!modal || modal.type !== 'form' || !modal.draft.id || saving) return;
        const draft = modal.draft;

        if (!user) {
            if (draft.mode !== 'personal') {
                login();
                return;
            }
            setSaving(true);
            setEventsError(null);
            try {
                removeLocalPersonalEvent(draft.id);
                closeModal();
                await reloadEvents();
            } catch (err) {
                setEventsError(err.message || 'Could not delete event');
            } finally {
                setSaving(false);
            }
            return;
        }

        setSaving(true);
        setEventsError(null);
        try {
            if (draft.mode === 'personal') {
                await removePersonalEvent(draft.id);
            } else {
                await removeEvent(draft.id);
            }
            closeModal();
            await reloadEvents();
        } catch (err) {
            if (err.code === 'not_authenticated') {
                login();
            } else {
                setEventsError(err.message || 'Could not delete event');
            }
        } finally {
            setSaving(false);
        }
    };

    const handleDeleteFromList = async (evt) => {
        if (saving) return;

        if (!user) {
            if (!evt.isPersonal) {
                login();
                return;
            }
            setSaving(true);
            setEventsError(null);
            try {
                removeLocalPersonalEvent(evt.id);
                if (modal?.type === 'form' && modal.draft.id === evt.id) closeModal();
                await reloadEvents();
            } catch (err) {
                setEventsError(err.message || 'Could not delete event');
            } finally {
                setSaving(false);
            }
            return;
        }

        setSaving(true);
        setEventsError(null);
        try {
            if (evt.isPersonal) {
                await removePersonalEvent(evt.id);
            } else {
                await removeEvent(evt.id);
            }
            if (modal?.type === 'form' && modal.draft.id === evt.id) closeModal();
            await reloadEvents();
        } catch (err) {
            if (err.code === 'not_authenticated') {
                login();
            } else {
                setEventsError(err.message || 'Could not delete event');
            }
        } finally {
            setSaving(false);
        }
    };

    const modalDraft = modal?.type === 'form' ? modal.draft : null;
    const modalFormTitle = modalDraft
        ? modalDraft.id
            ? modalDraft.mode === 'personal'
                ? 'Edit personal event'
                : 'Edit course event'
            : modalDraft.mode === 'personal'
              ? 'New personal event'
              : 'New course event'
        : '';

    const todayKey = formatDateKey(today);

    const renderClassChip = (s) => (
        <span
            key={s.id}
            className={`mycal__class-chip mycal__class-chip--${s.kind}`}
            title={`${s.courseCode} ${s.kindLabel} ${s.timeLabel}–${formatSessionTime(s.end)}`}
        >
            <span className="mycal__class-chip-code mono">{s.courseCode}</span>
            <span className="mycal__class-chip-meta">
                {s.kindLabel} {s.timeLabel}
            </span>
        </span>
    );

    const renderEventChip = (e) => (
        <span
            key={e.id}
            className={
                'mycal__chip' +
                (e.isPersonal ? ' mycal__chip--personal' : ` mycal__chip--${e.type}`)
            }
            role="button"
            tabIndex={0}
            aria-label={[
                e.isPersonal ? 'Personal event' : e.courseCode,
                TYPE_LABELS[e.type],
                e.title,
                formatEventSchedule(e),
            ].filter(Boolean).join(', ')}
            onClick={(ev) => {
                ev.stopPropagation();
                openEdit(e);
            }}
            onKeyDown={(ev) => {
                if (ev.key === 'Enter' || ev.key === ' ') {
                    ev.preventDefault();
                    ev.stopPropagation();
                    openEdit(e);
                }
            }}
            title={`${e.isPersonal ? 'Personal · ' : e.courseCode ? `${e.courseCode} · ` : ''}${TYPE_LABELS[e.type]} — ${e.title}${formatEventSchedule(e) ? ` (${formatEventSchedule(e)})` : ''}`}
        >
            {e.isPersonal ? (
                <span className="mycal__chip-code mono">You</span>
            ) : e.courseCode ? (
                <span className="mycal__chip-code mono">{e.courseCode}</span>
            ) : null}
            <span className="mycal__chip-title">{e.title}</span>
            {formatEventSchedule(e) && (
                <span className="mycal__chip-time mono">{formatEventSchedule(e)}</span>
            )}
        </span>
    );

    return (
        <SemesterDataGate>
        <div className="mycal">
            <header className="mycal__head">
                <div className="mycal__eyebrow">Calendar</div>
                <h1 className="mycal__title">
                    Quizzes, deadlines &amp; <em>everything you can't miss</em>.
                </h1>
                <p className="mycal__sub">
                    Shared course events are visible to everyone in that course — log in with IITD
                    to add or edit those. Personal events are private: guests save them on this
                    device; when you sign in, they sync to your account. Use{' '}
                    <strong>Holidays &amp; timetable changes</strong> for institute holidays,
                    swaps and breaks.
                </p>
            </header>

            <AndroidAppPromo />

            {eventsError && (
                <p className="mycal__status status status--err" role="alert">
                    {eventsError}
                </p>
            )}

            {!user && (
                <p className="mycal__status status">
                    <button type="button" className="btn btn--sm btn--primary" onClick={login}>
                        Log in with IITD
                    </button>
                    {' '}to add shared course events or sync personal events across devices.
                </p>
            )}

            {fetchCourseCodes.length === 0 && (
                <p className="mycal__status status">
                    Add courses on the Plan page to see and share events for your timetable.
                    {user ? ' Your enrolled courses will also appear once they are on the plan or in the registration data.' : ''}
                </p>
            )}

            <div className="mycal__toolbar">
                <div className="mycal__nav">
                    <button
                        type="button"
                        className="btn btn--sm btn--icon"
                        onClick={goPrev}
                        aria-label={viewMode === 'week' ? 'Previous week' : 'Previous month'}
                    >
                        ‹
                    </button>
                    <div className="mycal__month-label">
                        {viewMode === 'week' ? (
                            <>
                                <span className="mycal__month-name">
                                    {fmtWeekRange(weekStart, weekDates[6])}
                                </span>
                                <span className="mycal__month-year mono">
                                    {weekDates[6].getFullYear()}
                                </span>
                            </>
                        ) : (
                            <>
                                <span className="mycal__month-name">{MONTH_NAMES[viewMonth]}</span>
                                <span className="mycal__month-year mono">{viewYear}</span>
                            </>
                        )}
                    </div>
                    <button
                        type="button"
                        className="btn btn--sm btn--icon"
                        onClick={goNext}
                        aria-label={viewMode === 'week' ? 'Next week' : 'Next month'}
                    >
                        ›
                    </button>
                </div>
                <div className="mycal__toolbar-actions">
                    <div
                        className="mycal__viewtoggle"
                        role="group"
                        aria-label="Calendar view"
                    >
                        <button
                            type="button"
                            className={
                                'mycal__viewtoggle-btn' +
                                (viewMode === 'month' ? ' is-active' : '')
                            }
                            aria-pressed={viewMode === 'month'}
                            onClick={() => switchView('month')}
                        >
                            Month
                        </button>
                        <button
                            type="button"
                            className={
                                'mycal__viewtoggle-btn' +
                                (viewMode === 'week' ? ' is-active' : '')
                            }
                            aria-pressed={viewMode === 'week'}
                            onClick={() => switchView('week')}
                        >
                            Week
                        </button>
                    </div>
                    <AcademicCalendarButton />
                    {viewMode === 'month' && (
                        <label className="mycal__show-classes">
                            <input
                                type="checkbox"
                                checked={showClasses}
                                onChange={(e) => setShowClasses(e.target.checked)}
                            />
                            <span>Show classes</span>
                        </label>
                    )}
                    <button type="button" className="btn btn--sm" onClick={goToday}>
                        Today
                    </button>
                </div>
            </div>

            {(viewMode === 'week' || showClasses) && plannerCourseCount === 0 && (
                <p className="mycal__planner-hint status">
                    No courses on your planner yet — add them on the Plan page to see classes here.
                </p>
            )}

            {eventsLoading && (
                <p className="mycal__status status">Loading events…</p>
            )}

            {viewMode === 'month' && (
            <div className="mycal__grid-scroll">
            <div className="mycal__grid" role="grid" aria-label="Monthly calendar">
                <div className="mycal__weekhead" role="row">
                    {WEEK_HEADERS.map((w) => (
                        <div key={w.full} className="mycal__weekhead-cell" role="columnheader">
                            <span className="mycal__weekhead-full">{w.full}</span>
                            <span className="mycal__weekhead-short" aria-hidden="true">{w.short}</span>
                        </div>
                    ))}
                </div>

                {weeks.map((week, wi) => (
                    <div key={wi} className="mycal__week" role="row">
                        {week.map(({ date, inMonth }) => {
                            const key = formatDateKey(date);
                            const dayEvents = eventsByDate.get(key) || [];
                            const academic = getAcademicDay(date);
                            const dayClasses =
                                includePlannerClasses && academic.hasClasses
                                    ? classesByDate.get(key) || []
                                    : [];
                            const isToday = key === todayKey;
                            const isWeekend = academic.type === 'weekend';

                            const isExamBreak =
                                academic.type === 'break' && isExamPeriod(academic.name);

                            const cellClass =
                                'mycal__cell' +
                                (inMonth ? '' : ' is-out') +
                                (isToday ? ' is-today' : '') +
                                (isWeekend ? ' is-weekend' : '') +
                                (academic.type === 'holiday' ? ' is-holiday' : '') +
                                (isExamBreak ? ' is-exam' : '') +
                                (academic.type === 'break' && !isExamBreak ? ' is-break' : '') +
                                (academic.type === 'swapped' ? ' is-swap' : '');

                            return (
                                <button
                                    key={key}
                                    type="button"
                                    className={cellClass}
                                    onClick={() => openDayView(key, date)}
                                    aria-label={`View ${fmtFull(date)}`}
                                >
                                    <span className="mycal__cell-num tnum">{date.getDate()}</span>

                                    {academic.type === 'holiday' && (
                                        <span
                                            className="mycal__cell-tag mycal__cell-tag--holiday"
                                            title={academic.name}
                                        >
                                            {academic.name}
                                        </span>
                                    )}
                                    {academic.type === 'swapped' && (
                                        <span
                                            className="mycal__cell-tag mycal__cell-tag--swap"
                                            title={`${academic.weekday} runs as ${academic.effectiveDay} timetable`}
                                        >
                                            → {academic.effectiveDay} TT
                                        </span>
                                    )}
                                    {academic.type === 'break' && (
                                        <span
                                            className={
                                                'mycal__cell-tag' +
                                                (isExamBreak
                                                    ? ' mycal__cell-tag--exam'
                                                    : ' mycal__cell-tag--break')
                                            }
                                            title={academic.name}
                                        >
                                            {academic.name}
                                        </span>
                                    )}

                                    {dayClasses.length > 0 && (
                                        <span
                                            className="mycal__cell-classes"
                                            onClick={(ev) => ev.stopPropagation()}
                                            onKeyDown={(ev) => ev.stopPropagation()}
                                        >
                                            {dayClasses
                                                .slice(0, MAX_CELL_CLASSES)
                                                .map(renderClassChip)}
                                            {dayClasses.length > MAX_CELL_CLASSES && (
                                                <span className="mycal__cell-more mono">
                                                    +{dayClasses.length - MAX_CELL_CLASSES} class
                                                    {dayClasses.length - MAX_CELL_CLASSES === 1 ? '' : 'es'}
                                                </span>
                                            )}
                                        </span>
                                    )}

                                    {dayEvents.length > 0 && (
                                        <span className="mycal__cell-events">
                                            {dayEvents
                                                .slice(0, MAX_CELL_EVENTS)
                                                .map(renderEventChip)}
                                            {dayEvents.length > MAX_CELL_EVENTS && (
                                                <span className="mycal__cell-more mono">
                                                    +{dayEvents.length - MAX_CELL_EVENTS} more
                                                </span>
                                            )}
                                        </span>
                                    )}
                                </button>
                            );
                        })}
                    </div>
                ))}
            </div>
            </div>
            )}

            {viewMode === 'week' && (
                <div className="mycal__week-board">
                    <CalendarWeekGrid
                        weekDates={weekDates}
                        classesByDate={classesByDate}
                        eventsByDate={eventsByDate}
                        showClasses
                        todayKey={todayKey}
                        fmtFull={fmtFull}
                        openDayView={openDayView}
                        openEdit={openEdit}
                    />
                </div>
            )}

            {modal && (
                <div
                    className="mycal__modal-backdrop"
                    onClick={closeModal}
                    role="presentation"
                >
                    <div
                            ref={modalDialogRef}
                            className={
                                'mycal__modal panel' +
                                (modal.type === 'form' ? ' mycal__modal--form' : '') +
                                (modal.type === 'day' ? ' mycal__modal--day' : '')
                            }
                            role="dialog"
                            aria-modal="true"
                            aria-labelledby="mycal-modal-title"
                            onClick={(e) => e.stopPropagation()}
                        >
                            {modal.type === 'day' ? (
                                <MycalDayModalContent
                                    modal={modal}
                                    closeModal={closeModal}
                                    showClasses={includePlannerClasses}
                                    eventsByDate={eventsByDate}
                                    classesByDate={classesByDate}
                                    openEdit={openEdit}
                                    chooseCreateMode={chooseCreateMode}
                                />
                            ) : eventFormView === 'report' && modalDraft?.id && modalDraft.mode !== 'personal' ? (
                                <>
                                    <div className="mycal__modal-head">
                                        <div className="mycal__modal-head-main">
                                            <button
                                                type="button"
                                                className="btn btn--sm btn--ghost mycal__modal-back"
                                                onClick={() => setEventFormView('form')}
                                            >
                                                ← Back
                                            </button>
                                            <h2 id="mycal-modal-title" className="mycal__modal-title">
                                                Report event
                                            </h2>
                                        </div>
                                        <button
                                            type="button"
                                            className="btn btn--sm btn--ghost"
                                            onClick={closeModal}
                                            aria-label="Close"
                                        >
                                            ×
                                        </button>
                                    </div>
                                    <ReportContentPanel
                                        compact
                                        targetKind="course_event"
                                        targetId={modalDraft.id}
                                        contextLabel={`${modalDraft.courseCode} · ${modalDraft.title} · ${modalDraft.date}`}
                                        onDone={closeModal}
                                        onCancel={() => setEventFormView('form')}
                                    />
                                </>
                            ) : (
                                <form className="mycal__form" onSubmit={handleSave}>
                                    <div className="mycal__modal-head">
                                        <div className="mycal__modal-head-main">
                                            {modal.pickCtx && (
                                                <button
                                                    type="button"
                                                    className="btn btn--sm btn--ghost mycal__modal-back"
                                                    onClick={goBackToDay}
                                                >
                                                    ← Back
                                                </button>
                                            )}
                                            <h2 id="mycal-modal-title" className="mycal__modal-title">
                                                {modalFormTitle}
                                            </h2>
                                        </div>
                                        <button
                                            type="button"
                                            className="btn btn--sm btn--ghost"
                                            onClick={closeModal}
                                            aria-label="Close"
                                        >
                                            ×
                                        </button>
                                    </div>

                                    {modalDraft.id && (modalDraft.createdBy || modalDraft.updatedBy) && (
                                        <div className="mycal__form-meta">
                                            {modalDraft.createdBy && (
                                                <EventActorLine label="Added by" actor={modalDraft.createdBy} />
                                            )}
                                            {modalDraft.updatedBy &&
                                                !actorsMatch(modalDraft.createdBy, modalDraft.updatedBy) && (
                                                <EventActorLine label="Last edited by" actor={modalDraft.updatedBy} />
                                            )}
                                        </div>
                                    )}

                                    {modalDraft.mode === 'personal' && (
                                        <p className="mycal__form-scope">
                                            Only you can see this event.
                                        </p>
                                    )}

                                    <div className="mycal__form-grid">
                                        <FormField label="Date" htmlFor="mycal-event-date" className="mycal__form-row">
                                            <input
                                                id="mycal-event-date"
                                                type="date"
                                                className="field field--mono"
                                                value={modalDraft.date}
                                                onChange={(e) =>
                                                    updateModalDraft((d) => ({ ...d, date: e.target.value }))
                                                }
                                                required
                                            />
                                        </FormField>

                                        <FormField label="Type" htmlFor="mycal-event-type" className="mycal__form-row">
                                            <select
                                                id="mycal-event-type"
                                                className="field"
                                                value={modalDraft.type}
                                                onChange={(e) =>
                                                    updateModalDraft((d) => ({ ...d, type: e.target.value }))
                                                }
                                            >
                                                {EVENT_TYPES.map((t) => (
                                                    <option key={t} value={t}>
                                                        {TYPE_LABELS[t]}
                                                    </option>
                                                ))}
                                            </select>
                                        </FormField>

                                        <FormField
                                            label="Course"
                                            htmlFor={modalDraft.mode === 'personal' ? undefined : 'mycal-event-course'}
                                            className="mycal__form-row form-field--wide"
                                            wide
                                        >
                                            {modalDraft.mode === 'personal' ? (
                                                <span className="mycal__form-hint">
                                                    Not linked to a course — personal events stay private.
                                                </span>
                                            ) : (
                                                <>
                                                    <select
                                                        id="mycal-event-course"
                                                        className="field field--mono"
                                                        value={modalDraft.courseCode}
                                                        onChange={(e) =>
                                                            updateModalDraft((d) => ({
                                                                ...d,
                                                                courseCode: e.target.value,
                                                            }))
                                                        }
                                                        required
                                                    >
                                                        <option value="">Select a course…</option>
                                                        {courseOptions.map((c) => (
                                                            <option key={c.courseCode} value={c.courseCode}>
                                                                {c.courseCode} — {c.courseName}
                                                            </option>
                                                        ))}
                                                    </select>
                                                    {!usesPlannerCourses && (
                                                        <span className="mycal__form-hint">
                                                            Add courses on the planner to limit this list to yours.
                                                        </span>
                                                    )}
                                                </>
                                            )}
                                        </FormField>

                                        <FormField label="Title" htmlFor="mycal-event-title" className="mycal__form-row" wide>
                                            <input
                                                id="mycal-event-title"
                                                type="text"
                                                className="field"
                                                placeholder="e.g. Quiz 2"
                                                value={modalDraft.title}
                                                onChange={(e) =>
                                                    updateModalDraft((d) => ({ ...d, title: e.target.value }))
                                                }
                                                required
                                            />
                                        </FormField>

                                        <FormField as="fieldset" label="Schedule" className="mycal__form-row mycal__form-fieldset" wide>
                                            <div className="mycal__schedule-options">
                                                {EVENT_SCHEDULES.map((s) => (
                                                    <label
                                                        key={s}
                                                        className="mycal__schedule-option"
                                                        title={s === 'eod' ? 'End of day' : undefined}
                                                    >
                                                        <input
                                                            type="radio"
                                                            name="event-schedule"
                                                            value={s}
                                                            checked={modalDraft.schedule === s}
                                                            onChange={() =>
                                                                updateModalDraft((d) => ({ ...d, schedule: s }))
                                                            }
                                                        />
                                                        <span>{SCHEDULE_LABELS[s]}</span>
                                                    </label>
                                                ))}
                                            </div>
                                        </FormField>

                                        {modalDraft.schedule === 'at' && (
                                            <FormField label="At" htmlFor="mycal-event-at" className="mycal__form-row">
                                                <input
                                                    id="mycal-event-at"
                                                    type="time"
                                                    className="field field--mono"
                                                    value={hhmmToInput(modalDraft.time)}
                                                    onChange={(e) =>
                                                        updateModalDraft((d) => ({
                                                            ...d,
                                                            time: inputToHHMM(e.target.value),
                                                        }))
                                                    }
                                                    required
                                                />
                                            </FormField>
                                        )}

                                        {modalDraft.schedule === 'timed' && (
                                            <>
                                                <FormField label="From" htmlFor="mycal-event-from" className="mycal__form-row">
                                                    <input
                                                        id="mycal-event-from"
                                                        type="time"
                                                        className="field field--mono"
                                                        value={hhmmToInput(modalDraft.start)}
                                                        onChange={(e) =>
                                                            updateModalDraft((d) => ({
                                                                ...d,
                                                                start: inputToHHMM(e.target.value),
                                                            }))
                                                        }
                                                        required
                                                    />
                                                </FormField>
                                                <FormField label="To" htmlFor="mycal-event-to" className="mycal__form-row">
                                                    <input
                                                        id="mycal-event-to"
                                                        type="time"
                                                        className="field field--mono"
                                                        value={hhmmToInput(modalDraft.end)}
                                                        onChange={(e) =>
                                                            updateModalDraft((d) => ({
                                                                ...d,
                                                                end: inputToHHMM(e.target.value),
                                                            }))
                                                        }
                                                        required
                                                    />
                                                </FormField>
                                            </>
                                        )}

                                        <FormField label="Note (optional)" htmlFor="mycal-event-note" className="mycal__form-row" wide>
                                            <textarea
                                                id="mycal-event-note"
                                                className="field mycal__form-note"
                                                rows={2}
                                                placeholder="Room, syllabus, links…"
                                                value={modalDraft.note}
                                                onChange={(e) =>
                                                    updateModalDraft((d) => ({ ...d, note: e.target.value }))
                                                }
                                            />
                                        </FormField>
                                    </div>

                                    <div className="mycal__form-actions">
                                        {modalDraft.id && modalDraft.mode !== 'personal' && user && (
                                            <button
                                                type="button"
                                                className="btn btn--sm btn--ghost"
                                                onClick={() => setEventFormView('report')}
                                            >
                                                Report
                                            </button>
                                        )}
                                        {modalDraft.id && (
                                            <button
                                                type="button"
                                                className="btn btn--sm btn--danger-ghost"
                                                onClick={handleDelete}
                                            >
                                                Delete
                                            </button>
                                        )}
                                        <div className="mycal__form-actions-right">
                                            <button
                                                type="submit"
                                                className="btn btn--sm btn--primary"
                                                disabled={
                                                    saving ||
                                                    !modalDraft.title.trim() ||
                                                    (modalDraft.mode !== 'personal' &&
                                                        !modalDraft.courseCode.trim()) ||
                                                    !isDraftScheduleValid(modalDraft)
                                                }
                                            >
                                                {saving
                                                    ? 'Saving…'
                                                    : modalDraft.id
                                                      ? 'Save changes'
                                                      : modalDraft.mode === 'personal'
                                                        ? 'Add personal event'
                                                        : user
                                                          ? 'Add event'
                                                          : 'Log in to add'}
                                            </button>
                                        </div>
                                    </div>
                                </form>
                            )}
                        </div>
                </div>
            )}

            <section className="mycal__section">
                <div className="mycal__section-head">
                    <h2 className="mycal__h2">Upcoming</h2>
                    <span className="mycal__section-rule" aria-hidden="true" />
                </div>

                {upcoming.length === 0 ? (
                    <div className="empty">
                        <strong>Nothing scheduled.</strong>
                        Click a day above and choose course or personal event.
                    </div>
                ) : (
                    <ul className="mycal__list">
                        {upcoming.map((e) => {
                            const d = parseDateKey(e.date);
                            const when = formatEventSchedule(e);
                            return (
                                <li key={e.id} className="mycal__item">
                                    <span className="mycal__item-date mono">
                                        {fmtFull(d)}
                                        {when && (
                                            <span className="mycal__item-time">{when}</span>
                                        )}
                                    </span>
                                    <span className="mycal__item-main">
                                        <span
                                            className={
                                                'mycal__chip mycal__chip--inline' +
                                                (e.isPersonal
                                                    ? ' mycal__chip--personal'
                                                    : ` mycal__chip--${e.type}`)
                                            }
                                        >
                                            {e.isPersonal ? 'Personal' : TYPE_LABELS[e.type]}
                                        </span>
                                        {!e.isPersonal && e.courseCode && (
                                            <span className="badge badge--count mono">
                                                {e.courseCode}
                                            </span>
                                        )}
                                        <span className="mycal__item-title">{e.title}</span>
                                        {e.note && (
                                            <span className="mycal__item-note">{e.note}</span>
                                        )}
                                    </span>
                                    <span className="mycal__item-actions">
                                        {!e.isPersonal && user && (
                                            <button
                                                type="button"
                                                className="btn btn--sm btn--ghost"
                                                onClick={() => setReportingEvent(e)}
                                            >
                                                Report
                                            </button>
                                        )}
                                        <button
                                            type="button"
                                            className="btn btn--sm btn--ghost"
                                            onClick={() => openEdit(e)}
                                        >
                                            Edit
                                        </button>
                                        <button
                                            type="button"
                                            className="btn btn--sm btn--danger-ghost"
                                            onClick={() => handleDeleteFromList(e)}
                                            aria-label={`Delete ${e.title}`}
                                        >
                                            Delete
                                        </button>
                                    </span>
                                </li>
                            );
                        })}
                    </ul>
                )}
            </section>

            <p className="mycal__foot">
                Course events are shared with everyone in that course.
                Personal events are stored privately and only visible when you are logged in.
            </p>

            {reportingEvent && (
                <div
                    className="mycal__modal-backdrop"
                    onClick={closeReportDialog}
                    role="presentation"
                >
                    <div
                        ref={reportDialogRef}
                        className="mycal__modal mycal__modal--form panel"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="mycal-report-title"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div className="mycal__modal-head">
                            <h2 id="mycal-report-title" className="mycal__modal-title">
                                Report event
                            </h2>
                            <button
                                type="button"
                                className="btn btn--sm btn--ghost"
                                onClick={closeReportDialog}
                                aria-label="Close"
                            >
                                ×
                            </button>
                        </div>
                        <ReportContentPanel
                            compact
                            targetKind="course_event"
                            targetId={reportingEvent.id}
                            contextLabel={`${reportingEvent.courseCode} · ${reportingEvent.title} · ${reportingEvent.date}`}
                            onDone={closeReportDialog}
                            onCancel={closeReportDialog}
                        />
                    </div>
                </div>
            )}
        </div>
        </SemesterDataGate>
    );
}
