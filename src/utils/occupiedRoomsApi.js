import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const err = new Error((data && data.error) || `HTTP ${res.status}`);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** Active manual occupancy markings for a calendar date + time (HHMM integer). */
export async function fetchOccupiedRooms({ date, time }) {
    const params = new URLSearchParams({
        date: String(date),
        time: String(time),
    });
    const res = await apiFetch(`/api/rooms/occupied?${params}`);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return Array.isArray(data.markings) ? data.markings : [];
}

export async function createOccupiedRoom({ room, date, start, end, note }) {
    const payload = { room, date, start, end };
    if (note) payload.note = note;

    const res = await apiFetch('/api/rooms/occupied', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.marking;
}

export async function removeOccupiedRoom(id) {
    const res = await apiFetch(`/api/rooms/occupied/${encodeURIComponent(id)}`, {
        method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.id;
}
