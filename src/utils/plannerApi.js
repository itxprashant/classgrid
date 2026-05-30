import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const err = new Error((data && data.error) || `HTTP ${res.status}`);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** Load the signed-in user's saved planner (empty if none). */
export async function fetchPlan() {
    const res = await apiFetch('/api/me/plan');
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return {
        selectedCourses: Array.isArray(data.selectedCourses) ? data.selectedCourses : [],
        timetableData: data.timetableData && typeof data.timetableData === 'object'
            ? data.timetableData
            : {},
        updatedAt: data.updatedAt || null,
    };
}

/** Persist planner state for the signed-in user. */
export async function savePlan({ selectedCourses, timetableData }) {
    const res = await apiFetch('/api/me/plan', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ selectedCourses, timetableData }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data;
}
