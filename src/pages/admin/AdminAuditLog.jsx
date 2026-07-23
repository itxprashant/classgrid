import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import FormField from '../../components/FormField/FormField';
import { adminErrorMessage, fetchAdminAuditLog } from '../../utils/adminApi';
import {
    AUDIT_ACTIONS,
    AUDIT_TARGET_KINDS,
    auditDetailRows,
    auditSiteLinks,
    auditSummary,
    formatAuditAction,
    formatAuditActor,
    formatClient,
    formatTargetKind,
} from '../../utils/adminAuditLog';
import { adminSelectableRowProps } from '../../utils/adminSelectableRow';
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

function truncateId(id, max = 20) {
    if (!id) return '—';
    if (id.length <= max) return id;
    return `${id.slice(0, max)}…`;
}

function AuditDetail({ entry }) {
    const [showRaw, setShowRaw] = useState(false);
    const links = auditSiteLinks(entry);
    const rows = auditDetailRows(entry);

    return (
        <aside className="admin__detail-panel" aria-label="Audit entry detail">
            <div className="admin__detail-id">Entry {entry.id.slice(0, 8)}…</div>
            <p className="admin__detail-heading">{formatAuditAction(entry.action)}</p>
            <p className="admin__detail-text">
                <span className="badge">{formatTargetKind(entry.targetKind)}</span>
                {' · '}
                <span className="mono">{formatAuditActor(entry)}</span>
            </p>

            <dl className="admin__detail-dl">
                {rows.map((row) => (
                    <div key={row.label}>
                        <dt>{row.label}</dt>
                        <dd>{row.value}</dd>
                    </div>
                ))}
            </dl>

            {links.length > 0 && (
                <div className="admin__audit-links">
                    {links.map((link) => (
                        <Link key={link.to} to={link.to} className="admin__back">
                            {link.label} →
                        </Link>
                    ))}
                </div>
            )}

            <button
                type="button"
                className="btn btn--ghost btn--sm admin__detail-toggle"
                onClick={() => setShowRaw((v) => !v)}
            >
                {showRaw ? 'Hide raw metadata' : 'Show raw metadata'}
            </button>
            {showRaw && (
                <pre className="admin__detail-raw">{JSON.stringify(entry.metadata || {}, null, 2)}</pre>
            )}
        </aside>
    );
}

export default function AdminAuditLog() {
    const [since, setSince] = useState('');
    const [action, setAction] = useState('');
    const [targetKind, setTargetKind] = useState('');
    const [actorInput, setActorInput] = useState('');
    const [actorKerberos, setActorKerberos] = useState('');
    const [offset, setOffset] = useState(0);
    const [items, setItems] = useState([]);
    const [total, setTotal] = useState(0);
    const [selectedId, setSelectedId] = useState(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const applyActorFilter = useCallback(() => {
        setActorKerberos(actorInput.trim().toLowerCase());
        setOffset(0);
        setSelectedId(null);
    }, [actorInput]);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const data = await fetchAdminAuditLog({
                limit: PAGE_SIZE,
                offset,
                action,
                targetKind,
                since,
                actorKerberos,
            });
            setItems(data.entries || []);
            setTotal(data.total || 0);
            setSelectedId((prev) => {
                if (prev && !(data.entries || []).some((e) => e.id === prev)) {
                    return null;
                }
                return prev;
            });
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setLoading(false);
        }
    }, [offset, action, targetKind, since, actorKerberos]);

    useEffect(() => {
        load();
    }, [load]);

    const selected = items.find((e) => e.id === selectedId) || null;
    const page = Math.floor(offset / PAGE_SIZE) + 1;
    const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

    return (
        <>
            <div className="admin__controls admin__controls--wrap">
                <FormField label="Since" htmlFor="admin-audit-since" className="form-field--sm">
                    <input
                        id="admin-audit-since"
                        type="date"
                        className="field"
                        value={since}
                        onChange={(e) => {
                            setSince(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                        }}
                    />
                </FormField>
                <FormField label="Action" htmlFor="admin-audit-action" className="form-field--fixed">
                    <select
                        id="admin-audit-action"
                        className="field"
                        value={action}
                        onChange={(e) => {
                            setAction(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                        }}
                    >
                        <option value="">All actions</option>
                        {AUDIT_ACTIONS.map((group) => (
                            <optgroup key={group.group} label={group.group}>
                                {group.actions.map((a) => (
                                    <option key={a.id} value={a.id}>{a.label}</option>
                                ))}
                            </optgroup>
                        ))}
                    </select>
                </FormField>
                <FormField label="Target" htmlFor="admin-audit-target" className="form-field--fixed">
                    <select
                        id="admin-audit-target"
                        className="field"
                        value={targetKind}
                        onChange={(e) => {
                            setTargetKind(e.target.value);
                            setOffset(0);
                            setSelectedId(null);
                        }}
                    >
                        <option value="">All targets</option>
                        {AUDIT_TARGET_KINDS.map((k) => (
                            <option key={k.id} value={k.id}>{k.label}</option>
                        ))}
                    </select>
                </FormField>
                <FormField label="Actor" htmlFor="admin-audit-actor" className="form-field--fixed">
                    <input
                        id="admin-audit-actor"
                        type="text"
                        className="field mono"
                        placeholder="kerberos"
                        value={actorInput}
                        onChange={(e) => setActorInput(e.target.value)}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter') applyActorFilter();
                        }}
                        onBlur={applyActorFilter}
                    />
                </FormField>
                <div className="admin__control admin__control--end">
                    {!loading && (
                        <span className="admin__count tnum">{total} entr{total === 1 ? 'y' : 'ies'}</span>
                    )}
                    {(since || action || targetKind || actorKerberos) && (
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            onClick={() => {
                                setSince('');
                                setAction('');
                                setTargetKind('');
                                setActorInput('');
                                setActorKerberos('');
                                setOffset(0);
                                setSelectedId(null);
                            }}
                        >
                            Clear filters
                        </button>
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
                <p className="admin__loading admin__body-pad" role="status" aria-live="polite">
                    Loading audit log…
                </p>
            )}

            {!loading && items.length === 0 && !error && (
                <p className="admin__empty">No audit entries match these filters.</p>
            )}

            {!loading && items.length > 0 && (
                <div className={`admin__split${selected ? ' admin__split--open admin__body-pad' : ''}`}>
                    <div className="admin__table-wrap admin__table-wrap--flush">
                        <table className="admin__table">
                            <thead>
                                <tr>
                                    <th scope="col">When</th>
                                    <th scope="col">Action</th>
                                    <th scope="col">Actor</th>
                                    <th scope="col">Target</th>
                                    <th scope="col">Summary</th>
                                    <th scope="col">Client</th>
                                </tr>
                            </thead>
                            <tbody>
                                {items.map((row) => {
                                    const isSelected = row.id === selectedId;
                                    const toggleRow = () => setSelectedId(isSelected ? null : row.id);
                                    return (
                                        <tr
                                            key={row.id}
                                            className={`admin__row--clickable${isSelected ? ' admin__row--selected' : ''}`}
                                            {...adminSelectableRowProps(isSelected, toggleRow)}
                                        >
                                            <td className="mono">{formatDate(row.occurredAt)}</td>
                                            <td>
                                                <span className="badge">{formatAuditAction(row.action)}</span>
                                            </td>
                                            <td>
                                                {row.actorName
                                                    && row.actorKerberos
                                                    && row.actorName.toLowerCase() !== row.actorKerberos.toLowerCase() ? (
                                                    <>
                                                        <div>{row.actorName}</div>
                                                        <div className="mono admin__target-kind">{row.actorKerberos}</div>
                                                    </>
                                                ) : (
                                                    <span className="mono">{formatAuditActor(row)}</span>
                                                )}
                                            </td>
                                            <td>
                                                <div className="mono">{truncateId(row.targetId)}</div>
                                                <div className="admin__target-kind">{row.targetKind}</div>
                                            </td>
                                            <td>{auditSummary(row)}</td>
                                            <td className="mono">{formatClient(row.client)}</td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>
                    {selected && <AuditDetail entry={selected} />}
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
                            disabled={offset + PAGE_SIZE >= total}
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
