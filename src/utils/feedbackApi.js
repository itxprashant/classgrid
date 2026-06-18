import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const msg = (data && data.error) || `HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** POST /api/feedback — login optional. */
export async function submitFeedback(payload) {
    const res = await apiFetch('/api/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            message: payload.message,
            category: payload.category,
            pageContext: payload.pageContext,
            client: payload.client || 'web',
        }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}
