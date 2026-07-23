import React, { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
    compareSemesterCodeDesc,
    fetchInstructorOfferings,
    offeringTimingSummary,
    sortOfferingsBySemesterDesc,
} from '../utils/historyApi';
import './ProfessorDetail.css';

function titleWithEmphasis(name) {
    const text = (name || '').trim();
    if (!text) return null;
    const parts = text.split(/\s+/);
    if (parts.length < 2) return text;
    const last = parts.pop();
    return (
        <>
            {parts.join(' ')}{' '}
            <em>{last}</em>
        </>
    );
}

export default function ProfessorDetail() {
    const { email: emailParam } = useParams();
    const email = decodeURIComponent(emailParam || '').trim().toLowerCase();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!email.includes('@')) {
            setError('Invalid instructor email.');
            setLoading(false);
            return undefined;
        }
        setLoading(true);
        setError(null);
        fetchInstructorOfferings(email)
            .then((payload) => {
                setData(payload);
                setLoading(false);
            })
            .catch(() => {
                setError('Could not load offerings for this instructor.');
                setLoading(false);
            });
        return undefined;
    }, [email]);

    const sortedOfferings = useMemo(
        () => sortOfferingsBySemesterDesc(data?.offerings || []),
        [data],
    );

    const grouped = useMemo(() => {
        const map = new Map();
        sortedOfferings.forEach((o) => {
            if (!map.has(o.semesterCode)) map.set(o.semesterCode, []);
            map.get(o.semesterCode).push(o);
        });
        return [...map.entries()]
            .sort((a, b) => compareSemesterCodeDesc(a[0], b[0]))
            .map(([semesterCode, rows]) => [semesterCode, rows]);
    }, [sortedOfferings]);

    if (loading) {
        return (
            <div className="pd page">
                <div className="empty panel"><strong>Loading offerings…</strong></div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="pd page">
                <div className="empty panel"><strong>{error}</strong></div>
            </div>
        );
    }

    const instructor = data?.instructor || { name: email, email };
    const offerings = sortedOfferings;
    const semesterCount = grouped.length;

    return (
        <div className="pd page">
            <header className="pd__head">
                <p className="pd__eyebrow mono muted">
                    <Link to="/professors" className="pd__back">Prof explorer</Link>
                </p>
                <h1 className="pd__title serif">
                    {titleWithEmphasis(instructor.name || email)}
                </h1>
                <p className="pd__email mono muted">{instructor.email}</p>
                <p className="pd__meta muted">
                    {offerings.length} catalog offering{offerings.length === 1 ? '' : 's'}
                    {semesterCount > 0
                        ? ` across ${semesterCount} semester${semesterCount === 1 ? '' : 's'}`
                        : ''}
                </p>
            </header>

            {offerings.length === 0 ? (
                <div className="empty panel"><strong>No offerings found</strong></div>
            ) : (
                grouped.map(([semesterCode, rows]) => (
                    <section key={semesterCode} className="pd__sem">
                        <h2 className="pd__sem-title mono">{rows[0]?.label || semesterCode}</h2>
                        <ul className="pd__courses">
                            {rows.map((o) => (
                                <li
                                    key={`${o.semesterCode}-${o.courseCode}`}
                                    className={`pd__course${o.isActive ? ' pd__course--active' : ''}`}
                                >
                                    <div className="pd__course-head">
                                        <Link
                                            to={`/course/${encodeURIComponent(o.courseCode)}/${encodeURIComponent(o.semesterCode)}`}
                                            className="pd__code mono"
                                        >
                                            {o.courseCode}
                                        </Link>
                                        {o.isActive && (
                                            <span className="badge badge--accent">Current</span>
                                        )}
                                    </div>
                                    <p className="pd__course-name">{o.courseName}</p>
                                    <p className="pd__timings mono muted">{offeringTimingSummary(o)}</p>
                                    <div className="pd__chips">
                                        {o.slotName && o.slotName !== 'X' && (
                                            <span className="badge">Slot {o.slotName}</span>
                                        )}
                                        {o.credits != null && (
                                            <span className="badge">{o.credits} cr</span>
                                        )}
                                        {o.lectureHall && (
                                            <span className="badge">{o.lectureHall}</span>
                                        )}
                                    </div>
                                </li>
                            ))}
                        </ul>
                    </section>
                ))
            )}
        </div>
    );
}
