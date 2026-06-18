import React from 'react';
import { useSemesterData } from './SemesterDataContext';

export default function SemesterDataGate({ children }) {
    const { loading, error, retry } = useSemesterData();

    if (loading) {
        return (
            <div className="panel" style={{ margin: '2rem auto', maxWidth: '32rem', textAlign: 'center' }}>
                <p className="muted">Loading semester data…</p>
            </div>
        );
    }

    if (error) {
        return (
            <div className="panel" style={{ margin: '2rem auto', maxWidth: '32rem', textAlign: 'center' }}>
                <p style={{ color: 'var(--danger)' }}>
                    Could not load semester data. {error === 'database_unavailable' ? 'The database may be unavailable.' : ''}
                </p>
                <button type="button" className="btn btn--primary" onClick={retry} style={{ marginTop: '1rem' }}>
                    Retry
                </button>
            </div>
        );
    }

    return children;
}
