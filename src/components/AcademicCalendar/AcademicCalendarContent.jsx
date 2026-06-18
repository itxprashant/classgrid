import React, { useMemo } from 'react';
import {
    parseDateKey,
} from '../../utils/semesterSchedule';
import { useSemesterSchedule } from '../../data/SemesterDataContext';
import './AcademicCalendar.css';

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

function weekdayLong(date) {
    return date.toLocaleDateString('en-IN', { weekday: 'long' });
}

function statusOf(date, today, endDate) {
    const v = date.getTime();
    const t = today.getTime();
    if (v < t) return 'past';
    if (v === t) return 'today';
    if (endDate && endDate.getTime() < t) return 'past';
    return 'upcoming';
}

export default function AcademicCalendarContent({ embedded = false }) {
    const { schedule } = useSemesterSchedule();
    const today = todayMidnight();

    const SEMESTER = schedule?.SEMESTER || { label: '', classesStart: '', lastTeachingDay: '' };
    const HOLIDAYS = schedule?.HOLIDAYS || {};
    const SCHEDULE_EXCEPTIONS = schedule?.SCHEDULE_EXCEPTIONS || {};
    const NO_CLASS_PERIODS = schedule?.NO_CLASS_PERIODS || [];

    const start = SEMESTER.classesStart ? parseDateKey(SEMESTER.classesStart) : today;
    const end = SEMESTER.lastTeachingDay ? parseDateKey(SEMESTER.lastTeachingDay) : today;

    const changes = useMemo(
        () =>
            Object.entries(SCHEDULE_EXCEPTIONS)
                .map(([key, effectiveDay]) => {
                    const date = parseDateKey(key);
                    return { key, date, effectiveDay, realDay: weekdayLong(date) };
                })
                .sort((a, b) => a.date - b.date),
        [SCHEDULE_EXCEPTIONS]
    );

    const holidays = useMemo(
        () =>
            Object.entries(HOLIDAYS)
                .map(([key, name]) => ({ key, date: parseDateKey(key), name }))
                .sort((a, b) => a.date - b.date),
        [HOLIDAYS]
    );

    const periods = useMemo(
        () =>
            NO_CLASS_PERIODS.map((p) => ({
                ...p,
                startDate: parseDateKey(p.start),
                endDate: parseDateKey(p.end),
            })).sort((a, b) => a.startDate - b.startDate),
        [NO_CLASS_PERIODS]
    );

    const nextKey = useMemo(() => {
        const upcoming = [...holidays, ...changes]
            .filter((e) => e.date.getTime() >= today.getTime())
            .sort((a, b) => a.date - b.date);
        return upcoming.length ? upcoming[0].key : null;
    }, [holidays, changes, today]);

    if (!schedule) {
        return (
            <div className="cal">
                <p className="muted">Loading academic calendar…</p>
            </div>
        );
    }

    return (
        <div className={'cal' + (embedded ? ' cal--embedded' : '')}>
            {!embedded && (
                <header className="cal__head">
                    <div className="cal__eyebrow">Academic calendar</div>
                    <h1 className="cal__title">
                        Holidays &amp; <em>timetable changes</em>.
                    </h1>
                    <p className="cal__sub">
                        {SEMESTER.label} · classes {fmtFull(start)} → {fmtFull(end)}. Holidays,
                        working-day swaps and breaks all flow into the planner, the calendar export
                        and the free-halls finder.
                    </p>
                </header>
            )}

            {embedded && (
                <p className="cal__sub cal__sub--embedded">
                    {SEMESTER.label} · classes {fmtFull(start)} → {fmtFull(end)}.
                </p>
            )}

            <div className="cal__summary">
                <div className="cal__summary-card">
                    <span className="cal__summary-label">Classes begin</span>
                    <span className="cal__summary-value mono">{fmtFull(start)}</span>
                </div>
                <div className="cal__summary-card">
                    <span className="cal__summary-label">Last teaching day</span>
                    <span className="cal__summary-value mono">{fmtFull(end)}</span>
                </div>
                <div className="cal__summary-card">
                    <span className="cal__summary-label">Holidays</span>
                    <span className="cal__summary-value tnum">{holidays.length}</span>
                </div>
                <div className="cal__summary-card">
                    <span className="cal__summary-label">Timetable swaps</span>
                    <span className="cal__summary-value tnum">{changes.length}</span>
                </div>
            </div>

            <section className="cal__section">
                <div className="cal__section-head">
                    <h2 className="cal__h2">Timetable changes</h2>
                    <span className="cal__section-rule" aria-hidden="true" />
                </div>
                <p className="cal__section-note">
                    Days the institute runs a different day&apos;s timetable.
                </p>
                <ul className="cal__list">
                    {changes.map((c) => {
                        const st = statusOf(c.date, today);
                        return (
                            <li
                                key={c.key}
                                className={
                                    'cal__item cal__item--swap' +
                                    (c.key === nextKey ? ' cal__item--next' : '') +
                                    (st === 'past' ? ' cal__item--past' : '')
                                }
                            >
                                <span className="cal__item-date mono">{fmtFull(c.date)}</span>
                                <span className="cal__item-main">
                                    <span className="cal__swap">
                                        {c.realDay} <span className="cal__swap-arrow">→</span>{' '}
                                        <strong>{c.effectiveDay}</strong> timetable
                                    </span>
                                </span>
                                <span className={`cal__chip cal__chip--${st}`}>{st}</span>
                            </li>
                        );
                    })}
                </ul>
            </section>

            <section className="cal__section">
                <div className="cal__section-head">
                    <h2 className="cal__h2">Holidays</h2>
                    <span className="cal__section-rule" aria-hidden="true" />
                </div>
                <p className="cal__section-note">No classes on these days.</p>
                <ul className="cal__list">
                    {holidays.map((h) => {
                        const st = statusOf(h.date, today);
                        return (
                            <li
                                key={h.key}
                                className={
                                    'cal__item cal__item--holiday' +
                                    (h.key === nextKey ? ' cal__item--next' : '') +
                                    (st === 'past' ? ' cal__item--past' : '')
                                }
                            >
                                <span className="cal__item-date mono">{fmtFull(h.date)}</span>
                                <span className="cal__item-main">{h.name}</span>
                                <span className={`cal__chip cal__chip--${st}`}>{st}</span>
                            </li>
                        );
                    })}
                </ul>
            </section>

            <section className="cal__section">
                <div className="cal__section-head">
                    <h2 className="cal__h2">Breaks &amp; examinations</h2>
                    <span className="cal__section-rule" aria-hidden="true" />
                </div>
                <p className="cal__section-note">Periods with no regular timetabled classes.</p>
                <ul className="cal__list">
                    {periods.map((p) => {
                        const st = statusOf(p.startDate, today, p.endDate);
                        return (
                            <li
                                key={p.name}
                                className={
                                    'cal__item cal__item--break' +
                                    (st === 'past' ? ' cal__item--past' : '')
                                }
                            >
                                <span className="cal__item-date mono">
                                    {fmtFull(p.startDate)} – {fmtFull(p.endDate)}
                                </span>
                                <span className="cal__item-main">{p.name}</span>
                                <span className={`cal__chip cal__chip--${st}`}>{st}</span>
                            </li>
                        );
                    })}
                </ul>
            </section>

            <p className="cal__foot">
                In the event of a government-announced change of holiday, the institute observes the
                holiday accordingly and the working day created in lieu runs as per the timetable of
                the day of the holiday. Verify against the official IITD academic calendar.
            </p>
        </div>
    );
}
