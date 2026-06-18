import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const msg = (data && data.error) || `HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** POST /api/reports — requires session. */
export async function submitReport(payload) {
    const res = await apiFetch('/api/reports', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            targetKind: payload.targetKind,
            targetId: payload.targetId,
            reason: payload.reason,
            details: payload.details,
            pageContext: payload.pageContext,
            label: payload.label,
        }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}
