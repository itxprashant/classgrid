import React, { useMemo, useState } from 'react';
import { useParams, Link, Navigate } from 'react-router-dom';
import coursesData from '../courses.json';
import courseStudentsData from '../courseStudents.json';
import './CourseDetails.css';

// Muted palette aligned to design tokens (paper-toned hues, not saturated SaaS rainbow)
const COLORS = [
    'oklch(0.62 0.10 195)', // teal
    'oklch(0.60 0.10 80)',  // ochre
    'oklch(0.58 0.10 40)',  // clay
    'oklch(0.55 0.10 290)', // muted violet
    'oklch(0.62 0.10 145)', // sage
    'oklch(0.58 0.10 20)',  // rust
    'oklch(0.55 0.10 240)', // dusk
    'oklch(0.60 0.10 100)', // moss
    'oklch(0.58 0.10 350)', // berry
    'oklch(0.62 0.10 170)', // jade
];

function BranchPieChart({ students }) {
    const data = useMemo(() => {
        const counts = students.reduce((acc, student) => {
            const match = student.id.match(/^([a-z0-9]{3})/i);
            const branch = match ? match[1].toUpperCase() : 'Others';
            acc[branch] = (acc[branch] || 0) + 1;
            return acc;
        }, {});
        return Object.entries(counts)
            .sort((a, b) => b[1] - a[1])
            .map(([name, value], index) => ({
                name,
                value,
                color: COLORS[index % COLORS.length],
            }));
    }, [students]);

    const total = students.length;
    let accumulatedAngle = -90; // start at top

    return (
        <div className="cd-pie">
            <svg viewBox="0 0 100 100" className="cd-pie__svg" aria-label="Branch distribution">
                {data.map((slice) => {
                    const percentage = slice.value / total;
                    const angle = percentage * 360;
                    const x1 = 50 + 50 * Math.cos((Math.PI * accumulatedAngle) / 180);
                    const y1 = 50 + 50 * Math.sin((Math.PI * accumulatedAngle) / 180);
                    const endAngle = accumulatedAngle + angle;
                    const x2 = 50 + 50 * Math.cos((Math.PI * endAngle) / 180);
                    const y2 = 50 + 50 * Math.sin((Math.PI * endAngle) / 180);
                    const largeArcFlag = angle > 180 ? 1 : 0;
                    const pathData =
                        total === slice.value
                            ? `M 50 50 m -50 0 a 50 50 0 1 0 100 0 a 50 50 0 1 0 -100 0`
                            : `M 50 50 L ${x1} ${y1} A 50 50 0 ${largeArcFlag} 1 ${x2} ${y2} Z`;
                    accumulatedAngle += angle;
                    return (
                        <path
                            key={slice.name}
                            d={pathData}
                            fill={slice.color}
                            stroke="oklch(0.99 0.005 83)"
                            strokeWidth="0.8"
                        >
                            <title>{`${slice.name}: ${slice.value} (${(percentage * 100).toFixed(1)}%)`}</title>
                        </path>
                    );
                })}
                <circle cx="50" cy="50" r="30" fill="var(--surface)" />
                <text
                    x="50"
                    y="48"
                    textAnchor="middle"
                    style={{ fontSize: '11px', fill: 'var(--ink-3)', fontFamily: 'var(--font-mono)' }}
                >
                    Total
                </text>
                <text
                    x="50"
                    y="60"
                    textAnchor="middle"
                    style={{ fontSize: '12px', fill: 'var(--ink)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}
                >
                    {total}
                </text>
            </svg>
            <div className="cd-pie__legend">
                {data.map((item) => (
                    <div key={item.name} className="cd-pie__legend-item">
                        <span className="cd-pie__swatch" style={{ backgroundColor: item.color }} />
                        <span className="cd-pie__legend-label">{item.name}</span>
                        <span className="cd-pie__legend-value tnum">{item.value}</span>
                    </div>
                ))}
            </div>
        </div>
    );
}

function BranchYearPivotTable({ students }) {
    const { years, branches, matrix, totals } = useMemo(() => {
        const yearsSet = new Set();
        const branchesSet = new Set();
        const matrix = {};
        students.forEach((student) => {
            const match = student.id.match(/^([a-z0-9]{3})(\d{2})/i);
            const branch = match ? match[1].toUpperCase() : 'Unknown';
            const yearStr = match ? `20${match[2]}` : 'Unknown';
            yearsSet.add(yearStr);
            branchesSet.add(branch);
            if (!matrix[branch]) matrix[branch] = {};
            matrix[branch][yearStr] = (matrix[branch][yearStr] || 0) + 1;
        });
        const years = Array.from(yearsSet).sort();
        const branches = Array.from(branchesSet).sort();
        const totals = {};
        branches.forEach((branch) => {
            totals[branch] = years.reduce((sum, y) => sum + (matrix[branch][y] || 0), 0);
        });
        return { years, branches, matrix, totals };
    }, [students]);

    return (
        <div className="cd-pivot">
            <table className="cd-pivot__table">
                <thead>
                    <tr>
                        <th className="cd-pivot__corner">Branch</th>
                        {years.map((year) => (
                            <th key={year} className="cd-pivot__year">{year}</th>
                        ))}
                        <th className="cd-pivot__total-head">Total</th>
                    </tr>
                </thead>
                <tbody>
                    {branches.map((branch) => (
                        <tr key={branch}>
                            <td className="cd-pivot__branch">{branch}</td>
                            {years.map((year) => (
                                <td key={year} className="cd-pivot__cell tnum">
                                    {matrix[branch][year] || <span className="muted">·</span>}
                                </td>
                            ))}
                            <td className="cd-pivot__total tnum">{totals[branch]}</td>
                        </tr>
                    ))}
                </tbody>
            </table>
        </div>
    );
}

export default function CourseDetails() {
    const { courseCode } = useParams();
    const [showAnalytics, setShowAnalytics] = useState(false);

    const course = useMemo(
        () => coursesData.find((c) => c.courseCode === courseCode),
        [courseCode]
    );

    const students = useMemo(
        () => courseStudentsData[courseCode] || [],
        [courseCode]
    );

    if (!course) {
        return <Navigate to="/course-explorer" replace />;
    }

    return (
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
                    <span className="cd__credits tnum">{course.totalCredits} credits</span>
                </div>
                <h1 className="cd__title">{course.courseName}</h1>
                <p className="cd__instructor">
                    <span className="muted">Taught by</span> {course.instructor || 'TBD'}
                </p>
            </header>

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
                <div>
                    <dt>Strength</dt>
                    <dd className="mono">{course.currentStrength || '—'}</dd>
                </div>
            </dl>

            {students.length > 0 && (
                <section className="cd__section">
                    <div className="cd__section-head">
                        <h2 className="cd__h2">Class composition</h2>
                        <button className="btn btn--sm btn--ghost" onClick={() => setShowAnalytics(true)}>
                            Show full breakdown →
                        </button>
                    </div>
                    <div className="cd__chart-block">
                        <BranchPieChart students={students} />
                    </div>
                </section>
            )}

            <section className="cd__section">
                <div className="cd__section-head">
                    <h2 className="cd__h2">
                        Registered students
                        <span className="cd__h2-count tnum">{students.length}</span>
                    </h2>
                </div>

                {students.length > 0 ? (
                    <div className="cd__students">
                        <table className="cd__students-table">
                            <thead>
                                <tr>
                                    <th className="cd__students-num">#</th>
                                    <th>Name</th>
                                    <th>Kerberos</th>
                                </tr>
                            </thead>
                            <tbody>
                                {students.map((student, index) => (
                                    <tr key={student.id}>
                                        <td className="cd__students-num tnum muted">{index + 1}</td>
                                        <td>{student.name}</td>
                                        <td className="mono">{student.id}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                ) : (
                    <div className="empty">
                        <strong>No students registered yet</strong>
                        Check back closer to the semester start.
                    </div>
                )}
            </section>

            {showAnalytics && (
                <div className="cd__modal-overlay" onClick={() => setShowAnalytics(false)}>
                    <div className="cd__modal" onClick={(e) => e.stopPropagation()}>
                        <div className="cd__modal-head">
                            <h2 className="cd__h2">Class composition · {course.courseCode}</h2>
                            <button
                                className="btn btn--sm btn--ghost btn--icon"
                                onClick={() => setShowAnalytics(false)}
                                aria-label="Close"
                            >
                                ×
                            </button>
                        </div>
                        <div className="cd__modal-body">
                            <div className="cd__modal-grid">
                                <div>
                                    <h3 className="cd__h3">Branch distribution</h3>
                                    <BranchPieChart students={students} />
                                </div>
                                <div>
                                    <h3 className="cd__h3">Year of entry by branch</h3>
                                    <BranchYearPivotTable students={students} />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
