import React, { useMemo, useState, useEffect } from 'react';
import { useParams, Link, Navigate } from 'react-router-dom';
import { useAuth, apiFetch } from '../auth/AuthContext';
import { useSemesterData } from '../data/SemesterDataContext';
import SemesterDataGate from '../data/SemesterDataGate';
import { fetchCourseOfferings, offeringTimingSummary, offeringToCourse, sortOfferingsBySemesterDesc } from '../utils/historyApi';
import { courseOfferingPath } from '../utils/courseRoutes';
import { instructorsFromCourse } from '../utils/instructors';
import InstructorLinks from '../components/InstructorLinks/InstructorLinks';
import PlanToggle from '../components/PlanToggle/PlanToggle';
import CoursePolicySection from '../components/CoursePolicy/CoursePolicySection';
import { useCoursePlan } from '../hooks/useCoursePlan';
import './CourseDetails.css';

export default function CourseDetails() {
    const { courseCode } = useParams();
    const { user } = useAuth();
    const { courses, explorerCourses } = useSemesterData();
    const [offerings, setOfferings] = useState([]);
    const [offeringsLoading, setOfferingsLoading] = useState(true);
    const [offeringsError, setOfferingsError] = useState(null);
    const [showPastOfferings, setShowPastOfferings] = useState(false);
    const [enrolledCodes, setEnrolledCodes] = useState([]);
    const [enrollmentLoaded, setEnrollmentLoaded] = useState(false);

    const isEnrolled = useMemo(
        () => enrolledCodes.includes(courseCode),
        [enrolledCodes, courseCode],
    );

    const [fallbackCourse, setFallbackCourse] = useState(null);

    const catalogCourse = useMemo(
        () => courses.find((c) => c.courseCode === courseCode)
            ?? explorerCourses.find((c) => c.courseCode === courseCode),
        [courses, explorerCourses, courseCode]
    );

    const course = catalogCourse || fallbackCourse;
    const offeredThisSemester = course?.offeredThisSemester !== false;

    const { onPlan, addToPlan, removeFromPlan } = useCoursePlan(course, user);

    const sortedOfferings = useMemo(
        () => sortOfferingsBySemesterDesc(offerings),
        [offerings]
    );

    const headerInstructors = useMemo(() => {
        if (!course) return [];
        const active = sortedOfferings.find((o) => o.isActive);
        if (Array.isArray(active?.instructors) && active.instructors.length) {
            return active.instructors;
        }
        return instructorsFromCourse(course);
    }, [sortedOfferings, course]);

    const strengthLabel = (course?.currentStrength || '').trim();
    const activeOffering = sortedOfferings.find((o) => o.isActive);
    const primaryOffering = activeOffering || sortedOfferings[0] || null;

    useEffect(() => {
        let cancelled = false;
        setOfferingsLoading(true);
        setOfferingsError(null);
        fetchCourseOfferings(courseCode)
            .then(({ offerings: rows }) => {
                if (!cancelled) {
                    setOfferings(rows);
                    setShowPastOfferings(rows.length >= 1);
                    if (!catalogCourse && rows.length > 0) {
                        setFallbackCourse(offeringToCourse(rows[0]));
                    }
                }
            })
            .catch(() => {
                if (!cancelled) setOfferingsError('Could not load semester history');
            })
            .finally(() => {
                if (!cancelled) setOfferingsLoading(false);
            });
        return () => { cancelled = true; };
    }, [courseCode, catalogCourse]);

    useEffect(() => {
        setFallbackCourse(null);
    }, [courseCode]);

    useEffect(() => {
        if (!user) {
            setEnrolledCodes([]);
            setEnrollmentLoaded(true);
            return undefined;
        }
        let cancelled = false;
        setEnrollmentLoaded(false);
        apiFetch('/api/me/courses')
            .then((res) => res.json())
            .then((data) => {
                if (!cancelled) {
                    setEnrolledCodes(Array.isArray(data.courses) ? data.courses : []);
                }
            })
            .catch(() => {
                if (!cancelled) setEnrolledCodes([]);
            })
            .finally(() => {
                if (!cancelled) setEnrollmentLoaded(true);
            });
        return () => { cancelled = true; };
    }, [user, courseCode]);

    if (!course) {
        if (offeringsLoading) {
            return (
                <SemesterDataGate>
                    <div className="empty"><strong>Loading course…</strong></div>
                </SemesterDataGate>
            );
        }
        return (
            <SemesterDataGate>
                <Navigate to="/course-explorer" replace />
            </SemesterDataGate>
        );
    }

    return (
        <SemesterDataGate>
        <div className="cd">
            <Link to="/course-explorer" className="cd__back">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <line x1="19" y1="12" x2="5" y2="12" />
                    <polyline points="12 19 5 12 12 5" />
                </svg>
                Back to catalog
            </Link>

            <header className="cd__head">
                <div className="cd__head-top">
                    <span className="cd__code">{course.courseCode}</span>
                    {!offeredThisSemester && (
                        <span className="badge cd__not-offered">Not offered this sem</span>
                    )}
                    <span className="cd__credits tnum">{course.totalCredits} credits</span>
                </div>
                <div className="cd__title-row">
                    <h1 className="cd__title">{course.courseName}</h1>
                    <PlanToggle
                        onPlan={onPlan}
                        onAdd={addToPlan}
                        onRemove={removeFromPlan}
                    />
                </div>
                <p className="cd__instructor">
                    <span className="muted">Taught by</span>{' '}
                    {headerInstructors.length > 0 ? (
                        <InstructorLinks instructors={headerInstructors} />
                    ) : (
                        'TBD'
                    )}
                </p>
            </header>

            {!offeredThisSemester && (
                <p className="cd__not-offered-note muted">
                    Not offered this semester — summary below. Open the archived offering for full details and enrolled students.
                </p>
            )}

            {offeredThisSemester && activeOffering && (
                <p className="cd__offering-hint muted">
                    Summary page — open the <strong>{activeOffering.label}</strong> offering for schedule, venue, and enrolled students.
                </p>
            )}

            <dl className="cd__facts">
                <div>
                    <dt>Slot</dt>
                    <dd className="mono">{course.slot?.name || '—'}</dd>
                </div>
                <div>
                    <dt>Schedule</dt>
                    <dd className="mono">{course.slot?.lectureTimingStr || '—'}</dd>
                </div>
                <div>
                    <dt>Venue</dt>
                    <dd className="mono">{course.lectureHall || '—'}</dd>
                </div>
                <div>
                    <dt>Structure (L-T-P)</dt>
                    <dd className="mono">{course.creditStructure || '—'}</dd>
                </div>
            </dl>

            {primaryOffering && (
            <section className="cd__section">
                <Link
                    to={courseOfferingPath(courseCode, primaryOffering.semesterCode)}
                    className="cd__roster-link panel"
                >
                    <span className="cd__roster-icon" aria-hidden>
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
                            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
                        </svg>
                    </span>
                    <span className="cd__roster-copy">
                        <strong>
                            {primaryOffering.isActive
                                ? `Open ${primaryOffering.label} offering`
                                : `View ${primaryOffering.label} offering`}
                        </strong>
                        <span className="muted">
                            {primaryOffering.isActive
                                ? (strengthLabel
                                    ? `${strengthLabel} registered · slot, schedule, roster`
                                    : 'Schedule, venue, and enrolled students')
                                : 'Archived slot, schedule, and enrolled students'}
                        </span>
                    </span>
                    {strengthLabel && primaryOffering.isActive && (
                        <span className="badge cd__roster-badge">{strengthLabel}</span>
                    )}
                    <span className="cd__roster-chevron" aria-hidden>→</span>
                </Link>
            </section>
            )}

            {enrollmentLoaded && isEnrolled && offeredThisSemester && (
                <CoursePolicySection courseCode={courseCode} />
            )}

            <section className="cd__section">
                <div className="cd__section-head">
                    <h2 className="cd__h2">
                        Past offerings
                        {!offeringsLoading && sortedOfferings.length > 0 && (
                            <span className="cd__h2-count tnum">{sortedOfferings.length}</span>
                        )}
                    </h2>
                    {sortedOfferings.length > 1 && (
                        <button
                            type="button"
                            className="btn btn--sm btn--ghost"
                            onClick={() => setShowPastOfferings((v) => !v)}
                        >
                            {showPastOfferings ? 'Hide' : 'Show'} history
                        </button>
                    )}
                </div>
                {offeringsLoading ? (
                    <div className="empty"><strong>Loading semester history…</strong></div>
                ) : offeringsError ? (
                    <div className="empty"><strong>{offeringsError}</strong></div>
                ) : sortedOfferings.length === 0 ? (
                    <div className="empty">
                        <strong>No archived offerings yet</strong>
                    </div>
                ) : showPastOfferings ? (
                    <ul className="cd__history panel">
                        {sortedOfferings.map((o) => (
                            <li key={`${o.semesterCode}-${o.courseCode}`}>
                                <Link
                                    to={`/course/${encodeURIComponent(courseCode)}/${encodeURIComponent(o.semesterCode)}`}
                                    className={`cd__history-row cd__history-row--link${o.isActive ? ' cd__history-row--active' : ''}`}
                                >
                                    <div className="cd__history-head">
                                        <span className="mono">{o.label}</span>
                                        {o.isActive && <span className="badge">Current</span>}
                                    </div>
                                    <p className="cd__history-instr">
                                        <InstructorLinks
                                            course={o}
                                            instructors={o.instructors}
                                        />
                                    </p>
                                    <p className="cd__history-time mono muted">{offeringTimingSummary(o)}</p>
                                    <div className="cd__history-chips">
                                        {o.slotName && o.slotName !== 'X' && (
                                            <span className="badge">Slot {o.slotName}</span>
                                        )}
                                        {o.lectureHall && <span className="badge">{o.lectureHall}</span>}
                                    </div>
                                    <span className="cd__history-chevron" aria-hidden>→</span>
                                </Link>
                            </li>
                        ))}
                    </ul>
                ) : (
                    <p className="muted">This course has {sortedOfferings.length} recorded offerings across semesters.</p>
                )}
            </section>
        </div>
        </SemesterDataGate>
    );
}
