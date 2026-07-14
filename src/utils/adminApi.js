import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const msg = (data && data.error) || `HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

export async function fetchAdminMe() {
    const res = await apiFetch('/api/admin/me');
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function fetchAdminSummary() {
    const res = await apiFetch('/api/admin/summary');
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function fetchAdminFeedback({ limit = 50, offset = 0, category = '' } = {}) {
    const params = new URLSearchParams({ limit: String(limit), offset: String(offset) });
    if (category) params.set('category', category);
    const res = await apiFetch(`/api/admin/feedback?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function fetchAdminReports({ limit = 50, offset = 0, status = 'open' } = {}) {
    const params = new URLSearchParams({
        limit: String(limit),
        offset: String(offset),
        status,
    });
    const res = await apiFetch(`/api/admin/reports?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function fetchAdminAuditLog({
    limit = 50,
    offset = 0,
    action = '',
    targetKind = '',
    since = '',
    actorKerberos = '',
} = {}) {
    const params = new URLSearchParams({
        limit: String(limit),
        offset: String(offset),
    });
    if (action) params.set('action', action);
    if (targetKind) params.set('targetKind', targetKind);
    if (since) params.set('since', since);
    if (actorKerberos) params.set('actorKerberos', actorKerberos);
    const res = await apiFetch(`/api/admin/audit-log?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function patchAdminReport(id, status) {
    const res = await apiFetch(`/api/admin/reports/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function deleteAdminCourseEvent(id) {
    const res = await apiFetch(`/api/admin/content/course-events/${encodeURIComponent(id)}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function deleteAdminOccupiedRoom(id) {
    const res = await apiFetch(`/api/admin/content/occupied-rooms/${encodeURIComponent(id)}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function deleteAdminCoursePolicy(semesterCode, courseCode) {
    const sem = encodeURIComponent(semesterCode);
    const code = encodeURIComponent(courseCode);
    const res = await apiFetch(`/api/admin/content/course-policies/${sem}/${code}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export async function sendAdminPush({ title, body, audience }) {
    const res = await apiFetch('/api/admin/push', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, body, audience }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}

export function adminErrorMessage(code) {
    switch (code) {
        case 'not_authenticated':
            return 'Sign in with IITD OAuth to continue.';
        case 'not_admin':
            return 'Your account does not have admin access.';
        case 'database_unavailable':
            return 'Database temporarily unavailable.';
        case 'not_found':
            return 'That item could not be found.';
        case 'invalid_since':
            return 'Invalid date filter.';
        case 'invalid_actor':
            return 'Enter a valid kerberos id for the actor filter.';
        case 'fcm_unconfigured':
            return 'FCM is not configured on the server (missing service account).';
        case 'invalid_title':
            return 'Enter a title (max 120 characters).';
        case 'invalid_body':
            return 'Enter a message body (max 500 characters).';
        case 'invalid_audience':
            return 'Choose a valid audience.';
        default:
            return 'Something went wrong. Try again.';
    }
}
