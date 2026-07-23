import React, { useCallback, useEffect, useState } from 'react';
import FormField from '../../components/FormField/FormField';
import { FEEDBACK_CATEGORIES } from '../../utils/feedback';
import {
    adminErrorMessage,
    fetchAdminFeedback,
    fetchAdminFeedbackEmailDraft,
    patchAdminFeedback,
    sendAdminFeedbackEmail,
} from '../../utils/adminApi';
import { formatClient } from '../../utils/adminAuditLog';
import { adminSelectableRowProps } from '../../utils/adminSelectableRow';
import AdminEmailCompose from './AdminEmailCompose';
import './admin.css';

const PAGE_SIZE = 40;
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

function categoryLabel(id) {
    return FEEDBACK_CATEGORIES.find((c) => c.id === id)?.label || id;
}

function statusClass(status) {
    if (status === 'open') return 'badge admin__status--open';
    if (status === 'actioned') return 'badge admin__status--actioned';
    if (status === 'dismissed' || status === 'reviewed') return 'badge admin__status--dismissed';
    return 'badge';
}

function canEmailFeedback(item) {
    return Boolean(item.kerberos || item.reporterEmail);
}

function FeedbackDetail({
    item,
    busy,
    composing,
    onReview,
    onDismiss,
    onActioned,
    onEmail,
    onCloseEmail,
    onSendEmail,
    emailDraftLoader,
}) {
    return (
        <aside className="admin__detail-panel" aria-label="Feedback detail">
            <div className="admin__detail-id">Feedback {item.id.slice(0, 8)}…</div>
            <p className="admin__detail-heading">{categoryLabel(item.category)}</p>
            <p className="admin__detail-text">
                <span className={statusClass(item.status)}>{item.status}</span>
                {' · '}
                <span className="mono">{item.kerberos || item.reporterName || 'Guest'}</span>
                {' · '}
                {formatClient(item.client)}
            </p>

            <p className="admin__detail-text">{item.message}</p>

            <dl className="admin__detail-dl">
                <div>
                    <dt>When</dt>
                    <dd className="mono">{formatDate(item.createdAt)}</dd>
                </div>
                {item.reporterEmail && (
                    <div>
                        <dt>Email</dt>
                        <dd className="mono">{item.reporterEmail}</dd>
                    </div>
                )}
                {item.pageContext && (
                    <div>
                        <dt>Page</dt>
                        <dd className="mono">{item.pageContext}</dd>
                    </div>
                )}
            </dl>

            {composing ? (
                <AdminEmailCompose
                    kind="feedback"
                    templateName="feedback-review"
                    draftLoader={emailDraftLoader}
                    onSend={onSendEmail}
                    onClose={onCloseEmail}
                    busy={busy}
                />
            ) : (
                <div className="admin__actions">
                    {canEmailFeedback(item) && (
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={busy}
                            onClick={onEmail}
                        >
                            Email user
                        </button>
                    )}
                    {item.status === 'open' && (
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
                            <button
                                type="button"
                                className="btn btn--primary btn--sm"
                                disabled={busy}
                                onClick={onActioned}
                            >
                                Mark actioned
                            </button>
                        </>
                    )}
                    {item.status !== 'open' && item.reviewedAt && (
                        <span className="admin__reviewed">
                            Reviewed {formatDate(item.reviewedAt)}
                            {item.reviewedByKerberos ? ` · ${item.reviewedByKerberos}` : ''}
                        </span>
                    )}
                </div>
            )}
        </aside>
    );
}

export default function AdminFeedback() {
    const [status, setStatus] = useState('open');
    const [category, setCategory] = useState('');
    const [offset, setOffset] = useState(0);
    const [items, setItems] = useState([]);
    const [total, setTotal] = useState(0);
    const [selectedId, setSelectedId] = useState(null);
    const [composingEmail, setComposingEmail] = useState(false);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [busy, setBusy] = useState(false);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await fetchAdminFeedback({
                limit: PAGE_SIZE,
                offset,
                status,
                category,
            });
            setItems(data.items || []);
            setTotal(data.total || 0);
            setSelectedId((prev) => {
                if (prev && !(data.items || []).some((r) => r.id === prev)) {
                    setComposingEmail(false);
                    return null;
                }
                return prev;
            });
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setLoading(false);
        }
    }, [offset, status, category]);

    useEffect(() => {
        load();
    }, [load]);

    const selected = items.find((r) => r.id === selectedId) || null;

    const emailDraftLoader = useCallback(
        () => fetchAdminFeedbackEmailDraft(selectedId),
        [selectedId],
    );

    async function updateStatus(feedbackId, nextStatus) {
        setBusy(true);
        setError(null);
        try {
            await patchAdminFeedback(feedbackId, nextStatus);
            setComposingEmail(false);
            setSelectedId(null);
            await load();
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setBusy(false);
        }
    }

    async function sendEmail(payload) {
        setBusy(true);
        setError(null);
        try {
            await sendAdminFeedbackEmail(selectedId, payload);
            setComposingEmail(false);
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
            throw e;
        } finally {
            setBusy(false);
        }
    }

    const page = Math.floor(offset / PAGE_SIZE) + 1;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <div className="admin__controls admin__controls--wrap">
                <FormField label="Queue" htmlFor="admin-feedback-status" className="form-field--fixed">
                    <select
                        id="admin-feedback-status"
                        className="field"
                        value={status}
                        onChange={(e) => {
                            setStatus(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                            setComposingEmail(false);
                        }}
                    >
                        {STATUSES.map((s) => (
                            <option key={s.id} value={s.id}>{s.label}</option>
                        ))}
                    </select>
                </FormField>
                <FormField label="Category" htmlFor="admin-feedback-category" className="form-field--fixed">
                    <select
                        id="admin-feedback-category"
                        className="field"
                        value={category}
                        onChange={(e) => {
                            setCategory(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                            setComposingEmail(false);
                        }}
                    >
                        <option value="">All categories</option>
                        {FEEDBACK_CATEGORIES.map((c) => (
                            <option key={c.id} value={c.id}>{c.label}</option>
                        ))}
                    </select>
                </FormField>
                <div className="admin__control admin__control--end">
                    {!loading && (
                        <span className="admin__count tnum">{total} submission{total === 1 ? '' : 's'}</span>
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

            {loading && (
                <p className="admin__loading admin__body-pad" role="status" aria-live="polite">
                    Loading feedback…
                </p>
            )}

            {!loading && items.length === 0 && !error && (
                <p className="admin__empty">No feedback in this queue.</p>
            )}

            {!loading && items.length > 0 && (
                <div className={`admin__split${selected ? ' admin__split--open admin__body-pad' : ''}`}>
                    <div className="admin__table-wrap admin__table-wrap--flush">
                        <table className="admin__table">
                            <thead>
                                <tr>
                                    <th scope="col">When</th>
                                    <th scope="col">Status</th>
                                    <th scope="col">Category</th>
                                    <th scope="col">From</th>
                                    <th scope="col">Client</th>
                                    <th scope="col">Message</th>
                                </tr>
                            </thead>
                            <tbody>
                                {items.map((row) => {
                                    const isSelected = row.id === selectedId;
                                    const toggleRow = () => {
                                        setSelectedId(isSelected ? null : row.id);
                                        setComposingEmail(false);
                                    };
                                    const preview = row.message.length > 100
                                        ? `${row.message.slice(0, 100)}…`
                                        : row.message;
                                    return (
                                        <tr
                                            key={row.id}
                                            className={`admin__row--clickable${isSelected ? ' admin__row--selected' : ''}`}
                                            {...adminSelectableRowProps(isSelected, toggleRow)}
                                        >
                                            <td className="mono">{formatDate(row.createdAt)}</td>
                                            <td>
                                                <span className={statusClass(row.status)}>{row.status}</span>
                                            </td>
                                            <td>
                                                <span className="badge">{categoryLabel(row.category)}</span>
                                            </td>
                                            <td className="mono">
                                                {row.kerberos || row.reporterName || 'Guest'}
                                            </td>
                                            <td className="mono">{formatClient(row.client)}</td>
                                            <td>
                                                <div className="admin__message">{preview}</div>
                                                {row.pageContext && (
                                                    <div className="dim mono admin__context">
                                                        {row.pageContext}
                                                    </div>
                                                )}
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>

                    {selected && (
                        <FeedbackDetail
                            item={selected}
                            busy={busy}
                            composing={composingEmail}
                            emailDraftLoader={emailDraftLoader}
                            onReview={() => updateStatus(selected.id, 'reviewed')}
                            onDismiss={() => updateStatus(selected.id, 'dismissed')}
                            onActioned={() => updateStatus(selected.id, 'actioned')}
                            onEmail={() => setComposingEmail(true)}
                            onCloseEmail={() => setComposingEmail(false)}
                            onSendEmail={sendEmail}
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
                            onClick={() => {
                                setOffset(Math.max(0, offset - PAGE_SIZE));
                                setSelectedId(null);
                            }}
                        >
                            Previous
                        </button>
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={offset + PAGE_SIZE >= total || busy}
                            onClick={() => {
                                setOffset(offset + PAGE_SIZE);
                                setSelectedId(null);
                            }}
                        >
                            Next
                        </button>
                    </span>
                </div>
            )}
        </>
    );
}
