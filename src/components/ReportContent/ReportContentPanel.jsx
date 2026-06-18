import React, { useState } from 'react';
import FormField from '../FormField/FormField';
import { useAuth } from '../../auth/AuthContext';
import { submitReport } from '../../utils/reportsApi';
import { REPORT_REASONS, reportErrorMessage } from '../../utils/feedback';
import './ReportContent.css';

export default function ReportContentPanel({
    targetKind,
    targetId,
    contextLabel,
    pageContext,
    label,
    onDone,
    onCancel,
    compact = false,
}) {
    const { user, login } = useAuth();
    const [reason, setReason] = useState('');
    const [details, setDetails] = useState('');
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState(null);
    const [done, setDone] = useState(false);

    if (!user) {
        return (
            <div className={'rpt__panel' + (compact ? ' rpt__panel--compact' : '')}>
                <p className="status" role="status">
                    Sign in to report content.
                </p>
                <div className="rpt__actions">
                    <button type="button" className="btn btn--sm btn--primary" onClick={login}>
                        Log in
                    </button>
                    {onCancel && (
                        <button type="button" className="btn btn--sm btn--ghost" onClick={onCancel}>
                            Cancel
                        </button>
                    )}
                </div>
            </div>
        );
    }

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!reason) return;
        setSubmitting(true);
        setError(null);
        try {
            await submitReport({
                targetKind,
                targetId,
                reason,
                details: details.trim(),
                pageContext,
                label,
            });
            setDone(true);
            onDone?.();
        } catch (err) {
            setError(reportErrorMessage(err.code || err.message));
        } finally {
            setSubmitting(false);
        }
    };

    if (done) {
        return (
            <div className={'rpt__panel' + (compact ? ' rpt__panel--compact' : '')}>
                <p className="status status--ok" role="status">
                    Thanks. We will review your report.
                </p>
            </div>
        );
    }

    return (
        <form
            className={'rpt__panel' + (compact ? ' rpt__panel--compact' : '')}
            onSubmit={handleSubmit}
        >
            {!compact && (
                <h3 className="rpt__title">Report this</h3>
            )}

            {contextLabel && (
                <p className="rpt__context mono">{contextLabel}</p>
            )}

            <FormField as="fieldset" label="Reason" className="rpt__reasons">
                <div className="rpt__chips" role="radiogroup" aria-label="Report reason">
                    {REPORT_REASONS.map(({ id, label: reasonLabel }) => (
                        <button
                            key={id}
                            type="button"
                            role="radio"
                            aria-checked={reason === id}
                            className={
                                'badge rpt__chip'
                                + (reason === id ? ' badge--accent' : '')
                            }
                            onClick={() => setReason(id)}
                        >
                            {reasonLabel}
                        </button>
                    ))}
                </div>
            </FormField>

            <FormField label="Details (optional)" htmlFor="rpt-details" className="rpt__row" wide>
                <textarea
                    id="rpt-details"
                    className="field rpt__details"
                    rows={3}
                    value={details}
                    placeholder="What looks wrong?"
                    onChange={(e) => setDetails(e.target.value)}
                />
            </FormField>

            {error && (
                <p className="status status--err" role="alert">{error}</p>
            )}

            <div className="rpt__actions">
                {onCancel && (
                    <button type="button" className="btn btn--sm btn--ghost" onClick={onCancel}>
                        Cancel
                    </button>
                )}
                <button
                    type="submit"
                    className="btn btn--sm btn--primary"
                    disabled={submitting || !reason}
                >
                    {submitting ? 'Sending…' : 'Submit report'}
                </button>
            </div>
        </form>
    );
}
