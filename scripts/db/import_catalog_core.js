'use strict';

/**
 * Shared catalog import logic for import_catalog.js and import_historical_catalog.js.
 */

const { computeCatalogEtag } = require('./pg');

async function upsertSemesterStub(client, semesterCode, { label, classesStart, lastTeachingDay }) {
    await client.query(
        `INSERT INTO semesters (code, label, classes_start, last_teaching_day, is_active, academic_calendar)
         VALUES ($1, $2, $3::date, $4::date, false, '{}'::jsonb)
         ON CONFLICT (code) DO UPDATE SET
            label = COALESCE(NULLIF(semesters.label, ''), EXCLUDED.label),
            classes_start = EXCLUDED.classes_start,
            last_teaching_day = EXCLUDED.last_teaching_day,
            updated_at = now()
         WHERE semesters.is_active = false`,
        [semesterCode, label, classesStart, lastTeachingDay],
    );
}

async function importCatalogForSemester(client, semesterCode, courses) {
    const now = new Date().toISOString();
    const existing = await client.query(
        'SELECT course_code, course_data FROM catalog_courses WHERE semester_code = $1',
        [semesterCode],
    );
    const hallByCode = new Map(
        existing.rows.map((r) => [r.course_code, r.course_data?.lectureHall || null]),
    );

    await client.query('DELETE FROM catalog_courses WHERE semester_code = $1', [semesterCode]);

    // IITD CSVs sometimes list the same code twice (e.g. different lab sections); last row wins.
    const byCode = new Map();
    for (const course of courses) {
        byCode.set(course.courseCode.toUpperCase(), course);
    }
    const uniqueCourses = [...byCode.values()];

    for (const course of uniqueCourses) {
        const cc = course.courseCode.toUpperCase();
        const preservedHall = hallByCode.get(cc);
        if (preservedHall && !course.lectureHall) {
            course.lectureHall = preservedHall;
        }
        await client.query(
            `INSERT INTO catalog_courses (semester_code, course_code, course_data)
             VALUES ($1, $2, $3::jsonb)`,
            [semesterCode, cc, JSON.stringify(course)],
        );
    }

    await client.query(
        `UPDATE semesters SET catalog_etag = $2, catalog_updated_at = now(), updated_at = now()
         WHERE code = $1`,
        [semesterCode, computeCatalogEtag(semesterCode, uniqueCourses.length, now)],
    );

    return uniqueCourses.length;
}

module.exports = {
    upsertSemesterStub,
    importCatalogForSemester,
};
