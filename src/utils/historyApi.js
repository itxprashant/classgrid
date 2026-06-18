import { apiFetch } from '../auth/AuthContext';

export function offeringToCourse(offering) {
    if (!offering) return null;
    return {
        courseCode: offering.courseCode,
        courseName: offering.courseName || offering.courseCode,
        semesterCode: offering.semesterCode,
        totalCredits: offering.credits ?? 0,
        creditStructure: offering.creditStructure || '0.0-0.0-0.0',
        instructor: offering.instructor || '',
        instructorEmail: offering.instructorEmail || null,
        currentStrength: offering.currentStrength || null,
        slot: {
            name: offering.slotName || null,
            lectureTimingStr: offering.lectureTimingStr || null,
            lectureTiming: offering.lectureTiming || null,
            tutorialTiming: offering.tutorialTiming || null,
            labTiming: offering.labTiming || null,
        },
        lectureHall: offering.lectureHall || null,
        offeredThisSemester: Boolean(offering.isActive),
    };
}

/** Latest semester first (YYTT numeric code decreases with time). */
export function compareSemesterCodeDesc(a, b) {
    const sa = ((a && typeof a === 'object' ? a.semesterCode : a) || '').trim();
    const sb = ((b && typeof b === 'object' ? b.semesterCode : b) || '').trim();
    if (/^\d{4}$/.test(sa) && /^\d{4}$/.test(sb)) {
        return Number(sb) - Number(sa);
    }
    return sb.localeCompare(sa);
}

/** Latest semester first; ties broken by course code. */
export function sortOfferingsBySemesterDesc(offerings) {
    return [...offerings].sort((a, b) => {
        const bySemester = compareSemesterCodeDesc(a, b);
        if (bySemester !== 0) return bySemester;
        return (a.courseCode || '').localeCompare(b.courseCode || '');
    });
}

export async function fetchSemesters() {
    const res = await apiFetch('/api/semesters');
    if (!res.ok) throw new Error('semesters_load_failed');
    const data = await res.json();
    return Array.isArray(data.semesters) ? data.semesters : [];
}

export async function fetchCourseOfferings(courseCode) {
    const code = encodeURIComponent((courseCode || '').trim().toUpperCase());
    const res = await apiFetch(`/api/courses/${code}/offerings`);
    if (!res.ok) throw new Error('offerings_load_failed');
    const data = await res.json();
    const offerings = Array.isArray(data.offerings) ? data.offerings : [];
    return {
        courseCode: data.courseCode || code,
        offerings: sortOfferingsBySemesterDesc(offerings),
    };
}

export async function searchInstructors(query) {
    const q = (query || '').trim();
    if (q.length < 2) return [];
    const res = await apiFetch(`/api/instructors/search?q=${encodeURIComponent(q)}`);
    if (!res.ok) throw new Error('instructor_search_failed');
    const data = await res.json();
    return Array.isArray(data.results) ? data.results : [];
}

export async function fetchInstructorOfferings(email) {
    const enc = encodeURIComponent((email || '').trim().toLowerCase());
    const res = await apiFetch(`/api/instructors/${enc}/offerings`);
    if (!res.ok) throw new Error('instructor_offerings_failed');
    const data = await res.json();
    if (Array.isArray(data.offerings)) {
        data.offerings = sortOfferingsBySemesterDesc(data.offerings);
    }
    return data;
}

export async function searchStudents(query) {
    const q = (query || '').trim();
    if (q.length < 2) return [];
    const res = await apiFetch(`/api/students/search?q=${encodeURIComponent(q)}`);
    if (!res.ok) throw new Error('student_search_failed');
    const data = await res.json();
    return Array.isArray(data.results) ? data.results : [];
}

export async function fetchStudentOfferings(kerberos) {
    const enc = encodeURIComponent((kerberos || '').trim().toLowerCase());
    const res = await apiFetch(`/api/students/${enc}/offerings`);
    if (!res.ok) throw new Error('student_offerings_failed');
    const data = await res.json();
    if (Array.isArray(data.offerings)) {
        data.offerings = sortOfferingsBySemesterDesc(data.offerings);
    }
    return data;
}

export function offeringTimingSummary(offering) {
    if (offering.lectureTimingStr && offering.lectureTimingStr.trim()) {
        return offering.lectureTimingStr.trim();
    }
    return '—';
}
