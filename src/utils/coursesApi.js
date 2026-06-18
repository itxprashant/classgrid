import { apiFetch } from '../auth/AuthContext';

export async function fetchCourseStudents(courseCode, semesterCode) {
    const code = encodeURIComponent((courseCode || '').trim().toUpperCase());
    const sem = (semesterCode || '').trim();
    const qs = sem ? `?semester=${encodeURIComponent(sem)}` : '';
    const res = await apiFetch(`/api/courses/${code}/students${qs}`);
    if (!res.ok) throw new Error('roster_load_failed');
    const data = await res.json();
    return {
        courseCode: data.courseCode || code,
        count: data.count ?? (Array.isArray(data.students) ? data.students.length : 0),
        students: Array.isArray(data.students) ? data.students : [],
    };
}
