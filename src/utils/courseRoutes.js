const SEMESTER_CODE_RE = /^\d{4}$/;

export function courseOfferingPath(courseCode, semesterCode) {
    const code = encodeURIComponent((courseCode || '').trim().toUpperCase());
    const sem = (semesterCode || '').trim();
    if (SEMESTER_CODE_RE.test(sem)) {
        return `/course/${code}/${encodeURIComponent(sem)}`;
    }
    return `/course/${code}`;
}

/** Semester code for deep-linking from catalog / room schedule rows. */
export function courseLinkSemester(course, activeSemesterCode) {
    if (course?.offeredThisSemester === false && SEMESTER_CODE_RE.test(course?.semesterCode || '')) {
        return course.semesterCode;
    }
    if (SEMESTER_CODE_RE.test(activeSemesterCode || '')) {
        return activeSemesterCode;
    }
    if (SEMESTER_CODE_RE.test(course?.semesterCode || '')) {
        return course.semesterCode;
    }
    return null;
}

export function coursePagePath(course, activeSemesterCode) {
    const sem = courseLinkSemester(course, activeSemesterCode);
    return courseOfferingPath(course?.courseCode, sem);
}

export function coursePolicyReportPath(courseCode, semesterCode) {
    const sem = (semesterCode || '').trim();
    if (SEMESTER_CODE_RE.test(sem)) {
        return courseOfferingPath(courseCode, sem);
    }
    return `/course/${encodeURIComponent((courseCode || '').trim().toUpperCase())}`;
}
