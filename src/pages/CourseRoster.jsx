import React, { useEffect, useState } from 'react';
import { Link, Navigate, useParams } from 'react-router-dom';
import { useSemesterData } from '../data/SemesterDataContext';
import SemesterDataGate from '../data/SemesterDataGate';
import { fetchCourseOfferings, offeringToCourse } from '../utils/historyApi';
import { fetchCourseStudents } from '../utils/coursesApi';
import { BranchPieChart, BranchYearPivotTable } from '../components/BranchAnalytics/BranchAnalytics';
import './CourseRoster.css';

export default function CourseRoster() {
    const { courseCode } = useParams();
    const { courses } = useSemesterData();
    const [students, setStudents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [showBranches, setShowBranches] = useState(true);
    const [fallbackCourse, setFallbackCourse] = useState(null);
    const [activeSemester, setActiveSemester] = useState(null);
    const [offeringsResolved, setOfferingsResolved] = useState(false);

    const course = courses.find((c) => c.courseCode === courseCode) || fallbackCourse;

    useEffect(() => {
        let cancelled = false;
        fetchCourseOfferings(courseCode)
            .then(({ offerings }) => {
                if (cancelled) return;
                const active = offerings.find((o) => o.isActive);
                if (active) {
                    setActiveSemester(active.semesterCode);
                    if (!courses.find((c) => c.courseCode === courseCode)) {
                        setFallbackCourse(offeringToCourse(active));
                    }
                }
            })
            .catch(() => {})
            .finally(() => {
                if (!cancelled) setOfferingsResolved(true);
            });
        return () => { cancelled = true; };
    }, [courseCode, courses]);

    useEffect(() => {
        let cancelled = false;
        setLoading(true);
        setError(null);
        fetchCourseStudents(courseCode)
            .then(({ students: rows }) => {
                if (!cancelled) setStudents(rows);
            })
            .catch(() => {
                if (!cancelled) {
                    setStudents([]);
                    setError('Could not load enrolled students');
                }
            })
            .finally(() => {
                if (!cancelled) setLoading(false);
            });
        return () => { cancelled = true; };
    }, [courseCode]);

    if (!offeringsResolved) {
        return (
            <SemesterDataGate>
                <div className="empty"><strong>Loading roster…</strong></div>
            </SemesterDataGate>
        );
    }

    if (activeSemester) {
        return (
            <SemesterDataGate>
                <Navigate
                    to={`/course/${encodeURIComponent(courseCode)}/${encodeURIComponent(activeSemester)}`}
                    replace
                />
            </SemesterDataGate>
        );
    }

    if (!course) {
        return (
            <SemesterDataGate>
                <Navigate to="/course-explorer" replace />
            </SemesterDataGate>
        );
    }

    return (
        <SemesterDataGate>
            <div className="cr">
                <Link to={`/course/${encodeURIComponent(courseCode)}`} className="cr__back">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                        <line x1="19" y1="12" x2="5" y2="12" />
                        <polyline points="12 19 5 12 12 5" />
                    </svg>
                    Back to {courseCode}
                </Link>

                <header className="cr__head">
                    <span className="cr__code">{course.courseCode}</span>
                    <h1 className="cr__title">Enrolled students</h1>
                    <p className="cr__subtitle">{course.courseName}</p>
                </header>

                {loading ? (
                    <div className="empty panel"><strong>Loading roster…</strong></div>
                ) : error ? (
                    <div className="empty panel"><strong>{error}</strong></div>
                ) : students.length === 0 ? (
                    <div className="empty panel">
                        <strong>No students registered yet</strong>
                        Check back closer to the semester start.
                    </div>
                ) : (
                    <>
                        <div className="cr__toolbar">
                            <span className="badge">{students.length} enrolled</span>
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
            </div>
        </SemesterDataGate>
    );
}
