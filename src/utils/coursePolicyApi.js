import { apiFetch } from '../auth/AuthContext';

function apiError(res, data) {
    const msg = (data && data.error) || `HTTP ${res.status}`;
    const err = new Error(msg);
    err.status = res.status;
    err.code = data && data.error;
    return err;
}

/** Fetch course policy for the active semester (enrolled students only). */
export async function fetchCoursePolicy(courseCode) {
    const res = await apiFetch(
        `/api/courses/${encodeURIComponent(courseCode)}/policy`,
    );
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return {
        semesterCode: data.semesterCode,
        courseCode: data.courseCode,
        policy: data.policy || null,
    };
}

/** Create or replace course policy (enrolled students only). */
export async function saveCoursePolicy(courseCode, partial) {
    const res = await apiFetch(
        `/api/courses/${encodeURIComponent(courseCode)}/policy`,
        {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(partial),
        },
    );
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw apiError(res, data);
    return data.policy;
}
