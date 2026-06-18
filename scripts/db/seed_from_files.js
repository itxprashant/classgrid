#!/usr/bin/env node
'use strict';

/**
 * One-time seed: load legacy JSON files into Postgres semester tables.
 * Usage: DATABASE_URL=... node scripts/db/seed_from_files.js [--semester=2601] [--activate]
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot, computeCatalogEtag } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester || '2601';
const activate = args.activate !== false;

async function main() {
    const calPath = path.join(repoRoot, 'data', 'academic_calendar.json');
    const cal = JSON.parse(fs.readFileSync(calPath, 'utf8'));
    const sem = cal.semester || {};

    const coursesPath = path.join(repoRoot, 'src', 'courses.json');
    const courses = JSON.parse(fs.readFileSync(coursesPath, 'utf8'));

    const studentCoursesPath = path.join(repoRoot, 'src', 'studentCourses.json');
    const studentCourses = fs.existsSync(studentCoursesPath)
        ? JSON.parse(fs.readFileSync(studentCoursesPath, 'utf8'))
        : {};

    const courseStudentsPath = path.join(repoRoot, 'src', 'courseStudents.json');
    const courseStudents = fs.existsSync(courseStudentsPath)
        ? JSON.parse(fs.readFileSync(courseStudentsPath, 'utf8'))
        : {};

    const extraPath = path.join(repoRoot, 'data', 'extra_occupied.json');
    const extraSlots = fs.existsSync(extraPath)
        ? JSON.parse(fs.readFileSync(extraPath, 'utf8'))
        : [];

    const pubspecPath = path.join(repoRoot, 'app', 'pubspec.yaml');
    let android = null;
    if (fs.existsSync(pubspecPath)) {
        const raw = fs.readFileSync(pubspecPath, 'utf8');
        const match = raw.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/m);
        if (match) {
            const version = match[1];
            const build = Number(match[2]);
            android = {
                version,
                build,
                downloadUrl: `https://classgrid.devclub.in/app/classgrid-${version}+${build}.apk`,
            };
        }
    }

    const code = sem.code || semesterCode;
    const now = new Date().toISOString();
    const etag = computeCatalogEtag(code, courses.length, now);

    await withClient(async (client) => {
        await client.query('BEGIN');

        await client.query(
            `INSERT INTO semesters (code, label, classes_start, last_teaching_day, is_active,
                                   academic_calendar, catalog_etag, catalog_updated_at)
             VALUES ($1, $2, $3::date, $4::date, false, $5::jsonb, $6, now())
             ON CONFLICT (code) DO UPDATE SET
                label = EXCLUDED.label,
                classes_start = EXCLUDED.classes_start,
                last_teaching_day = EXCLUDED.last_teaching_day,
                academic_calendar = EXCLUDED.academic_calendar,
                catalog_etag = EXCLUDED.catalog_etag,
                catalog_updated_at = now(),
                updated_at = now()`,
            [
                code,
                sem.label || `Semester ${code}`,
                sem.classesStart,
                sem.lastTeachingDay,
                JSON.stringify({
                    holidays: cal.holidays || {},
                    scheduleExceptions: cal.scheduleExceptions || {},
                    noClassPeriods: cal.noClassPeriods || [],
                }),
                etag,
            ],
        );

        await client.query('DELETE FROM catalog_courses WHERE semester_code = $1', [code]);
        for (const course of courses) {
            if (!course || !course.courseCode) continue;
            await client.query(
                `INSERT INTO catalog_courses (semester_code, course_code, course_data)
                 VALUES ($1, $2, $3::jsonb)
                 ON CONFLICT (semester_code, course_code) DO UPDATE SET course_data = EXCLUDED.course_data`,
                [code, course.courseCode.toUpperCase(), JSON.stringify(course)],
            );
        }

        await client.query('DELETE FROM student_enrollments WHERE semester_code = $1', [code]);
        for (const [kerberos, courseList] of Object.entries(studentCourses)) {
            if (!Array.isArray(courseList)) continue;
            for (const cc of courseList) {
                await client.query(
                    `INSERT INTO student_enrollments (semester_code, kerberos, course_code)
                     VALUES ($1, $2, $3)
                     ON CONFLICT DO NOTHING`,
                    [code, kerberos.toLowerCase().trim(), String(cc).toUpperCase()],
                );
            }
        }

        await client.query('DELETE FROM course_rosters WHERE semester_code = $1', [code]);
        for (const [courseCode, roster] of Object.entries(courseStudents)) {
            if (!Array.isArray(roster)) continue;
            for (const row of roster) {
                if (!row || !row.id) continue;
                await client.query(
                    `INSERT INTO course_rosters (semester_code, course_code, student_kerberos, student_name)
                     VALUES ($1, $2, $3, $4)
                     ON CONFLICT DO NOTHING`,
                    [
                        code,
                        courseCode.toUpperCase(),
                        row.id.toLowerCase().trim(),
                        (row.name || '').trim(),
                    ],
                );
            }
        }

        await client.query('DELETE FROM extra_occupied_slots WHERE semester_code = $1', [code]);
        for (const slot of extraSlots) {
            if (!slot || !slot.lectureHall) continue;
            await client.query(
                `INSERT INTO extra_occupied_slots
                 (semester_code, lecture_hall, day_of_week, start_time, end_time, reason)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                    code,
                    slot.lectureHall,
                    slot.day,
                    slot.startTime,
                    slot.endTime,
                    slot.reason || null,
                ],
            );
        }

        if (android) {
            await client.query(
                `INSERT INTO app_release_config (platform, version, build, download_url, updated_at)
                 VALUES ('android', $1, $2, $3, now())
                 ON CONFLICT (platform) DO UPDATE SET
                    version = EXCLUDED.version,
                    build = EXCLUDED.build,
                    download_url = EXCLUDED.download_url,
                    updated_at = now()`,
                [android.version, android.build, android.downloadUrl],
            );
        }

        if (activate) {
            await client.query('UPDATE semesters SET is_active = false WHERE code <> $1', [code]);
            await client.query('UPDATE semesters SET is_active = true WHERE code = $1', [code]);
        }

        await client.query('COMMIT');
        console.log(`Seeded semester ${code}: ${courses.length} courses, `
            + `${Object.keys(studentCourses).length} students, `
            + `${extraSlots.length} extra-occupied slots`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
