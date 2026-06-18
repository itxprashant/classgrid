import React, { useEffect, useMemo, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { useAuth, apiFetch } from '../auth/AuthContext';
import SemesterDataGate from '../data/SemesterDataGate';
import { fetchCourseOfferings, offeringToCourse, offeringTimingSummary } from '../utils/historyApi';
import { fetchCourseStudents } from '../utils/coursesApi';
import { instructorsFromCourse } from '../utils/instructors';
import InstructorLinks from '../components/InstructorLinks/InstructorLinks';
import PlanToggle from '../components/PlanToggle/PlanToggle';
import CoursePolicySection from '../components/CoursePolicy/CoursePolicySection';
import { BranchPieChart, BranchYearPivotTable } from '../components/BranchAnalytics/BranchAnalytics';
import { useCoursePlan } from '../hooks/useCoursePlan';
import './CourseDetails.css';
import './CourseRoster.css';

const SEMESTER_CODE_RE = /^\d{4}$/;

export default function CourseOffering() {
    const { courseCode, semesterCode } = useParams();
    const { user } = useAuth();
    const [offering, setOffering] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [students, setStudents] = useState([]);
    const [rosterLoading, setRosterLoading] = useState(true);
    const [rosterError, setRosterError] = useState(null);
    const [showBranches, setShowBranches] = useState(true);
    const [enrolledCodes, setEnrolledCodes] = useState([]);
    const [enrollmentLoaded, setEnrollmentLoaded] = useState(false);

    const course = useMemo(
        () => (offering ? offeringToCourse(offering) : null),
        [offering],
    );

    const headerInstructors = useMemo(() => {
        if (!offering) return [];
        if (Array.isArray(offering.instructors) && offering.instructors.length) {
            return offering.instructors;
        }
        return course ? instructorsFromCourse(course) : [];
    }, [offering, course]);

    const { onPlan, addToPlan, removeFromPlan } = useCoursePlan(course, user);

    const isEnrolled = useMemo(
        () => enrolledCodes.includes(courseCode),
        [enrolledCodes, courseCode],
    );

    const showPolicy = enrollmentLoaded && isEnrolled && offering?.isActive;

    useEffect(() => {
        if (!SEMESTER_CODE_RE.test(semesterCode || '')) {
            setLoading(false);
            setError('invalid_semester');
            return undefined;
        }
        let cancelled = false;
        setLoading(true);
        setError(null);
        fetchCourseOfferings(courseCode)
            .then(({ offerings }) => {
                if (cancelled) return;
                const match = offerings.find((o) => o.semesterCode === semesterCode);
                if (!match) {
                    setError('offering_not_found');
                    setOffering(null);
                } else {
                    setOffering(match);
                }
            })
            .catch(() => {
                if (!cancelled) setError('offerings_load_failed');
            })
            .finally(() => {
                if (!cancelled) setLoading(false);
            });
        return () => { cancelled = true; };
    }, [courseCode, semesterCode]);

    useEffect(() => {
        if (!offering || !SEMESTER_CODE_RE.test(semesterCode || '')) return undefined;
        let cancelled = false;
        setRosterLoading(true);
        setRosterError(null);
        fetchCourseStudents(courseCode, semesterCode)
            .then(({ students: rows }) => {
                if (!cancelled) setStudents(rows);
            })
            .catch(() => {
                if (!cancelled) {
                    setStudents([]);
                    setRosterError('Could not load enrolled students');
                }
            })
            .finally(() => {
                if (!cancelled) setRosterLoading(false);
            });
        return () => { cancelled = true; };
    }, [courseCode, semesterCode, offering]);

    useEffect(() => {
        if (!user || !offering?.isActive) {
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
    }, [user, courseCode, offering]);

    if (!SEMESTER_CODE_RE.test(semesterCode || '')) {
        return (
            <SemesterDataGate>
                <Navigate to={`/course/${encodeURIComponent(courseCode)}`} replace />
            </SemesterDataGate>
        );
    }

    if (loading) {
        return (
            <SemesterDataGate>
                <div className="empty"><strong>Loading offering…</strong></div>
            </SemesterDataGate>
        );
    }

    if (error === 'offering_not_found' || !course || !offering) {
        return (
            <SemesterDataGate>
                <Navigate to={`/course/${encodeURIComponent(courseCode)}`} replace />
            </SemesterDataGate>
        );
    }

    const strengthLabel = (offering.currentStrength || '').trim();
    const rosterCount = students.length;

    return (
        <SemesterDataGate>
            <div className="cd">
                <Link to={`/course/${encodeURIComponent(courseCode)}`} className="cd__back">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <line x1="19" y1="12" x2="5" y2="12" />
                        <polyline points="12 19 5 12 12 5" />
                    </svg>
                    Back to {courseCode}
                </Link>

                <header className="cd__head">
                    <div className="cd__head-top">
                        <span className="cd__code">{course.courseCode}</span>
                        <span className="badge">{offering.label}</span>
                        {offering.isActive && <span className="badge">Current</span>}
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

                {!offering.isActive && (
                    <p className="cd__not-offered-note muted">
                        Archived offering for {offering.label} — not the current semester.
                    </p>
                )}

                <dl className="cd__facts">
                    <div>
                        <dt>Semester</dt>
                        <dd className="mono">{offering.label}</dd>
                    </div>
                    <div>
                        <dt>Slot</dt>
                        <dd className="mono">{course.slot?.name || '—'}</dd>
                    </div>
                    <div>
                        <dt>Schedule</dt>
                        <dd className="mono">{offeringTimingSummary(offering)}</dd>
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

                {showPolicy && (
                    <section className="cd__section">
                        <CoursePolicySection courseCode={courseCode} />
                    </section>
                )}

                <section className="cd__section cr__section">
                    <div className="cd__section-head">
                        <h2 className="cd__h2">Enrolled students</h2>
                        {!rosterLoading && rosterCount > 0 && (
                            <span className="badge">{rosterCount} enrolled</span>
                        )}
                    </div>

                    {rosterLoading ? (
                        <div className="empty panel"><strong>Loading roster…</strong></div>
                    ) : rosterError ? (
                        <div className="empty panel"><strong>{rosterError}</strong></div>
                    ) : rosterCount === 0 ? (
                        <div className="empty panel">
                            <strong>No students registered</strong>
                            {strengthLabel
                                ? ` Catalog listed ${strengthLabel} — roster may not be imported for this semester yet.`
                                : ' Roster data may not be available for this semester yet.'}
                        </div>
                    ) : (
                        <>
                            <div className="cr__toolbar">
                                <span className="muted">{offering.label}</span>
                                <button
                                    type="button"
                                    className="btn btn--sm btn--ghost"
                                    onClick={() => setShowBranches((v) => !v)}
                                >
                                    {showBranches ? 'Hide branches' : 'Show branches'}
                                </button>
                            </div>

                            {showBranches && (
                                <section className="cr__analytics panel">
                                    <div className="cr__analytics-grid">
                                        <div>
                                            <h2 className="cr__h2">Branch distribution</h2>
                                            <BranchPieChart students={students} />
                                        </div>
                                        <div>
                                            <h2 className="cr__h2">Year of entry by branch</h2>
                                            <BranchYearPivotTable students={students} />
                                        </div>
                                    </div>
                                </section>
                            )}

                            <section className="cr__students panel">
                                <table className="cr__students-table">
                                    <thead>
                                        <tr>
                                            <th className="cr__students-num">#</th>
                                            <th>Name</th>
                                            <th>Kerberos</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {students.map((student, index) => (
                                            <tr key={student.id}>
                                                <td className="cr__students-num tnum muted">{index + 1}</td>
                                                <td>{student.name}</td>
                                                <td className="mono">
                                                    <Link to={`/student/${encodeURIComponent(student.id)}`}>
                                                        {student.id}
                                                    </Link>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </section>
                        </>
                    )}
                </section>
            </div>
        </SemesterDataGate>
    );
}
