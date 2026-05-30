import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    let msg = (data && data.error) || `HTTP ${res.status}`;
    if (res.status === 414) {
        msg = 'Request URI too long';
    }
    const err = new Error(msg);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** Fetch shared course events for the visible date range. */
export async function fetchEvents({ from, to, courses }) {
    const codes = [...new Set((courses || []).filter(Boolean))];
    const params = new URLSearchParams({ from, to });
    if (codes.length > 0) {
        params.set('courses', codes.join(','));
    }
    const res = await apiFetch(`/api/events?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return Array.isArray(data.events) ? data.events : [];
}

export async function createEvent(partial) {
    const res = await apiFetch('/api/events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partial),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.event;
}

export async function patchEvent(id, partial) {
    const res = await apiFetch(`/api/events/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partial),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.event;
}

export async function removeEvent(id) {
    const res = await apiFetch(`/api/events/${encodeURIComponent(id)}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.id;
}
