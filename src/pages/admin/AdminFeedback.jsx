import React, { useCallback, useEffect, useState } from 'react';
import FormField from '../../components/FormField/FormField';
import { FEEDBACK_CATEGORIES } from '../../utils/feedback';
import { adminErrorMessage, fetchAdminFeedback } from '../../utils/adminApi';
import './admin.css';

const PAGE_SIZE = 40;

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

export default function AdminFeedback() {
    const [category, setCategory] = useState('');
    const [offset, setOffset] = useState(0);
    const [items, setItems] = useState([]);
    const [total, setTotal] = useState(0);
    const [expandedId, setExpandedId] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await fetchAdminFeedback({
                limit: PAGE_SIZE,
                offset,
                category,
            });
            setItems(data.items || []);
            setTotal(data.total || 0);
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setLoading(false);
        }
    }, [offset, category]);

    useEffect(() => {
        load();
    }, [load]);

    const page = Math.floor(offset / PAGE_SIZE) + 1;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <div className="admin__controls">
                <FormField label="Category" htmlFor="admin-feedback-category" className="form-field--fixed">
                    <select
                        id="admin-feedback-category"
                        className="field"
                        value={category}
                        onChange={(e) => {
                            setCategory(e.target.value);
                            setOffset(0);
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
                    <button type="button" className="btn btn--ghost btn--sm" onClick={load}>
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
                <p className="admin__loading admin__body-pad">Loading feedback…</p>
            )}

            {!loading && items.length === 0 && !error && (
                <p className="admin__empty">No feedback in this filter yet.</p>
            )}

            {!loading && items.length > 0 && (
                <div className="admin__table-wrap admin__table-wrap--flush">
                    <table className="admin__table">
                        <thead>
                            <tr>
                                <th>When</th>
                                <th>Category</th>
                                <th>From</th>
                                <th>Client</th>
                                <th>Message</th>
                            </tr>
                        </thead>
                        <tbody>
                            {items.map((row) => {
                                const expanded = expandedId === row.id;
                                const long = row.message.length > 120;
                                const preview = long && !expanded
                                    ? `${row.message.slice(0, 120)}…`
                                    : row.message;
                                return (
                                    <tr key={row.id}>
                                        <td className="mono">{formatDate(row.createdAt)}</td>
                                        <td>
                                            <span className="badge">{categoryLabel(row.category)}</span>
                                        </td>
                                        <td className="mono">
                                            {row.kerberos || row.reporterName || 'Guest'}
                                        </td>
                                        <td className="mono">{row.client}</td>
                                        <td>
                                            <div className="admin__message">{preview}</div>
                                            {long && (
                                                <button
                                                    type="button"
                                                    className="btn btn--ghost btn--sm admin__expand"
                                                    onClick={() => setExpandedId(expanded ? null : row.id)}
                                                >
                                                    {expanded ? 'Show less' : 'Show more'}
                                                </button>
                                            )}
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
                            disabled={offset === 0}
                            onClick={() => setOffset(Math.max(0, offset - PAGE_SIZE))}
                        >
                            Previous
                        </button>
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={offset + PAGE_SIZE >= total}
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
