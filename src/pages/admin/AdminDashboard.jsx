import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminErrorMessage, fetchAdminSummary } from '../../utils/adminApi';
import './admin.css';

function PriorityStat({ label, value, alert }) {
    return (
        <div className="admin__priority-stat">
            <div className="admin__priority-label">{label}</div>
            <div className={`admin__priority-value tnum${alert ? ' admin__priority-value--alert' : ''}`}>
                {value}
            </div>
        </div>
    );
}

export default function AdminDashboard() {
    const [data, setData] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const summary = await fetchAdminSummary();
            setData(summary);
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
            setData(null);
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => {
        load();
    }, [load]);

    if (loading) {
        return <p className="admin__loading admin__body-pad">Loading overview…</p>;
    }

    if (error) {
        return (
            <div className="admin__body-pad">
                <p className="status status--err">{error}</p>
                <div className="admin__actions admin__actions--inline">
                    <button type="button" className="btn btn--ghost btn--sm" onClick={load}>Retry</button>
                </div>
            </div>
        );
    }

    const { health, explorer, feedback, reports } = data;
    const openReports = reports.open ?? 0;

    return (
        <>
            <div className="admin__priority admin__priority--inset">
                <PriorityStat label="Open reports" value={openReports} alert={openReports > 0} />
                <PriorityStat label="Feedback (24h)" value={feedback.last24h ?? 0} />
                <PriorityStat label="Feedback (7d)" value={feedback.last7d ?? 0} />
                <PriorityStat label="Feedback total" value={feedback.total ?? 0} />
                {openReports > 0 && (
                    <Link to="/admin/reports" className="admin__priority-link">
                        Review queue →
                    </Link>
                )}
            </div>

            <div className="admin__health admin__body-pad">
                <dl className="dl">
                    <div>
                        <dt>Active semester</dt>
                        <dd className="mono">{health.activeSemester || '—'}</dd>
                    </div>
                    <div>
                        <dt>Catalog offered</dt>
                        <dd className="mono tnum">{explorer.offeredCount ?? '—'}</dd>
                    </div>
                    <div>
                        <dt>Catalog total</dt>
                        <dd className="mono tnum">{explorer.count ?? '—'}</dd>
                    </div>
                    <div>
                        <dt>Active catalog rows</dt>
                        <dd className="mono tnum">{health.catalogCount ?? '—'}</dd>
                    </div>
                    <div>
                        <dt>Enrolled students</dt>
                        <dd className="mono tnum">{health.enrolledStudents ?? '—'}</dd>
                    </div>
                    <div>
                        <dt>API cache</dt>
                        <dd>{health.semesterDataLoaded ? 'Loaded' : 'Not loaded'}</dd>
                    </div>
                </dl>
            </div>

            <div className="admin__actions admin__actions--inline admin__body-pad">
                <Link to="/admin/reports" className="btn btn--primary btn--sm">
                    Reports inbox
                </Link>
                <Link to="/admin/feedback" className="btn btn--ghost btn--sm">
                    Feedback inbox
                </Link>
                <Link to="/admin/logs" className="btn btn--ghost btn--sm">
                    Audit log
                </Link>
                <button type="button" className="btn btn--ghost btn--sm" onClick={load}>
                    Refresh
                </button>
            </div>
        </>
    );
}
