#!/usr/bin/env node
'use strict';

/**
 * Rebuild course_data.instructors from existing instructor / instructorEmail fields.
 * Run after upgrading parse logic, without re-importing CSVs.
 *
 * Usage: DATABASE_URL=... node scripts/db/backfill_instructors.js
 */

const { withClient } = require('./pg');
const {
    parseInstructorsFromRow,
    resolveInstructorEmails,
    syncPrimaryInstructorFields,
} = require('./parse_instructors');

async function main() {
    await withClient(async (client) => {
        const { rows } = await client.query(
            'SELECT semester_code, course_code, course_data FROM catalog_courses',
        );

        const courses = rows.map((row) => {
            const d = row.course_data && typeof row.course_data === 'object' ? row.course_data : {};
            return {
                semesterCode: row.semester_code,
                courseCode: row.course_code,
                courseData: d,
                instructor: d.instructor || '',
                instructorEmail: d.instructorEmail || null,
                instructors: parseInstructorsFromRow(d.instructor, d.instructorEmail),
            };
        });

        resolveInstructorEmails(courses);

        await client.query('BEGIN');
        for (const course of courses) {
            syncPrimaryInstructorFields(course);
            const merged = {
                ...course.courseData,
                instructor: course.instructor,
                instructorEmail: course.instructorEmail,
                instructors: course.instructors,
            };
            await client.query(
                `UPDATE catalog_courses SET course_data = $3::jsonb
                 WHERE semester_code = $1 AND course_code = $2`,
                [course.semesterCode, course.courseCode, JSON.stringify(merged)],
            );
        }
        await client.query('COMMIT');
        console.log(`Backfilled instructors on ${courses.length} catalog rows.`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
