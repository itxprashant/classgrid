import React, { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../auth/AuthContext';
import FormField from '../FormField/FormField';
import { fetchCoursePolicy, saveCoursePolicy } from '../../utils/coursePolicyApi';
import ReportContentPanel from '../ReportContent/ReportContentPanel';
import {
    POLICY_FIELDS,
    actorsMatch,
    emptyPolicyDraft,
    formatPolicyActorLine,
    isPolicySubmittable,
    policyHasContent,
    policyPayload,
} from '../../utils/coursePolicy';
import './CoursePolicy.css';

function PolicySubsection({ label, text }) {
    if (!text || !String(text).trim()) return null;
    return (
        <div className="cdpolicy__subsection">
            <h3 className="cd__h3">{label}</h3>
            <p className="cdpolicy__body">{text}</p>
        </div>
    );
}

function PolicyMeta({ policy }) {
    if (!policy) return null;
    const added = formatPolicyActorLine(policy.createdBy);
    const edited = formatPolicyActorLine(policy.updatedBy);
    const showEdited = policy.updatedBy && !actorsMatch(policy.createdBy, policy.updatedBy);

    return (
        <div className="cdpolicy__meta">
            {added && (
                <p className="cdpolicy__meta-line">
                    Added by <span className="mono">{added}</span>
                </p>
            )}
            {showEdited && edited && (
                <p className="cdpolicy__meta-line">
                    Last edited by <span className="mono">{edited}</span>
                </p>
            )}
        </div>
    );
}

function PolicySkeleton() {
    return (
        <div className="cdpolicy__skeleton" aria-hidden>
            <div className="cdpolicy__skeleton-bar" />
            <div className="cdpolicy__skeleton-bar" />
            <div className="cdpolicy__skeleton-bar" />
        </div>
    );
}

export default function CoursePolicySection({ courseCode }) {
    const { user } = useAuth();
    const [policy, setPolicy] = useState(null);
    const [loading, setLoading] = useState(true);
    const [loadError, setLoadError] = useState(null);
    const [editing, setEditing] = useState(false);
    const [draft, setDraft] = useState(emptyPolicyDraft());
    const [saving, setSaving] = useState(false);
    const [saveError, setSaveError] = useState(null);
    const [saveOk, setSaveOk] = useState(false);
    const [reportOpen, setReportOpen] = useState(false);

    const loadPolicy = useCallback(async () => {
        setLoading(true);
        setLoadError(null);
        try {
            const data = await fetchCoursePolicy(courseCode);
            setPolicy(data.policy);
        } catch (e) {
            setLoadError(e.message || 'Could not load course policy');
        } finally {
            setLoading(false);
        }
    }, [courseCode]);

    useEffect(() => {
        loadPolicy();
    }, [loadPolicy]);

    const startEdit = () => {
        setDraft(emptyPolicyDraft(policy));
        setSaveError(null);
        setSaveOk(false);
        setEditing(true);
    };

    const cancelEdit = () => {
        setEditing(false);
        setSaveError(null);
        setSaveOk(false);
    };

    const onFieldChange = (key, value) => {
        setDraft((prev) => ({ ...prev, [key]: value }));
        setSaveOk(false);
    };

    const onSave = async () => {
        if (!isPolicySubmittable(draft)) return;
        setSaving(true);
        setSaveError(null);
        setSaveOk(false);
        try {
            const saved = await saveCoursePolicy(courseCode, policyPayload(draft));
            setPolicy(saved);
            setEditing(false);
            setSaveOk(true);
        } catch (e) {
            setSaveError(e.message || 'Could not save policy');
        } finally {
            setSaving(false);
        }
    };

    const hasContent = policyHasContent(policy);
    const showEditToggle = hasContent && !editing;

    return (
        <section className="cd__section">
            <div className="cd__section-head cdpolicy__section-head">
                <h2 className="cd__h2">Course policy</h2>
                <div className="cdpolicy__section-actions">
                    {showEditToggle && user && hasContent && !reportOpen && (
                        <button
                            type="button"
                            className="btn btn--sm btn--ghost"
                            onClick={() => setReportOpen(true)}
                        >
                            Report policy
                        </button>
                    )}
                    {showEditToggle && (
                        <button type="button" className="btn btn--sm btn--ghost" onClick={startEdit}>
                            Edit
                        </button>
                    )}
                    {editing && (
                        <button type="button" className="btn btn--sm btn--ghost" onClick={cancelEdit}>
                            Cancel
                        </button>
                    )}
                </div>
            </div>

            <div className="panel cdpolicy__read">
                {loading ? (
                    <PolicySkeleton />
                ) : loadError ? (
                    <div className="empty">
                        <strong>{loadError}</strong>
                        <button type="button" className="btn btn--sm btn--ghost" onClick={loadPolicy}>
                            Retry
                        </button>
                    </div>
                ) : !hasContent && !editing ? (
                    <div className="cdpolicy__empty empty">
                        <strong>No policy yet.</strong>
                        <p className="muted">Add marking and attendance rules for your section.</p>
                        <button type="button" className="btn btn--primary btn--sm" onClick={startEdit}>
                            Add policy
                        </button>
                    </div>
                ) : (
                    <>
                        {POLICY_FIELDS.map(({ key, label }) => (
                            <PolicySubsection
                                key={key}
                                label={label.toUpperCase()}
                                text={policy?.[key]}
                            />
                        ))}
                        <PolicyMeta policy={policy} />
                    </>
                )}
            </div>

            {reportOpen && hasContent && !editing && (
                <div className="panel cdpolicy__report">
                    <ReportContentPanel
                        targetKind="course_policy"
                        targetId={courseCode}
                        contextLabel={`${courseCode} · course policy`}
                        onDone={() => setReportOpen(false)}
                        onCancel={() => setReportOpen(false)}
                    />
                </div>
            )}

            {editing && (
                <div className="cdpolicy__edit">
                    <div className="rule" />
                    <div className="cdpolicy__edit-fields">
                        {POLICY_FIELDS.map(({ key, label, placeholder }) => (
                            <FormField
                                key={key}
                                label={label}
                                htmlFor={`cdpolicy-${key}`}
                                className="cdpolicy__form-row"
                                wide
                            >
                                <textarea
                                    id={`cdpolicy-${key}`}
                                    className="field cdpolicy__form-note"
                                    rows={3}
                                    value={draft[key]}
                                    placeholder={placeholder}
                                    onChange={(e) => onFieldChange(key, e.target.value)}
                                />
                            </FormField>
                        ))}
                    </div>

                    {(draft.createdBy || draft.updatedBy) && (
                        <div className="cdpolicy__meta">
                            {draft.createdBy && (
                                <p className="cdpolicy__meta-line">
                                    Added by{' '}
                                    <span className="mono">{formatPolicyActorLine(draft.createdBy)}</span>
                                </p>
                            )}
                            {draft.updatedBy &&
                                !actorsMatch(draft.createdBy, draft.updatedBy) && (
                                <p className="cdpolicy__meta-line">
                                    Last edited by{' '}
                                    <span className="mono">{formatPolicyActorLine(draft.updatedBy)}</span>
                                </p>
                            )}
                        </div>
                    )}

                    {saveError && (
                        <p className="status status--err" role="alert">{saveError}</p>
                    )}
                    {saveOk && (
                        <p className="status status--ok" role="status">Policy saved.</p>
                    )}

                    <div className="cdpolicy__actions">
                        <button
                            type="button"
                            className="btn btn--primary"
                            disabled={!isPolicySubmittable(draft) || saving}
                            onClick={onSave}
                        >
                            {saving ? 'Saving…' : 'Save policy'}
                        </button>
                        <button type="button" className="btn btn--ghost" onClick={cancelEdit}>
                            Cancel
                        </button>
                    </div>
                </div>
            )}
        </section>
    );
}
