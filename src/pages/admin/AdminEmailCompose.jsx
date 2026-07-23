import React, { useEffect, useState } from 'react';
import FormField from '../../components/FormField/FormField';
import {
    adminErrorMessage,
    fetchAdminEmailTemplate,
    putAdminEmailTemplate,
} from '../../utils/adminApi';

/**
 * Inline compose + optional template editor for feedback/report reply emails.
 */
export default function AdminEmailCompose({
    kind,
    templateName,
    draftLoader,
    onSend,
    onClose,
    busy,
}) {
    const [to, setTo] = useState('');
    const [subject, setSubject] = useState('');
    const [body, setBody] = useState('');
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);
    const [mailOk, setMailOk] = useState(true);
    const [showTemplate, setShowTemplate] = useState(false);
    const [templateBody, setTemplateBody] = useState('');
    const [templatePlaceholders, setTemplatePlaceholders] = useState([]);
    const [templateBusy, setTemplateBusy] = useState(false);
    const [templateNote, setTemplateNote] = useState(null);

    useEffect(() => {
        let cancelled = false;
        (async () => {
            setLoading(true);
            setError(null);
            try {
                const data = await draftLoader();
                if (cancelled) return;
                setTo(data.draft?.to || '');
                setSubject(data.draft?.subject || '');
                setBody(data.draft?.body || '');
                setMailOk(data.mailConfigured !== false);
            } catch (e) {
                if (!cancelled) setError(adminErrorMessage(e.code || e.message));
            } finally {
                if (!cancelled) setLoading(false);
            }
        })();
        return () => { cancelled = true; };
    }, [draftLoader]);

    async function openTemplateEditor() {
        setShowTemplate(true);
        setTemplateNote(null);
        setTemplateBusy(true);
        setError(null);
        try {
            const data = await fetchAdminEmailTemplate(templateName);
            setTemplateBody(data.body || '');
            setTemplatePlaceholders(data.placeholders || []);
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
            setShowTemplate(false);
        } finally {
            setTemplateBusy(false);
        }
    }

    async function saveTemplate() {
        setTemplateBusy(true);
        setTemplateNote(null);
        setError(null);
        try {
            await putAdminEmailTemplate(templateName, templateBody);
            setTemplateNote('Template saved on the API host. Re-open Email to refresh the draft.');
        } catch (e) {
            setError(adminErrorMessage(e.code || e.message));
        } finally {
            setTemplateBusy(false);
        }
    }

    async function handleSend(e) {
        e.preventDefault();
        setError(null);
        // eslint-disable-next-line no-alert
        if (!window.confirm(`Send this email to ${to}?`)) return;
        try {
            await onSend({ to, subject, body });
        } catch (err) {
            setError(adminErrorMessage(err.code || err.message));
        }
    }

    if (loading) {
        return (
            <div className="admin__email">
                <p className="admin__loading" role="status">Loading draft…</p>
            </div>
        );
    }

    return (
        <div className="admin__email">
            <div className="admin__email-head">
                <p className="admin__email-title">Email {kind}</p>
                <button type="button" className="btn btn--ghost btn--sm" onClick={onClose} disabled={busy}>
                    Close
                </button>
            </div>

            {!mailOk && (
                <p className="status status--err">
                    SMTP is not configured on the server (SMTP_USER / SMTP_PASS).
                </p>
            )}
            {error && <p className="status status--err">{error}</p>}
            {templateNote && <p className="status status--ok">{templateNote}</p>}

            <form className="admin__email-form" onSubmit={handleSend}>
                <FormField label="To" htmlFor={`admin-email-to-${kind}`} className="form-field--wide">
                    <input
                        id={`admin-email-to-${kind}`}
                        className="field mono"
                        type="email"
                        value={to}
                        onChange={(ev) => setTo(ev.target.value)}
                        disabled={busy || !mailOk}
                        required
                    />
                </FormField>
                <FormField label="Subject" htmlFor={`admin-email-subject-${kind}`} className="form-field--wide">
                    <input
                        id={`admin-email-subject-${kind}`}
                        className="field"
                        type="text"
                        maxLength={200}
                        value={subject}
                        onChange={(ev) => setSubject(ev.target.value)}
                        disabled={busy || !mailOk}
                        required
                    />
                </FormField>
                <FormField label="Body" htmlFor={`admin-email-body-${kind}`} className="form-field--wide">
                    <textarea
                        id={`admin-email-body-${kind}`}
                        className="field admin__email-body"
                        rows={14}
                        value={body}
                        onChange={(ev) => setBody(ev.target.value)}
                        disabled={busy || !mailOk}
                        required
                    />
                </FormField>
                <p className="admin__email-hint dim">
                    Write your reply above the quoted message. From: prashant@devclub.in
                </p>
                <div className="admin__actions">
                    <button
                        type="submit"
                        className="btn btn--primary btn--sm"
                        disabled={busy || !mailOk || !to.trim()}
                    >
                        {busy ? 'Sending…' : 'Send email'}
                    </button>
                    <button
                        type="button"
                        className="btn btn--ghost btn--sm"
                        disabled={busy || templateBusy}
                        onClick={showTemplate ? () => setShowTemplate(false) : openTemplateEditor}
                    >
                        {showTemplate ? 'Hide template' : 'Edit template'}
                    </button>
                </div>
            </form>

            {showTemplate && (
                <div className="admin__email-template">
                    <p className="admin__email-hint dim">
                        Placeholders:{' '}
                        {templatePlaceholders.map((p) => `{{${p}}}`).join(' · ') || '—'}
                    </p>
                    <FormField
                        label={`Template (${templateName}.txt)`}
                        htmlFor={`admin-email-template-${kind}`}
                        className="form-field--wide"
                    >
                        <textarea
                            id={`admin-email-template-${kind}`}
                            className="field admin__email-body"
                            rows={12}
                            value={templateBody}
                            onChange={(ev) => setTemplateBody(ev.target.value)}
                            disabled={templateBusy}
                        />
                    </FormField>
                    <div className="admin__actions">
                        <button
                            type="button"
                            className="btn btn--ghost btn--sm"
                            disabled={templateBusy}
                            onClick={saveTemplate}
                        >
                            {templateBusy ? 'Saving…' : 'Save template'}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
