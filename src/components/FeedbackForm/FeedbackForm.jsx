import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import FormField from '../FormField/FormField';
import { useAuth } from '../../auth/AuthContext';
import { submitFeedback } from '../../utils/feedbackApi';
import {
    FEEDBACK_CATEGORIES,
    feedbackErrorMessage,
    isFeedbackSubmittable,
} from '../../utils/feedback';
import './FeedbackForm.css';

export default function FeedbackForm({
    pageContext = '',
    onSuccess,
    showOtherReportLink = false,
    onOpenOtherReport,
}) {
    const { user } = useAuth();
    const [category, setCategory] = useState('feature');
    const [message, setMessage] = useState('');
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState(null);
    const [done, setDone] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!isFeedbackSubmittable(message)) return;
        setSubmitting(true);
        setError(null);
        try {
            await submitFeedback({
                message: message.trim(),
                category,
                pageContext: pageContext || undefined,
                client: 'web',
            });
            setDone(true);
            onSuccess?.();
        } catch (err) {
            setError(feedbackErrorMessage(err.code || err.message));
        } finally {
            setSubmitting(false);
        }
    };

    if (done) {
        return (
            <div className="fb__thanks panel">
                <p className="status status--ok" role="status">
                    Thanks. We will review your suggestion.
                </p>
                <p className="fb__thanks-lead muted">
                    Feature ideas help us prioritize what to build next.
                </p>
                <Link to="/plan" className="btn btn--sm btn--ghost">
                    Back to Plan
                </Link>
            </div>
        );
    }

    return (
        <form className="fb__form panel" onSubmit={handleSubmit}>
            <FormField label="Category" htmlFor="fb-category" className="fb__row">
                <select
                    id="fb-category"
                    className="field"
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                >
                    {FEEDBACK_CATEGORIES.map(({ id, label }) => (
                        <option key={id} value={id}>{label}</option>
                    ))}
                </select>
            </FormField>

            <FormField label="Your idea" htmlFor="fb-message" className="fb__row" wide>
                <textarea
                    id="fb-message"
                    className="field fb__message"
                    rows={6}
                    value={message}
                    placeholder="Describe the feature or improvement you would like to see."
                    onChange={(e) => setMessage(e.target.value)}
                    required
                />
            </FormField>

            {!user && (
                <p className="fb__guest-note muted">
                    Signed in? We can reach you if we have questions.
                </p>
            )}

            {error && (
                <p className="status status--err" role="alert">{error}</p>
            )}

            <div className="fb__actions">
                <button
                    type="submit"
                    className="btn btn--primary"
                    disabled={submitting || !isFeedbackSubmittable(message)}
                >
                    {submitting ? 'Sending…' : 'Send feedback'}
                </button>
            </div>

            {showOtherReportLink && user && onOpenOtherReport && (
                <p className="fb__other muted">
                    Wrong info on the site?{' '}
                    <button type="button" className="fb__inline-link" onClick={onOpenOtherReport}>
                        Report it
                    </button>
                </p>
            )}
        </form>
    );
}
