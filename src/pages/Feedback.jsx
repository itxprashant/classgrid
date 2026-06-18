import React, { useState } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import FeedbackForm from '../components/FeedbackForm/FeedbackForm';
import ReportContentPanel from '../components/ReportContent/ReportContentPanel';
import './Feedback.css';

export default function Feedback() {
    const location = useLocation();
    const { user, login } = useAuth();
    const params = new URLSearchParams(location.search);
    const pageContext = params.get('from') || location.pathname;
    const [showOtherReport, setShowOtherReport] = useState(false);
    const [otherReportDone, setOtherReportDone] = useState(false);

    return (
        <div className="fb-page">
            <header className="fb-page__head">
                <div className="fb-page__head-text">
                    <div className="fb-page__eyebrow">Help improve ClassGrid</div>
                    <h1 className="fb-page__title">Suggest a feature</h1>
                    <p className="fb-page__lead">
                        Tell us what would make planning your semester easier. We read every
                        submission when prioritizing the roadmap.
                    </p>
                </div>
            </header>

            {!showOtherReport ? (
                <FeedbackForm
                    pageContext={pageContext}
                    showOtherReportLink
                    onOpenOtherReport={() => setShowOtherReport(true)}
                />
            ) : otherReportDone ? (
                <div className="panel fb-page__report-done">
                    <p className="status status--ok" role="status">
                        Thanks. We will review your report.
                    </p>
                    <button
                        type="button"
                        className="btn btn--sm btn--ghost"
                        onClick={() => {
                            setShowOtherReport(false);
                            setOtherReportDone(false);
                        }}
                    >
                        Back to feedback
                    </button>
                </div>
            ) : user ? (
                <div className="panel fb-page__report-panel">
                    <ReportContentPanel
                        targetKind="other"
                        targetId={pageContext || 'page:unknown'}
                        contextLabel={pageContext || 'General report'}
                        pageContext={pageContext}
                        label="Report from feedback page"
                        onDone={() => setOtherReportDone(true)}
                        onCancel={() => setShowOtherReport(false)}
                    />
                </div>
            ) : (
                <div className="panel fb-page__report-login">
                    <p className="status" role="status">
                        Sign in to report wrong information on shared content.
                    </p>
                    <div className="fb__actions">
                        <button type="button" className="btn btn--sm btn--primary" onClick={login}>
                            Log in
                        </button>
                        <button
                            type="button"
                            className="btn btn--sm btn--ghost"
                            onClick={() => setShowOtherReport(false)}
                        >
                            Back
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
