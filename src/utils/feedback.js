export const FEEDBACK_CATEGORIES = [
    { id: 'feature', label: 'Feature idea' },
    { id: 'improvement', label: 'Improvement' },
    { id: 'bug', label: 'Bug' },
    { id: 'other', label: 'Other' },
];

export const REPORT_REASONS = [
    { id: 'spam', label: 'Spam' },
    { id: 'wrong_info', label: 'Wrong info' },
    { id: 'offensive', label: 'Offensive' },
    { id: 'duplicate', label: 'Duplicate' },
    { id: 'other', label: 'Other' },
];

export const FEEDBACK_MIN_MESSAGE_LEN = 10;
export const FEEDBACK_MAX_MESSAGE_LEN = 4000;
export const REPORT_MAX_DETAILS_LEN = 2000;

export function isFeedbackSubmittable(message) {
    const trimmed = String(message || '').trim();
    return (
        trimmed.length >= FEEDBACK_MIN_MESSAGE_LEN
        && trimmed.length <= FEEDBACK_MAX_MESSAGE_LEN
    );
}

export function feedbackErrorMessage(code) {
    switch (code) {
        case 'message_too_short':
            return 'Please write at least 10 characters.';
        case 'message_too_long':
            return 'Message is too long.';
        case 'rate_limited':
            return 'Too many submissions recently. Try again later.';
        case 'database_unavailable':
            return 'Service temporarily unavailable.';
        default:
            return 'Could not send feedback. Try again.';
    }
}

export function reportErrorMessage(code) {
    switch (code) {
        case 'duplicate_report':
            return 'You already reported this. We will follow up if needed.';
        case 'not_authenticated':
            return 'Sign in to report content.';
        case 'target_not_found':
            return 'This content could not be found. It may have been removed.';
        case 'invalid_reason':
            return 'Choose a reason for your report.';
        case 'database_unavailable':
            return 'Service temporarily unavailable.';
        default:
            return 'Could not send report. Try again.';
    }
}

export function reportContextLabel(snapshot, fallback = '') {
    if (!snapshot) return fallback;
    if (snapshot.kind === 'course_event') {
        return `${snapshot.courseCode} · ${snapshot.title} · ${snapshot.date}`;
    }
    if (snapshot.kind === 'course_policy') {
        return `${snapshot.courseCode} · course policy`;
    }
    if (snapshot.kind === 'occupied_room') {
        return `${snapshot.room} · ${snapshot.date}`;
    }
    if (snapshot.kind === 'other') {
        return snapshot.label || snapshot.pageContext || fallback;
    }
    return fallback;
}
