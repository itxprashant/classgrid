'use strict';

function normalizeName(name) {
    return (name || '').replace(/\s+/g, ' ').trim().toUpperCase();
}

function normalizeEmail(email) {
    const e = (email || '').trim().toLowerCase();
    return e.includes('@') ? e : null;
}

function splitInstructorNames(raw) {
    if (!raw || raw === 'N/A') return [];
    return raw
        .split(',')
        .map((s) => s.replace(/\s+/g, ' ').trim())
        .filter(Boolean);
}

function parseInstructorsFromRow(instructorRaw, emailRaw) {
    const names = splitInstructorNames(instructorRaw);
    const primaryEmail = normalizeEmail(emailRaw);
    if (!names.length) {
        if (primaryEmail) {
            return [{ name: instructorRaw?.trim() || primaryEmail, email: primaryEmail }];
        }
        return [];
    }
    return names.map((name, index) => ({
        name,
        email: index === 0 ? primaryEmail : null,
    }));
}

/** Fill missing co-instructor emails using sole-instructor rows in the batch. */
function resolveInstructorEmails(courses) {
    const emailByName = new Map();
    for (const course of courses) {
        for (const inst of course.instructors || []) {
            if (inst.email && inst.name) {
                const key = normalizeName(inst.name);
                if (!emailByName.has(key)) emailByName.set(key, inst.email);
            }
        }
    }
    for (const course of courses) {
        for (const inst of course.instructors || []) {
            if (!inst.email && inst.name) {
                inst.email = emailByName.get(normalizeName(inst.name)) || null;
            }
        }
        syncPrimaryInstructorFields(course);
    }
    return courses;
}

function syncPrimaryInstructorFields(course) {
    const list = course.instructors || [];
    const primary = list.find((i) => i.email) || list[0];
    course.instructor = primary?.name || course.instructor || 'N/A';
    course.instructorEmail = primary?.email || null;
}

function attachInstructors(course) {
    course.instructors = parseInstructorsFromRow(course.instructor, course.instructorEmail);
    syncPrimaryInstructorFields(course);
    return course;
}

function instructorsFromCourseData(courseData) {
    if (!courseData || typeof courseData !== 'object') return [];
    if (Array.isArray(courseData.instructors) && courseData.instructors.length) {
        return courseData.instructors
            .map((i) => ({
                name: (i?.name || '').trim(),
                email: normalizeEmail(i?.email),
            }))
            .filter((i) => i.name || i.email);
    }
    return parseInstructorsFromRow(courseData.instructor, courseData.instructorEmail);
}

module.exports = {
    normalizeName,
    normalizeEmail,
    splitInstructorNames,
    parseInstructorsFromRow,
    resolveInstructorEmails,
    attachInstructors,
    syncPrimaryInstructorFields,
    instructorsFromCourseData,
};
