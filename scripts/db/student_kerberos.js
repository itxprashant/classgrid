'use strict';

/** IITD student ids: aa1234567 (2 letters + 7 digits) or abc123456 (3 letters + 6 digits). */
const STUDENT_KERBEROS_RE = /^(?:[a-z]{2}[0-9]{7}|[a-z]{3}[0-9]{6})$/;

function normalizeKerberos(kerberos) {
    return (kerberos || '').toLowerCase().trim();
}

function isStudentKerberos(kerberos) {
    return STUDENT_KERBEROS_RE.test(normalizeKerberos(kerberos));
}

/**
 * Drop staff/professor kerberos from LDAP enrollment exports.
 * @returns {{ studentCourses: object, courseStudents: object, skippedKerberos: number }}
 */
function filterStudentEnrollmentData({ studentCourses, courseStudents }) {
    const filteredStudentCourses = {};
    let skippedKerberos = 0;

    for (const [kerberos, courseList] of Object.entries(studentCourses || {})) {
        const kid = normalizeKerberos(kerberos);
        if (!isStudentKerberos(kid)) {
            skippedKerberos += 1;
            continue;
        }
        filteredStudentCourses[kid] = courseList;
    }

    const filteredCourseStudents = {};
    for (const [courseCode, roster] of Object.entries(courseStudents || {})) {
        filteredCourseStudents[courseCode] = (roster || []).filter(
            (row) => row && isStudentKerberos(row.id),
        );
    }

    return {
        studentCourses: filteredStudentCourses,
        courseStudents: filteredCourseStudents,
        skippedKerberos,
    };
}

module.exports = {
    STUDENT_KERBEROS_RE,
    normalizeKerberos,
    isStudentKerberos,
    filterStudentEnrollmentData,
};
