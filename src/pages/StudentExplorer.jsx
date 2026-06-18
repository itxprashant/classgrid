import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { searchStudents } from '../utils/historyApi';
import './StudentExplorer.css';

function initials(name) {
    const parts = (name || '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

export default function StudentExplorer() {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        const q = query.trim();
        if (q.length < 2) {
            setResults([]);
            setError(null);
            setLoading(false);
            return undefined;
        }

        setLoading(true);
        setError(null);
        const timer = setTimeout(() => {
            searchStudents(q)
                .then((rows) => {
                    setResults(rows);
                    setLoading(false);
                })
                .catch(() => {
                    setError('Search failed. Try again.');
                    setLoading(false);
                });
        }, 350);

        return () => clearTimeout(timer);
    }, [query]);

    const trimmed = query.trim();
    const showEmptyHint = !loading && trimmed.length < 2;
    const showNoResults = !loading && trimmed.length >= 2 && results.length === 0 && !error;

    return (
        <div className="se">
            <header className="se__head">
                <div className="se__eyebrow">Explore</div>
                <h1 className="se__title">
                    Find a student <em>across semesters</em>.
                </h1>
                <p className="se__sub">
                    Search by name or kerberos id. Each result shows registered courses from imported enrollment data.
                </p>
            </header>

            <div className="se__toolbar">
                <div className="se__search">
                    <span className="se__search-icon" aria-hidden="true">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="11" cy="11" r="8" />
                            <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                    </span>
                    <input
                        id="student-search"
                        type="search"
                        className="se__search-input"
                        placeholder="e.g. sharma or mt6240685"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        autoComplete="off"
                    />
                    {query && (
                        <button
                            type="button"
                            className="se__search-clear"
                            onClick={() => setQuery('')}
                            aria-label="Clear search"
                        >
                            ×
                        </button>
                    )}
                </div>
                {results.length > 0 && (
                    <span className="se__count">
                        {results.length} match{results.length === 1 ? '' : 'es'}
                    </span>
                )}
            </div>

            {loading && <p className="se__loading">Searching enrollment records…</p>}
            {error && <p className="se__error">{error}</p>}

            {showEmptyHint && (
                <div className="se__hint panel">
                    <strong>Type at least 2 characters</strong>
                    <p className="muted">Results include students from imported roster and enrollment data.</p>
                </div>
            )}

            {showNoResults && (
                <div className="se__hint panel">
                    <strong>No matches</strong>
                    <p className="muted">Try a shorter fragment of the name or part of the kerberos id.</p>
                </div>
            )}

            {results.length > 0 && (
                <div className="se__list">
                    <div className="se__list-head" aria-hidden="true">
                        <span>Student</span>
                        <span>Kerberos</span>
                        <span className="se__list-head-right">Semesters</span>
                    </div>
                    {results.map((row) => (
                        <Link
                            key={row.kerberos}
                            to={`/student/${encodeURIComponent(row.kerberos)}`}
                            className="se__row"
                        >
                            <span className="se__cell se__cell--person">
                                <span className="se__avatar" aria-hidden="true">{initials(row.name)}</span>
                                <span className="se__name">{row.name}</span>
                            </span>
                            <span className="se__cell se__cell--kerberos mono">{row.kerberos}</span>
                            <span className="se__cell se__cell--count">
                                <span className="se__semesters">{row.enrollmentCount}</span>
                            </span>
                        </Link>
                    ))}
                </div>
            )}
        </div>
    );
}
