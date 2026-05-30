import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const err = new Error((data && data.error) || `HTTP ${res.status}`);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** Fetch the logged-in user's personal events for a date range. */
export async function fetchPersonalEvents({ from, to }) {
    const params = new URLSearchParams({ from, to });
    const res = await apiFetch(`/api/me/events?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return Array.isArray(data.events) ? data.events : [];
}

export async function createPersonalEvent(partial) {
    const res = await apiFetch('/api/me/events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partial),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.event;
}

export async function patchPersonalEvent(id, partial) {
    const res = await apiFetch(`/api/me/events/${encodeURIComponent(id)}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(partial),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.event;
}

export async function removePersonalEvent(id) {
    const res = await apiFetch(`/api/me/events/${encodeURIComponent(id)}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.id;
}
