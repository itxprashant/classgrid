import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { searchInstructors } from '../utils/historyApi';
import './ProfessorExplorer.css';

function initials(name) {
    const parts = (name || '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

export default function ProfessorExplorer() {
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
            searchInstructors(q)
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
        <div className="pe">
            <header className="pe__head">
                <div className="pe__eyebrow">Explore</div>
                <h1 className="pe__title">
                    Find a professor <em>across semesters</em>.
                </h1>
                <p className="pe__sub">
                    Search by name or IITD email. Each result is one instructor — co-taught courses are linked separately.
                </p>
            </header>

            <div className="pe__toolbar">
                <div className="pe__search">
                    <span className="pe__search-icon" aria-hidden="true">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="11" cy="11" r="8" />
                            <line x1="21" y1="21" x2="16.65" y2="16.65" />
                        </svg>
                    </span>
                    <input
                        id="prof-search"
                        type="search"
                        className="pe__search-input"
                        placeholder="e.g. patel or @cse.iitd.ac.in"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                        autoComplete="off"
                    />
                    {query && (
                        <button
                            type="button"
                            className="pe__search-clear"
                            onClick={() => setQuery('')}
                            aria-label="Clear search"
                        >
                            ×
                        </button>
                    )}
                </div>
                {results.length > 0 && (
                    <span className="pe__count">
                        {results.length} match{results.length === 1 ? '' : 'es'}
                    </span>
                )}
            </div>

            {loading && <p className="pe__loading">Searching catalog history…</p>}
            {error && <p className="pe__error">{error}</p>}

            {showEmptyHint && (
                <div className="pe__hint panel">
                    <strong>Type at least 2 characters</strong>
                    <p className="muted">Results include offerings from archived and current semesters.</p>
                </div>
            )}

            {showNoResults && (
                <div className="pe__hint panel">
                    <strong>No matches</strong>
                    <p className="muted">Try a shorter fragment of the name or part of the email address.</p>
                </div>
            )}

            {results.length > 0 && (
                <div className="pe__list">
                    <div className="pe__list-head" aria-hidden="true">
                        <span>Instructor</span>
                        <span>Email</span>
                        <span className="pe__list-head-right">Offerings</span>
                    </div>
                    {results.map((row) => (
                        <Link
                            key={row.email}
                            to={`/professor/${encodeURIComponent(row.email)}`}
                            className="pe__row"
                        >
                            <span className="pe__cell pe__cell--person">
                                <span className="pe__avatar" aria-hidden="true">{initials(row.name)}</span>
                                <span className="pe__name">{row.name}</span>
                            </span>
                            <span className="pe__cell pe__cell--email mono">{row.email}</span>
                            <span className="pe__cell pe__cell--count">
                                <span className="pe__offerings">{row.offeringCount}</span>
                            </span>
                        </Link>
                    ))}
                </div>
            )}
        </div>
    );
}
