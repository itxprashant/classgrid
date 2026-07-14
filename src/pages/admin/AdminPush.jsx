import React, { useState } from 'react';
import FormField from '../../components/FormField/FormField';
import { adminErrorMessage, sendAdminPush } from '../../utils/adminApi';
import './admin.css';

const AUDIENCES = [
    { id: 'all', label: 'All app installs (topic broadcast)' },
    { id: 'signed_in', label: 'Signed-in devices only' },
];

export default function AdminPush() {
    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [audience, setAudience] = useState('all');
    const [sending, setSending] = useState(false);
    const [error, setError] = useState(null);
    const [result, setResult] = useState(null);

    async function handleSubmit(e) {
        e.preventDefault();
        setError(null);
        setResult(null);

        const trimmedTitle = title.trim();
        const trimmedBody = body.trim();
        if (!trimmedTitle || !trimmedBody) {
            setError('Enter a title and message body.');
            return;
        }

        const audienceLabel = AUDIENCES.find((a) => a.id === audience)?.label || audience;
        const confirmed = window.confirm(
            `Send this push notification?\n\nAudience: ${audienceLabel}\nTitle: ${trimmedTitle}\n\nThis cannot be undone.`,
        );
        if (!confirmed) return;

        setSending(true);
        try {
            const data = await sendAdminPush({
                title: trimmedTitle,
                body: trimmedBody,
                audience,
            });
            setResult(data);
        } catch (err) {
            setError(adminErrorMessage(err.code || err.message));
        } finally {
            setSending(false);
        }
    }

    return (
        <div className="admin__body-pad">
            <p className="admin-push__lede">
                Send a broadcast notification to the Android app. Local class reminders are
                unchanged — this is for semester updates and announcements only.
            </p>

            {error && (
                <p className="admin-push__flash admin-push__flash--error" role="alert">
                    {error}
                </p>
            )}

            {result && (
                <p className="admin-push__flash admin-push__flash--ok" role="status">
                    Sent to <span className="mono">{result.audience}</span>
                    {' — '}
                    <span className="tnum">{result.successCount}</span> succeeded
                    {typeof result.failureCount === 'number' && result.failureCount > 0 && (
                        <>
                            {', '}
                            <span className="tnum">{result.failureCount}</span> failed
                        </>
                    )}
                </p>
            )}

            <form className="admin-push__form" onSubmit={handleSubmit}>
                <FormField label="Title" htmlFor="admin-push-title" className="form-field--wide">
                    <input
                        id="admin-push-title"
                        className="field"
                        type="text"
                        maxLength={120}
                        value={title}
                        onChange={(ev) => setTitle(ev.target.value)}
                        disabled={sending}
                        required
                    />
                </FormField>

                <FormField label="Message" htmlFor="admin-push-body" className="form-field--wide">
                    <textarea
                        id="admin-push-body"
                        className="field admin-push__body"
                        rows={5}
                        maxLength={500}
                        value={body}
                        onChange={(ev) => setBody(ev.target.value)}
                        disabled={sending}
                        required
                    />
                </FormField>

                <FormField label="Audience" htmlFor="admin-push-audience" className="form-field--wide">
                    <select
                        id="admin-push-audience"
                        className="field"
                        value={audience}
                        onChange={(ev) => setAudience(ev.target.value)}
                        disabled={sending}
                    >
                        {AUDIENCES.map((a) => (
                            <option key={a.id} value={a.id}>{a.label}</option>
                        ))}
                    </select>
                </FormField>

                <div className="admin__actions admin__actions--inline">
                    <button
                        type="submit"
                        className="btn btn--primary"
                        disabled={sending}
                    >
                        {sending ? 'Sending…' : 'Send push'}
                    </button>
                </div>
            </form>
        </div>
    );
}
