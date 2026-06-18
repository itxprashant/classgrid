import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import FormField from '../../components/FormField/FormField';
import {
    adminErrorMessage,
    deleteAdminCourseEvent,
    deleteAdminCoursePolicy,
    deleteAdminOccupiedRoom,
    fetchAdminReports,
    patchAdminReport,
} from '../../utils/adminApi';
import { REPORT_REASONS, reportContextLabel } from '../../utils/feedback';
import { snapshotFields, snapshotHeading } from './adminSnapshot';
import { coursePolicyReportPath } from '../../utils/courseRoutes';
import './admin.css';

const PAGE_SIZE = 30;
const STATUSES = [
    { id: 'open', label: 'Open' },
    { id: 'reviewed', label: 'Reviewed' },
    { id: 'dismissed', label: 'Dismissed' },
    { id: 'actioned', label: 'Actioned' },
];

function formatDate(iso) {
    if (!iso) return '—';
    try {
        return new Date(iso).toLocaleString(undefined, {
            dateStyle: 'medium',
            timeStyle: 'short',
        });
    } catch {
        return iso;
    }
}

function reasonLabel(id) {
    return REPORT_REASONS.find((r) => r.id === id)?.label || id;
}

function statusClass(status) {
    if (status === 'open') return 'badge admin__status--open';
    if (status === 'actioned') return 'badge admin__status--actioned';
    if (status === 'dismissed' || status === 'reviewed') return 'badge admin__status--dismissed';
    return 'badge';
}

function targetLink(report) {
    const snap = report.targetSnapshot || {};
    if (report.targetKind === 'course_event' && snap.courseCode) {
        return `/calendar?course=${encodeURIComponent(snap.courseCode)}`;
    }
    if (report.targetKind === 'course_policy' && snap.courseCode) {
        const semester = snap.semesterCode || report.targetId.split(':')[0];
        return coursePolicyReportPath(snap.courseCode, semester);
    }
    if (report.targetKind === 'occupied_room') {
        return '/empty-halls';
    }
    return null;
}

async function removeReportedContent(report) {
    const snap = report.targetSnapshot || {};
    if (report.targetKind === 'course_event') {
        await deleteAdminCourseEvent(report.targetId);
        return;
    }
    if (report.targetKind === 'occupied_room') {
        await deleteAdminOccupiedRoom(report.targetId);
        return;
    }
    if (report.targetKind === 'course_policy') {
        const semester = snap.semesterCode || report.targetId.split(':')[0];
        const courseCode = snap.courseCode || report.targetId.split(':').slice(1).join(':');
        await deleteAdminCoursePolicy(semester, courseCode);
        return;
    }
    throw new Error('unsupported_target');
}

function ReportDetail({ report, busy, onReview, onDismiss, onRemove, onActioned }) {
    const [showRaw, setShowRaw] = useState(false);
    const link = targetLink(report);
    const fields = snapshotFields(report.targetSnapshot, report.targetKind);

    return (
        <aside className="admin__detail-panel" aria-label="Report detail">
            <div className="admin__detail-id">Report {report.id.slice(0, 8)}…</div>
            <p className="admin__detail-heading">
                {snapshotHeading(report.targetSnapshot, report.targetKind)}
            </p>
            <p className="admin__detail-text">
                <span className={statusClass(report.status)}>{report.status}</span>
                {' · '}
                {reasonLabel(report.reason)}
                {' · '}
                <span className="mono">{report.reporterKerberos}</span>
            </p>

            {report.details && (
                <p className="admin__detail-text">{report.details}</p>
            )}

            <dl className="admin__detail-dl">
                {fields.map((row) => (
                    <div key={row.label}>
                        <dt>{row.label}</dt>
                        <dd>{row.value}</dd>
                    </div>
                ))}
            </dl>

            {link && (
                <Link to={link} className="admin__back">View on site →</Link>
            )}

            <button
                type="button"
                className="btn btn--ghost btn--sm admin__detail-toggle"
                onClick={() => setShowRaw((v) => !v)}
            >
                {showRaw ? 'Hide raw snapshot' : 'Show raw snapshot'}
            </button>
            {showRaw && (
                <pre className="admin__detail-raw">{JSON.stringify(report.targetSnapshot, null, 2)}</pre>
            )}

            <div className="admin__actions">
                {report.status === 'open' && (
                    <>
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={busy}
                            onClick={onReview}
                        >
                            Mark reviewed
                        </button>
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={busy}
                            onClick={onDismiss}
                        >
                            Dismiss
                        </button>
                        {report.targetKind !== 'other' && (
                            <button
                                type="button"
                                className="btn btn--danger-ghost btn--sm"
                                disabled={busy}
                                onClick={onRemove}
                            >
                                Remove content & close
                            </button>
                        )}
                        {report.targetKind === 'other' && (
                            <button
                                type="button"
                                className="btn btn--primary btn--sm"
                                disabled={busy}
                                onClick={onActioned}
                            >
                                Mark actioned
                            </button>
                        )}
                    </>
                )}
                {report.status !== 'open' && report.reviewedAt && (
                    <span className="admin__reviewed">
                        Reviewed {formatDate(report.reviewedAt)}
                        {report.reviewedByKerberos ? ` · ${report.reviewedByKerberos}` : ''}
                    </span>
                )}
            </div>
        </aside>
    );
}

export default function AdminReports() {
    const [status, setStatus] = useState('open');
    const [offset, setOffset] = useState(0);
    const [items, setItems] = useState([]);
    const [total, setTotal] = useState(0);
    const [selectedId, setSelectedId] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [busy, setBusy] = useState(false);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await fetchAdminReports({
                limit: PAGE_SIZE,
                offset,
                status,
            });
            setItems(data.items || []);
            setTotal(data.total || 0);
            setSelectedId((prev) => {
                if (prev && !(data.items || []).some((r) => r.id === prev)) {
                    return null;
                }
                return prev;
            });
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setLoading(false);
        }
    }, [offset, status]);

    useEffect(() => {
        load();
    }, [load]);

    const selected = items.find((r) => r.id === selectedId) || null;

    async function updateStatus(reportId, nextStatus) {
        setBusy(true);
        setError(null);
        try {
            await patchAdminReport(reportId, nextStatus);
            await load();
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setBusy(false);
        }
    }

    async function removeAndClose(report) {
        const label = reportContextLabel(report.targetSnapshot, report.targetKind);
        // eslint-disable-next-line no-alert
        if (!window.confirm(`Remove reported content and mark actioned?\n\n${label}`)) {
            return;
        }
        setBusy(true);
        setError(null);
        try {
            if (report.targetKind !== 'other') {
                await removeReportedContent(report);
            }
            await patchAdminReport(report.id, 'actioned');
            setSelectedId(null);
            await load();
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setBusy(false);
        }
    }

    const page = Math.floor(offset / PAGE_SIZE) + 1;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <div className="admin__controls">
                <FormField label="Queue" htmlFor="admin-reports-status" className="form-field--fixed">
                    <select
                        id="admin-reports-status"
                        className="field"
                        value={status}
                        onChange={(e) => {
                            setStatus(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                        }}
                    >
                        {STATUSES.map((s) => (
                            <option key={s.id} value={s.id}>{s.label}</option>
                        ))}
                    </select>
                </FormField>
                <div className="admin__control admin__control--end">
                    {!loading && (
                        <span className="admin__count tnum">{total} report{total === 1 ? '' : 's'}</span>
                    )}
                    <button type="button" className="btn btn--ghost btn--sm" onClick={load} disabled={busy}>
                        Refresh
                    </button>
                </div>
            </div>

            {error && (
                <div className="admin__body-pad">
                    <p className="status status--err">{error}</p>
                </div>
            )}
            {loading && <p className="admin__loading admin__body-pad">Loading reports…</p>}

            {!loading && items.length === 0 && !error && (
                <p className="admin__empty">No reports in this queue.</p>
            )}

            {!loading && items.length > 0 && (
                <div className={`admin__split${selected ? ' admin__split--open admin__body-pad' : ''}`}>
                    <div className="admin__table-wrap admin__table-wrap--flush">
                        <table className="admin__table">
                            <thead>
                                <tr>
                                    <th>When</th>
                                    <th>Status</th>
                                    <th>Reason</th>
                                    <th>Target</th>
                                    <th>Reporter</th>
                                </tr>
                            </thead>
                            <tbody>
                                {items.map((row) => {
                                    const isSelected = row.id === selectedId;
                                    return (
                                        <tr
                                            key={row.id}
                                            className={`admin__row--clickable${isSelected ? ' admin__row--selected' : ''}`}
                                            onClick={() => setSelectedId(isSelected ? null : row.id)}
                                        >
                                            <td className="mono">{formatDate(row.createdAt)}</td>
                                            <td>
                                                <span className={statusClass(row.status)}>{row.status}</span>
                                            </td>
                                            <td>{reasonLabel(row.reason)}</td>
                                            <td>
                                                <div className="mono">
                                                    {reportContextLabel(row.targetSnapshot, row.targetKind)}
                                                </div>
                                                <div className="admin__target-kind">{row.targetKind}</div>
                                            </td>
                                            <td className="mono">{row.reporterKerberos}</td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>

                    {selected && (
                        <ReportDetail
                            report={selected}
                            busy={busy}
                            onReview={() => updateStatus(selected.id, 'reviewed')}
                            onDismiss={() => updateStatus(selected.id, 'dismissed')}
                            onRemove={() => removeAndClose(selected)}
                            onActioned={() => updateStatus(selected.id, 'actioned')}
                        />
                    )}
                </div>
            )}

            {total > PAGE_SIZE && (
                <div className="admin__pager admin__body-pad">
                    <span className="tnum">
                        Page {page} of {pageCount} · {total} total
                    </span>
                    <span className="admin__control admin__control--end">
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={offset === 0 || busy}
                            onClick={() => setOffset(Math.max(0, offset - PAGE_SIZE))}
                        >
                            Previous
                        </button>
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={offset + PAGE_SIZE >= total || busy}
                            onClick={() => setOffset(offset + PAGE_SIZE)}
                        >
                            Next
                        </button>
                    </span>
                </div>
            )}
        </>
    );
}
