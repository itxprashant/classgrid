import React, { useState, useEffect, useRef, useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import html2canvas from 'html2canvas-pro';
import './Generator.css';
import coursesData from '../courses.json';
import TimetableGrid from '../components/Timetable/TimetableGrid';
import EditTiming from '../components/FullTimetable/EditTiming';
import AcademicCalendarButton from '../components/AcademicCalendar/AcademicCalendarButton';
import { useAuth, apiFetch } from '../auth/AuthContext';
import { fetchPlan, savePlan } from '../utils/plannerApi';
import { SEMESTER, getAcademicDay, parseDateKey } from '../utils/semesterSchedule';

function parseTimingStr(timingStr) {
    if (!timingStr) return [];
    const timings = timingStr.split(',');
    return timings.map((t) => {
        const dayCode = t[0];
        const start = t.slice(1, 5);
        const end = t.slice(5, 9);
        const days = { 1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday' };
        return { day: days[dayCode], start, end };
    });
}

function toMinutes(t) {
    return parseInt(t.substring(0, 2), 10) * 60 + parseInt(t.substring(2, 4), 10);
}

// Semester metadata is sourced from src/utils/semesterSchedule.js so the
// planner, free-room finder and ICS export all share one calendar.
const SEMESTER_LABEL = SEMESTER.label; // e.g. "Semester 1, 2026–2027"
const SEMESTER_START = parseDateKey(SEMESTER.classesStart); // Commencement of classes
const SEMESTER_END = parseDateKey(SEMESTER.lastTeachingDay); // Last teaching day

const DAY_TO_WEEKDAY = {
    Monday: 1,
    Tuesday: 2,
    Wednesday: 3,
    Thursday: 4,
    Friday: 5,
};

function pad2(n) {
    return n.toString().padStart(2, '0');
}

function firstDateOnOrAfter(startDate, weekday) {
    const d = new Date(startDate);
    const diff = (weekday - d.getDay() + 7) % 7;
    d.setDate(d.getDate() + diff);
    return d;
}

function formatDateYMD(date) {
    return `${date.getFullYear()}${pad2(date.getMonth() + 1)}${pad2(date.getDate())}`;
}

function formatUtcStamp(date) {
    return (
        `${date.getUTCFullYear()}${pad2(date.getUTCMonth() + 1)}${pad2(date.getUTCDate())}` +
        `T${pad2(date.getUTCHours())}${pad2(date.getUTCMinutes())}${pad2(date.getUTCSeconds())}Z`
    );
}

function escapeIcsText(text) {
    return String(text)
        .replace(/\\/g, '\\\\')
        .replace(/;/g, '\\;')
        .replace(/,/g, '\\,')
        .replace(/\n/g, '\\n');
}

export default function Generator() {
    const [allCourses, setAllCourses] = useState([]);
    const [selectedCourses, setSelectedCourses] = useState(() => {
        try {
            const saved = localStorage.getItem('selectedCourses');
            return saved ? JSON.parse(saved) : [];
        } catch (e) {
            return [];
        }
    });
    const [searchQuery, setSearchQuery] = useState('');
    const [showAddCourse, setShowAddCourse] = useState(false);
    const [timetableData, setTimetableData] = useState(() => {
        try {
            const saved = localStorage.getItem('timetableData');
            return saved ? JSON.parse(saved) : {};
        } catch (e) {
            return {};
        }
    });
    const [expandedCourse, setExpandedCourse] = useState(null);

    const [autoFetchLoading, setAutoFetchLoading] = useState(false);
    const [showAutoFetchConfirm, setShowAutoFetchConfirm] = useState(false);
    const [oauthBanner, setOauthBanner] = useState(null);

    const timetableRef = useRef(null);
    const addCourseInputRef = useRef(null);
    const oauthLoadRef = useRef(false);
    const planSaveTimerRef = useRef(null);
    const skipNextSaveRef = useRef(false);

    const [planReady, setPlanReady] = useState(false);

    const { user, loading: authLoading, login } = useAuth();
    const location = useLocation();
    const navigate = useNavigate();

    useEffect(() => {
        setAllCourses(coursesData);
    }, []);

    useEffect(() => {
        localStorage.setItem('selectedCourses', JSON.stringify(selectedCourses));
        localStorage.setItem('timetableData', JSON.stringify(timetableData));
    }, [selectedCourses, timetableData]);

    // Load saved plan from DB when signed in; debounced save on changes.
    useEffect(() => {
        if (authLoading) return undefined;

        const params = new URLSearchParams(location.search);
        const isLoginSuccess = params.get('login') === 'success';

        const cleanLoginUrl = () => {
            if (!isLoginSuccess) return;
            params.delete('login');
            const qs = params.toString();
            navigate({ pathname: location.pathname, search: qs ? `?${qs}` : '' }, { replace: true });
        };

        if (!user) {
            setPlanReady(true);
            if (isLoginSuccess) {
                setOauthBanner({ kind: 'err', text: 'Login was not completed. Please try again.' });
                cleanLoginUrl();
            }
            return undefined;
        }

        setPlanReady(false);
        let cancelled = false;

        (async () => {
            let savedPlan = { selectedCourses: [], timetableData: {} };
            try {
                savedPlan = await fetchPlan();
                if (cancelled) return;

                const hasSaved =
                    savedPlan.selectedCourses.length > 0 ||
                    Object.keys(savedPlan.timetableData).length > 0;

                if (hasSaved) {
                    skipNextSaveRef.current = true;
                    setSelectedCourses(savedPlan.selectedCourses);
                    setTimetableData(savedPlan.timetableData);
                }
            } catch (e) {
                if (!cancelled) {
                    setOauthBanner({ kind: 'err', text: `Could not load your saved plan: ${e.message}` });
                }
            }

            if (cancelled) return;

            if (isLoginSuccess && !oauthLoadRef.current) {
                oauthLoadRef.current = true;
                cleanLoginUrl();

                const hasSaved =
                    savedPlan.selectedCourses.length > 0 ||
                    Object.keys(savedPlan.timetableData).length > 0;

                if (hasSaved) {
                    setOauthBanner({
                        kind: 'ok',
                        text: 'Restored your saved timetable.',
                    });
                } else {
                    try {
                        const res = await apiFetch('/api/me/courses');
                        if (!res.ok) throw new Error(`HTTP ${res.status}`);
                        const data = await res.json();
                        const codes = Array.isArray(data.courses) ? data.courses : [];
                        await replaceUserPlan(codes, user.name || user.kerberos, { persist: true });
                    } catch (e) {
                        setOauthBanner({ kind: 'err', text: `Could not load your courses: ${e.message}` });
                    }
                }
            }

            if (!cancelled) setPlanReady(true);
        })();

        return () => {
            cancelled = true;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [authLoading, user, location.search]);

    useEffect(() => {
        if (!user || !planReady) return undefined;

        if (skipNextSaveRef.current) {
            skipNextSaveRef.current = false;
            return undefined;
        }

        clearTimeout(planSaveTimerRef.current);
        planSaveTimerRef.current = setTimeout(() => {
            savePlan({ selectedCourses, timetableData }).catch(() => {
                // Best-effort — localStorage still holds a copy.
            });
        }, 800);

        return () => clearTimeout(planSaveTimerRef.current);
    }, [selectedCourses, timetableData, user, planReady]);

    const buildPlanFromCodes = (courseCodes) => {
        const newCourses = [];
        const newTimetableUpdates = {};

        courseCodes.forEach((courseCode) => {
            if (newCourses.find((c) => c.courseCode === courseCode)) return;

            const course = allCourses.find((c) => c.courseCode === courseCode);
            if (!course) return;

            newTimetableUpdates[courseCode] = {
                lecture: parseTimingStr(course.slot.lectureTiming),
                tutorial: null,
                lab: null,
            };

            newCourses.push({
                courseCode: course.courseCode,
                courseName: course.courseName,
                instructor: course.instructor,
                lecture: !!course.slot.lectureTiming,
                tutorial: course.creditStructure.split('-')[1] !== '0.0',
                lab: course.creditStructure.split('-')[2] !== '0.0',
                lectureTiming: parseTimingStr(course.slot.lectureTiming),
                tutorialTiming: parseTimingStr(course.slot.tutorialTiming),
                labTiming: parseTimingStr(course.slot.labTiming),
                creditStructure: course.creditStructure,
                totalCredits: course.totalCredits,
                lectureHall: course.lectureHall,
            });
        });

        return { selectedCourses: newCourses, timetableData: newTimetableUpdates };
    };

    const replaceUserPlan = async (courseCodes, accountLabel, { persist = false } = {}) => {
        const plan = buildPlanFromCodes(courseCodes);
        skipNextSaveRef.current = true;
        setSelectedCourses(plan.selectedCourses);
        setTimetableData(plan.timetableData);
        setExpandedCourse(null);
        setSearchQuery('');

        if (persist && user) {
            await savePlan(plan);
        }

        if (courseCodes.length === 0) {
            setOauthBanner({
                kind: 'warn',
                text: accountLabel
                    ? `No registered courses were found for ${accountLabel}. Your plan was cleared.`
                    : 'No registered courses were found. Your plan was cleared.',
            });
            return;
        }

        setOauthBanner({
            kind: 'ok',
            text: accountLabel
                ? `Loaded ${courseCodes.length} course${courseCodes.length === 1 ? '' : 's'} for ${accountLabel}.`
                : `Loaded ${courseCodes.length} course${courseCodes.length === 1 ? '' : 's'}.`,
        });
    };

    const addCourses = (courseCodes, clearExisting = false) => {
        if (clearExisting) {
            replaceUserPlan(courseCodes, '', { persist: false });
            return;
        }

        const plan = buildPlanFromCodes(courseCodes);
        const freshCodes = plan.selectedCourses.filter(
            (c) => !selectedCourses.find((s) => s.courseCode === c.courseCode)
        );
        if (freshCodes.length === 0) return;

        const additions = buildPlanFromCodes(freshCodes.map((c) => c.courseCode));
        setTimetableData((prev) => ({ ...prev, ...additions.timetableData }));
        setSelectedCourses((prev) => [...prev, ...additions.selectedCourses]);
        setSearchQuery('');
    };

    const applyUserCourseCodes = (codes, accountLabel, options) =>
        replaceUserPlan(codes, accountLabel, options);

    const refreshUserCourses = async () => {
        setAutoFetchLoading(true);
        try {
            const res = await apiFetch('/api/me/courses');
            if (!res.ok) {
                throw new Error(`HTTP ${res.status}`);
            }
            const data = await res.json();
            const codes = Array.isArray(data.courses) ? data.courses : [];
            const label = user?.name || user?.kerberos || '';
            await replaceUserPlan(codes, label, { persist: true });
        } catch (e) {
            setOauthBanner({ kind: 'err', text: `Could not load your courses: ${e.message}` });
        } finally {
            setAutoFetchLoading(false);
        }
    };

    const addCourse = (courseCode) => addCourses([courseCode]);

    const removeCourse = (courseCode) => {
        setSelectedCourses(selectedCourses.filter((c) => c.courseCode !== courseCode));
        const newData = { ...timetableData };
        delete newData[courseCode];
        setTimetableData(newData);
        if (expandedCourse === courseCode) setExpandedCourse(null);
    };

    const toggleExpand = (courseCode) => {
        setExpandedCourse(expandedCourse === courseCode ? null : courseCode);
    };

    const closeAutoFetchConfirm = () => {
        setShowAutoFetchConfirm(false);
    };

    const confirmAutoFetch = () => {
        setShowAutoFetchConfirm(false);
        refreshUserCourses();
    };

    const handleAutoFetch = () => {
        if (authLoading || autoFetchLoading) return;
        if (!user) {
            login();
            return;
        }
        setShowAutoFetchConfirm(true);
    };

    const generateICS = () => {
        const CRLF = '\r\n';
        const lines = [];
        lines.push('BEGIN:VCALENDAR');
        lines.push('VERSION:2.0');
        lines.push('PRODID:-//IITD Timetable//EN');
        lines.push('CALSCALE:GREGORIAN');
        lines.push('METHOD:PUBLISH');

        // Fixed-offset VTIMEZONE for Asia/Kolkata (no DST).
        lines.push('BEGIN:VTIMEZONE');
        lines.push('TZID:Asia/Kolkata');
        lines.push('BEGIN:STANDARD');
        lines.push('DTSTART:19700101T000000');
        lines.push('TZOFFSETFROM:+0530');
        lines.push('TZOFFSETTO:+0530');
        lines.push('TZNAME:IST');
        lines.push('END:STANDARD');
        lines.push('END:VTIMEZONE');

        const dtstamp = formatUtcStamp(new Date());
        // UNTIL is end of SEMESTER_END day in IST, expressed in UTC (23:59:59 IST = 18:29:59 UTC).
        const untilDate = new Date(Date.UTC(
            SEMESTER_END.getFullYear(),
            SEMESTER_END.getMonth(),
            SEMESTER_END.getDate(),
            18, 29, 59
        ));
        const untilStr = formatUtcStamp(untilDate);

        // Walk the teaching term once to find, per weekday (1=Mon … 5=Fri):
        //  - exdates: dates a normal class is cancelled (holidays, breaks, exam
        //    weeks, and days swapped to another weekday's timetable)
        //  - swapExtras: one-off dates where this weekday's timetable runs on a
        //    different calendar day (e.g. a Saturday running the Wednesday plan)
        const exdatesByWeekday = { 1: [], 2: [], 3: [], 4: [], 5: [] };
        const swapExtrasByWeekday = { 1: [], 2: [], 3: [], 4: [], 5: [] };
        const cursor = new Date(SEMESTER_START);
        while (cursor <= SEMESTER_END) {
            const info = getAcademicDay(cursor);
            const dow = cursor.getDay(); // Sun=0 … Sat=6; Mon–Fri == day code
            if (info.type === 'holiday' || info.type === 'break') {
                if (dow >= 1 && dow <= 5) exdatesByWeekday[dow].push(formatDateYMD(cursor));
            } else if (info.type === 'swapped') {
                if (dow >= 1 && dow <= 5) exdatesByWeekday[dow].push(formatDateYMD(cursor));
                if (info.effectiveDayCode) {
                    swapExtrasByWeekday[info.effectiveDayCode].push(formatDateYMD(cursor));
                }
            }
            cursor.setDate(cursor.getDate() + 1);
        }

        selectedCourses.forEach((course) => {
            const data = timetableData[course.courseCode];
            if (!data) return;
            const events = [];
            if (data.lecture) events.push(...data.lecture.map((e) => ({ ...e, type: 'Lecture' })));
            if (data.tutorial) events.push(...data.tutorial.map((e) => ({ ...e, type: 'Tutorial' })));
            if (data.lab) events.push(...data.lab.map((e) => ({ ...e, type: 'Lab' })));
            events.forEach((event) => {
                const weekday = DAY_TO_WEEKDAY[event.day];
                if (!weekday) return;
                const firstDate = firstDateOnOrAfter(SEMESTER_START, weekday);
                const datePart = formatDateYMD(firstDate);
                const startTime = `${event.start.slice(0, 2)}${event.start.slice(2, 4)}00`;
                const endTime = `${event.end.slice(0, 2)}${event.end.slice(2, 4)}00`;
                const loc = event.location || course.lectureHall || '';
                const byday = event.day.slice(0, 2).toUpperCase();
                const summary = `${course.courseCode} ${event.type}${loc ? ` (${loc})` : ''}`;
                const uid = `${course.courseCode}-${event.type}-${event.day}-${event.start}@iitd-timetable`;

                lines.push('BEGIN:VEVENT');
                lines.push(`UID:${uid}`);
                lines.push(`DTSTAMP:${dtstamp}`);
                lines.push(`SUMMARY:${escapeIcsText(summary)}`);
                lines.push(`DTSTART;TZID=Asia/Kolkata:${datePart}T${startTime}`);
                lines.push(`DTEND;TZID=Asia/Kolkata:${datePart}T${endTime}`);
                lines.push(`RRULE:FREQ=WEEKLY;BYDAY=${byday};UNTIL=${untilStr}`);
                const exdates = exdatesByWeekday[weekday] || [];
                if (exdates.length > 0) {
                    const exVals = exdates.map((d) => `${d}T${startTime}`).join(',');
                    lines.push(`EXDATE;TZID=Asia/Kolkata:${exVals}`);
                }
                if (loc) lines.push(`LOCATION:${escapeIcsText(loc)}`);
                lines.push('END:VEVENT');

                // Extra one-off sessions created by working-day swaps.
                const extras = swapExtrasByWeekday[weekday] || [];
                extras.forEach((d) => {
                    lines.push('BEGIN:VEVENT');
                    lines.push(`UID:${course.courseCode}-${event.type}-swap-${d}-${event.start}@iitd-timetable`);
                    lines.push(`DTSTAMP:${dtstamp}`);
                    lines.push(`SUMMARY:${escapeIcsText(summary)}`);
                    lines.push(`DTSTART;TZID=Asia/Kolkata:${d}T${startTime}`);
                    lines.push(`DTEND;TZID=Asia/Kolkata:${d}T${endTime}`);
                    if (loc) lines.push(`LOCATION:${escapeIcsText(loc)}`);
                    lines.push('END:VEVENT');
                });
            });
        });

        lines.push('END:VCALENDAR');
        const ics = lines.join(CRLF) + CRLF;

        const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'iitd-timetable.ics';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(() => URL.revokeObjectURL(url), 0);
    };

    const handleDownloadImage = async () => {
        if (!timetableRef.current) return;
        const scrollContainer = timetableRef.current.querySelector('.tt');
        if (!scrollContainer) return;
        const w = scrollContainer.scrollWidth;
        const h = scrollContainer.scrollHeight;
        try {
            const canvas = await html2canvas(timetableRef.current, {
                scale: 2,
                backgroundColor: '#FBF9F4',
                logging: false,
                useCORS: true,
                width: w,
                height: h,
                windowWidth: w,
                windowHeight: h,
                onclone: (clonedDoc) => {
                    const node = clonedDoc.querySelector('.tt');
                    if (node) {
                        node.style.overflow = 'visible';
                        node.style.width = w + 'px';
                        node.style.height = h + 'px';
                        node.style.maxWidth = 'none';
                        node.style.maxHeight = 'none';
                    }
                },
            });
            const link = document.createElement('a');
            link.href = canvas.toDataURL('image/png');
            link.download = 'iitd-timetable.png';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (err) {
            console.error('Error downloading image:', err);
        }
    };

    const filteredCourses = useMemo(() => {
        if (!searchQuery) return [];
        return allCourses
            .filter((c) => c.courseCode.includes(searchQuery.toUpperCase()))
            .slice(0, 10);
    }, [searchQuery, allCourses]);

    // Stats: total credits and conflict count
    const stats = useMemo(() => {
        let credits = 0;
        const sessions = [];
        selectedCourses.forEach((course) => {
            credits += parseFloat(course.totalCredits || 0) || 0;
            const cd = timetableData[course.courseCode];
            if (!cd) return;
            ['lecture', 'tutorial', 'lab'].forEach((k) => {
                if (cd[k]) {
                    cd[k].forEach((s) => {
                        if (s && s.day && s.start && s.end) {
                            sessions.push({ ...s, courseCode: course.courseCode });
                        }
                    });
                }
            });
        });
        let conflicts = 0;
        for (let i = 0; i < sessions.length; i++) {
            for (let j = i + 1; j < sessions.length; j++) {
                const a = sessions[i];
                const b = sessions[j];
                if (a.day !== b.day || a.courseCode === b.courseCode) continue;
                if (toMinutes(a.start) < toMinutes(b.end) && toMinutes(b.start) < toMinutes(a.end)) {
                    conflicts++;
                }
            }
        }
        return { credits, conflicts };
    }, [selectedCourses, timetableData]);

    const openAddCourse = () => {
        setSearchQuery('');
        setShowAddCourse(true);
    };

    const closeAddCourse = () => {
        setShowAddCourse(false);
        setSearchQuery('');
    };

    // Close add-course dialog on Escape; focus search when it opens.
    useEffect(() => {
        if (!showAddCourse) return undefined;
        const t = window.setTimeout(() => addCourseInputRef.current?.focus(), 0);
        const onKey = (e) => {
            if (e.key === 'Escape') closeAddCourse();
        };
        document.addEventListener('keydown', onKey);
        return () => {
            window.clearTimeout(t);
            document.removeEventListener('keydown', onKey);
        };
    }, [showAddCourse]);

    useEffect(() => {
        if (!showAutoFetchConfirm) return undefined;
        const onKey = (e) => {
            if (e.key === 'Escape') closeAutoFetchConfirm();
        };
        document.addEventListener('keydown', onKey);
        return () => document.removeEventListener('keydown', onKey);
    }, [showAutoFetchConfirm]);

    return (
        <section className="gen">
            <header className="gen__head">
                <div className="gen__head-text">
                    <div className="gen__eyebrow">IIT Delhi · {SEMESTER_LABEL}</div>
                    <h1 className="gen__title">
                        Build your <em>week</em>, the way it actually fits.
                    </h1>
                    <p className="gen__sub">
                        Search courses, configure your tutorials and labs, catch conflicts, and export
                        the result to your calendar or as an image.
                    </p>
                </div>

                <div className="gen__stats" aria-label="Schedule summary">
                    <div className="gen__stat">
                        <span className="gen__stat-label">Courses</span>
                        <span className="gen__stat-value tnum">{selectedCourses.length}</span>
                    </div>
                    <div className="gen__stat">
                        <span className="gen__stat-label">Credits</span>
                        <span className="gen__stat-value tnum">{stats.credits.toFixed(1)}</span>
                    </div>
                    <div className="gen__stat">
                        <span className="gen__stat-label">Conflicts</span>
                        <span className={'gen__stat-value tnum' + (stats.conflicts > 0 ? ' gen__stat-value--warn' : '')}>
                            {stats.conflicts}
                        </span>
                    </div>
                </div>
            </header>

            <div className="gen__toolbar">
                <button
                    type="button"
                    className="btn btn--primary gen__add-course-btn"
                    onClick={openAddCourse}
                >
                    <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <line x1="12" y1="5" x2="12" y2="19" />
                        <line x1="5" y1="12" x2="19" y2="12" />
                    </svg>
                    Add course
                </button>

                <button
                    type="button"
                    className="btn gen__autofetch-toggle"
                    onClick={handleAutoFetch}
                    disabled={authLoading || autoFetchLoading}
                >
                    <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                    {autoFetchLoading ? 'Fetching…' : 'Auto-fetch'}
                </button>

                <AcademicCalendarButton />
            </div>

            {showAutoFetchConfirm && (
                <div
                    className="gen__dialog-backdrop"
                    onClick={closeAutoFetchConfirm}
                    role="presentation"
                >
                    <div
                        className="gen__dialog panel gen__dialog--confirm"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="gen-autofetch-title"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <h2 id="gen-autofetch-title" className="gen__dialog-title">
                            Replace your planner?
                        </h2>
                        <p className="gen__dialog-hint">
                            Auto-fetch will clear your current courses and tutorial/lab timings,
                            then load your registered courses from IIT Delhi.
                        </p>
                        <div className="gen__dialog-actions">
                            <button
                                type="button"
                                className="btn btn--ghost"
                                onClick={closeAutoFetchConfirm}
                            >
                                Cancel
                            </button>
                            <button
                                type="button"
                                className="btn btn--primary"
                                onClick={confirmAutoFetch}
                                autoFocus
                            >
                                OK
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {showAddCourse && (
                <div
                    className="gen__dialog-backdrop"
                    onClick={closeAddCourse}
                    role="presentation"
                >
                    <div
                        className="gen__dialog panel"
                        role="dialog"
                        aria-modal="true"
                        aria-labelledby="gen-add-course-title"
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div className="gen__dialog-head">
                            <h2 id="gen-add-course-title" className="gen__dialog-title">
                                Add course
                            </h2>
                            <button
                                type="button"
                                className="btn btn--sm btn--ghost"
                                onClick={closeAddCourse}
                                aria-label="Close"
                            >
                                ×
                            </button>
                        </div>

                        <div className="gen__search gen__search--dialog">
                            <span className="gen__search-icon" aria-hidden="true">
                                <svg width="18" height="18" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                                </svg>
                            </span>
                            <input
                                ref={addCourseInputRef}
                                type="text"
                                className="gen__search-input"
                                placeholder="Search by course code (COL106, ELL201, MTL106…)"
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                            />
                        </div>

                        {searchQuery && filteredCourses.length > 0 && (
                            <div className="gen__results gen__results--dialog" role="listbox">
                                {filteredCourses.map((c) => (
                                    <div
                                        key={c.courseCode}
                                        className="gen__result"
                                        role="option"
                                        aria-selected={false}
                                        tabIndex={0}
                                        onClick={() => addCourse(c.courseCode)}
                                        onKeyDown={(e) => {
                                            if (e.key === 'Enter') addCourse(c.courseCode);
                                        }}
                                    >
                                        <div>
                                            <span className="gen__result-code">{c.courseCode}</span>
                                            {c.lectureHall && (
                                                <span className="gen__result-loc">{c.lectureHall}</span>
                                            )}
                                        </div>
                                        <span className="gen__result-credits">{c.creditStructure}</span>
                                    </div>
                                ))}
                            </div>
                        )}

                        {searchQuery && filteredCourses.length === 0 && (
                            <p className="gen__dialog-empty">No courses match that code.</p>
                        )}

                        {!searchQuery && (
                            <p className="gen__dialog-hint">
                                Type a course code to search the semester catalog.
                            </p>
                        )}
                    </div>
                </div>
            )}

            {oauthBanner && (
                <div
                    className={
                        'gen__oauth-banner' +
                        (oauthBanner.kind === 'ok' ? ' gen__oauth-banner--ok' : '') +
                        (oauthBanner.kind === 'warn' ? ' gen__oauth-banner--warn' : '') +
                        (oauthBanner.kind === 'err' ? ' gen__oauth-banner--err' : '')
                    }
                    role="status"
                >
                    <span>{oauthBanner.text}</span>
                    <button
                        type="button"
                        className="gen__oauth-banner-close"
                        onClick={() => setOauthBanner(null)}
                        aria-label="Dismiss"
                    >
                        ×
                    </button>
                </div>
            )}

            <div className="gen__main">
                <div className="gen__col-board" ref={timetableRef}>
                    <TimetableGrid timetable={selectedCourses} timetableData={timetableData} />

                    <div className="gen__legend" aria-label="Legend">
                        <span className="gen__legend-item">
                            <span className="gen__legend-swatch gen__legend-swatch--lec" /> Lecture
                        </span>
                        <span className="gen__legend-item">
                            <span className="gen__legend-swatch gen__legend-swatch--tut" /> Tutorial
                        </span>
                        <span className="gen__legend-item">
                            <span className="gen__legend-swatch gen__legend-swatch--lab" /> Lab
                        </span>
                        <span className="gen__legend-item">
                            <span className="gen__legend-swatch gen__legend-swatch--conf" /> Conflict
                        </span>
                    </div>

                    {stats.conflicts > 0 && (
                        <div className="gen__conflict" role="alert">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                <circle cx="12" cy="12" r="10" />
                                <line x1="12" y1="8" x2="12" y2="12" />
                                <line x1="12" y1="16" x2="12.01" y2="16" />
                            </svg>
                            <span>
                                {stats.conflicts} overlap{stats.conflicts === 1 ? '' : 's'} detected — adjust tutorial/lab timings to resolve.
                            </span>
                        </div>
                    )}
                </div>

                <aside className="gen__col-side">
                    <div className="gen__side-head">
                        <h2 className="gen__side-title">
                            Selected
                            <span className="gen__side-count tnum">{selectedCourses.length.toString().padStart(2, '0')}</span>
                        </h2>
                    </div>

                    {selectedCourses.length > 0 && (
                        <div className="gen__actions">
                            <button className="btn btn--primary" onClick={generateICS}>
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                                    <line x1="16" y1="2" x2="16" y2="6" />
                                    <line x1="8" y1="2" x2="8" y2="6" />
                                    <line x1="3" y1="10" x2="21" y2="10" />
                                </svg>
                                Export .ics
                            </button>
                            <button className="btn" onClick={handleDownloadImage}>
                                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                                    <polyline points="7 10 12 15 17 10" />
                                    <line x1="12" y1="15" x2="12" y2="3" />
                                </svg>
                                Save image
                            </button>
                        </div>
                    )}

                    {selectedCourses.length === 0 ? (
                        <div className="gen__empty">
                            <div className="gen__empty-title">No courses yet</div>
                            <div className="gen__empty-sub">
                                Use Add course or auto-fetch to start building your week.
                            </div>
                        </div>
                    ) : (
                        <div className="gen__course-list">
                            {selectedCourses.map((course) => {
                                const isExpanded = expandedCourse === course.courseCode;
                                return (
                                    <div key={course.courseCode} className="gen__course">
                                        <div className="gen__course-row">
                                            <div className="gen__course-info">
                                                <span className="gen__course-code">{course.courseCode}</span>
                                                <span className="gen__course-meta">
                                                    <span>{course.creditStructure}</span>
                                                    {course.lectureHall && (
                                                        <>
                                                            <span className="gen__course-meta-dot" />
                                                            <span>{course.lectureHall}</span>
                                                        </>
                                                    )}
                                                </span>
                                            </div>
                                            <div className="gen__course-actions">
                                                <button
                                                    className="btn btn--sm btn--ghost"
                                                    onClick={() => toggleExpand(course.courseCode)}
                                                    aria-expanded={isExpanded}
                                                >
                                                    {isExpanded ? 'Done' : 'Edit'}
                                                </button>
                                                <button
                                                    className="btn btn--sm btn--icon btn--danger-ghost"
                                                    onClick={() => removeCourse(course.courseCode)}
                                                    title="Remove"
                                                    aria-label={`Remove ${course.courseCode}`}
                                                >
                                                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                                        <line x1="5" y1="12" x2="19" y2="12" />
                                                    </svg>
                                                </button>
                                            </div>
                                        </div>

                                        {isExpanded && (
                                            <div className="gen__course-edit">
                                                <EditTiming
                                                    div_id={`edit-${course.courseCode}`}
                                                    data={course}
                                                    timetableData={timetableData}
                                                    setTimetableData={setTimetableData}
                                                />
                                            </div>
                                        )}
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </aside>
            </div>
        </section>
    );
}
