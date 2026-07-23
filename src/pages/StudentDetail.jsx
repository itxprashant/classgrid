import React, { useEffect, useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
    compareSemesterCodeDesc,
    fetchStudentOfferings,
    offeringTimingSummary,
    sortOfferingsBySemesterDesc,
} from '../utils/historyApi';
import { isStudentKerberos } from '../utils/kerberosMeta';
import './StudentDetail.css';

function formatHostel(hostel) {
    const value = (hostel || '').trim();
    return value || '—';
}

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

export default function StudentDetail() {
    const { kerberos: kerberosParam } = useParams();
    const kerberos = decodeURIComponent(kerberosParam || '').trim().toLowerCase();
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        if (!kerberos || !isStudentKerberos(kerberos)) {
            setError('Invalid student kerberos id.');
            setLoading(false);
            return undefined;
        }
        setLoading(true);
        setError(null);
        fetchStudentOfferings(kerberos)
            .then((payload) => {
                setData(payload);
                setLoading(false);
            })
            .catch(() => {
                setError('Could not load courses for this student.');
                setLoading(false);
            });
        return undefined;
    }, [kerberos]);

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
            <div className="sd page">
                <div className="empty panel"><strong>Loading courses…</strong></div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="sd page">
                <div className="empty panel"><strong>{error}</strong></div>
            </div>
        );
    }

    const student = data?.student || { kerberos, name: kerberos };
    const offerings = sortedOfferings;
    const semesterCount = grouped.length;

    return (
        <div className="sd page">
            <header className="sd__head">
                <p className="sd__eyebrow mono muted">
                    <Link to="/students" className="sd__back">Student explorer</Link>
                </p>
                <h1 className="sd__title serif">
                    {titleWithEmphasis(student.name || kerberos)}
                </h1>
                <p className="sd__kerberos mono muted">{student.kerberos}</p>
                <dl className="sd__facts">
                    {student.branch && (
                        <>
                            <dt className="mono muted">Branch</dt>
                            <dd className="mono">{student.branch}</dd>
                        </>
                    )}
                    {student.entryYear && (
                        <>
                            <dt className="mono muted">Entry</dt>
                            <dd className="mono">{student.entryYear}</dd>
                        </>
                    )}
                    <dt className="mono muted">Hostel</dt>
                    <dd>{formatHostel(student.hostel)}</dd>
                </dl>
                <p className="sd__count muted">
                    {offerings.length} registered course{offerings.length === 1 ? '' : 's'}
                    {semesterCount > 0
                        ? ` across ${semesterCount} semester${semesterCount === 1 ? '' : 's'}`
                        : ''}
                </p>
            </header>

            {offerings.length === 0 ? (
                <div className="empty panel"><strong>No courses found</strong></div>
            ) : (
                grouped.map(([semesterCode, rows]) => (
                    <section key={semesterCode} className="sd__sem">
                        <h2 className="sd__sem-title mono">{rows[0]?.label || semesterCode}</h2>
                        <ul className="sd__courses">
                            {rows.map((o) => (
                                <li
                                    key={`${o.semesterCode}-${o.courseCode}`}
                                    className={`sd__course${o.isActive ? ' sd__course--active' : ''}`}
                                >
                                    <div className="sd__course-head">
                                        <Link
                                            to={`/course/${encodeURIComponent(o.courseCode)}/${encodeURIComponent(o.semesterCode)}`}
                                            className="sd__code mono"
                                        >
                                            {o.courseCode}
                                        </Link>
                                        {o.isActive && (
                                            <span className="badge badge--accent">Current</span>
                                        )}
                                    </div>
                                    <p className="sd__course-name">{o.courseName}</p>
                                    <p className="sd__timings mono muted">{offeringTimingSummary(o)}</p>
                                    <div className="sd__chips">
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
