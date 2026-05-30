import React, { useState, useEffect, useMemo } from 'react';
import { Link } from 'react-router-dom';
import './CourseExplorer.css';
import coursesData from '../courses.json';

const ITEMS_PER_PAGE = 40;

export default function CourseExplorer() {
    const [searchTerm, setSearchTerm] = useState('');
    const [department, setDepartment] = useState('');
    const [displayedCourses, setDisplayedCourses] = useState([]);
    const [page, setPage] = useState(1);
    const [loading, setLoading] = useState(true);

    // First two letters of a courseCode denote the department (e.g. COL106 → CO).
    const departments = useMemo(() => {
        const counts = new Map();
        coursesData.forEach((course) => {
            const code = (course.courseCode || '').toUpperCase();
            const prefix = code.slice(0, 2);
            if (prefix.length === 2) {
                counts.set(prefix, (counts.get(prefix) || 0) + 1);
            }
        });
        return Array.from(counts.entries())
            .sort((a, b) => a[0].localeCompare(b[0]))
            .map(([code, count]) => ({ code, count }));
    }, []);

    const filteredCourses = useMemo(() => {
        const lowerTerm = searchTerm.trim().toLowerCase();
        return coursesData.filter((course) => {
            const code = (course.courseCode || '').toUpperCase();
            if (department && code.slice(0, 2) !== department) return false;
            if (!lowerTerm) return true;
            const lcCode = code.toLowerCase();
            const name = (course.courseName || '').toLowerCase();
            const instr = (course.instructor || '').toLowerCase();
            return lcCode.includes(lowerTerm) || name.includes(lowerTerm) || instr.includes(lowerTerm);
        });
    }, [searchTerm, department]);

    useEffect(() => {
        const end = page * ITEMS_PER_PAGE;
        setDisplayedCourses(filteredCourses.slice(0, end));
        setLoading(false);
    }, [filteredCourses, page]);

    const handleSearchChange = (e) => {
        setSearchTerm(e.target.value);
        setPage(1);
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    const loadMore = () => setPage((p) => p + 1);
    const hasMore = displayedCourses.length < filteredCourses.length;

    return (
        <div className="ce">
            <header className="ce__head">
                <div className="ce__eyebrow">Catalog</div>
                <h1 className="ce__title">
                    Every course offered <em>this semester</em>.
                </h1>
                <p className="ce__sub">
                    Browse {coursesData.length.toLocaleString()} courses, search by code, name, or instructor.
                </p>
            </header>

            <div className="ce__toolbar">
                <div className="ce__search">
                    <span className="ce__search-icon" aria-hidden="true">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="11" cy="11" r="8" />
                            <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                    </span>
                    <input
                        type="text"
                        placeholder="Search by code, name, or instructor…"
                        className="ce__search-input"
                        value={searchTerm}
                        onChange={handleSearchChange}
                    />
                    {searchTerm && (
                        <button
                            className="ce__search-clear"
                            onClick={() => { setSearchTerm(''); setPage(1); }}
                            aria-label="Clear search"
                        >
                            ×
                        </button>
                    )}
                </div>
                <select
                    className="field field--mono ce__dept"
                    value={department}
                    onChange={(e) => {
                        setDepartment(e.target.value);
                        setPage(1);
                        window.scrollTo({ top: 0, behavior: 'smooth' });
                    }}
                    aria-label="Filter by department"
                >
                    <option value="">All departments</option>
                    {departments.map((d) => (
                        <option key={d.code} value={d.code}>
                            {d.code} ({d.count})
                        </option>
                    ))}
                </select>
                <div className="ce__count tnum">
                    {filteredCourses.length.toLocaleString()} match{filteredCourses.length === 1 ? '' : 'es'}
                </div>
            </div>

            {loading ? (
                <div className="ce__loading">Loading courses…</div>
            ) : displayedCourses.length === 0 ? (
                <div className="empty">
                    <strong>No courses found</strong>
                    Try a different code, name, or instructor.
                </div>
            ) : (
                <>
                    <div className="ce__list" role="list">
                        <div className="ce__list-head" aria-hidden="true">
                            <span>Code</span>
                            <span>Title</span>
                            <span>Instructor</span>
                            <span>Slot</span>
                            <span>Venue</span>
                            <span className="ce__list-head-right">Credits</span>
                        </div>
                        {displayedCourses.map((course, index) => (
                            <Link
                                to={`/course/${course.courseCode}`}
                                key={`${course.courseCode}-${index}`}
                                className="ce__row"
                                role="listitem"
                            >
                                <span className="ce__cell ce__cell--code">{course.courseCode}</span>
                                <span className="ce__cell ce__cell--name">{course.courseName}</span>
                                <span className="ce__cell ce__cell--instr">{course.instructor || '—'}</span>
                                <span className="ce__cell ce__cell--slot">
                                    <span className="ce__slot">{course.slot?.name || '—'}</span>
                                </span>
                                <span className="ce__cell ce__cell--venue">{course.lectureHall || '—'}</span>
                                <span className="ce__cell ce__cell--credits">
                                    <span className="ce__credits tnum">{course.totalCredits}</span>
                                </span>
                            </Link>
                        ))}
                    </div>

                    {hasMore && (
                        <div className="ce__load-more">
                            <button onClick={loadMore} className="btn">
                                Load {Math.min(ITEMS_PER_PAGE, filteredCourses.length - displayedCourses.length)} more
                            </button>
                            <span className="ce__load-more-meta tnum muted">
                                Showing {displayedCourses.length} of {filteredCourses.length}
                            </span>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}
