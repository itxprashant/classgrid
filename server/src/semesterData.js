'use strict';

const crypto = require('crypto');
const { query } = require('./db');
const { instructorsFromCourseData, INSTRUCTORS_JSON_SQL } = require('./instructorUtils');

const DAY_NAME_TO_CODE = {
    Monday: 1,
    Tuesday: 2,
    Wednesday: 3,
    Thursday: 4,
    Friday: 5,
};

let activeSemesterCode = null;
let catalogCache = { courses: [], semesterCode: null, etag: '"empty"', count: 0 };
let scheduleCache = null;
let extraOccupiedCache = [];
let enrollmentsCount = 0;
let cacheReady = false;
let cacheError = null;

function normalizeSemesterCode(code) {
    return (code || '').trim();
}

function normalizeCourseCode(code) {
    return (code || '').trim().toUpperCase();
}

function normalizeKerberos(kerberos) {
    return (kerberos || '').toLowerCase().trim();
}

function formatEtag(raw) {
    if (!raw) return '"empty"';
    const s = String(raw);
    return s.startsWith('"') ? s : `"${s}"`;
}

function notModified(req, etag) {
    const inm = req.headers['if-none-match'];
    if (!inm || !etag) return false;
    return inm.split(',').map((s) => s.trim()).some((tag) => tag === etag || tag === `W/${etag}`);
}

async function resolveSemesterCode(semesterCode) {
    const explicit = normalizeSemesterCode(semesterCode);
    if (explicit) return explicit;
    if (activeSemesterCode) return activeSemesterCode;
    const { rows } = await query(
        'SELECT code FROM semesters WHERE is_active = true LIMIT 1',
    );
    return rows[0]?.code || null;
}

async function refreshActiveCache() {
    try {
        const { rows: semRows } = await query(
            `SELECT code, label, classes_start, last_teaching_day, academic_calendar,
                    catalog_etag, catalog_updated_at
             FROM semesters WHERE is_active = true LIMIT 1`,
        );
        if (!semRows.length) {
            activeSemesterCode = null;
            catalogCache = { courses: [], semesterCode: null, etag: '"empty"', count: 0 };
            scheduleCache = null;
            extraOccupiedCache = [];
            enrollmentsCount = 0;
            cacheReady = true;
            cacheError = null;
            console.warn('[semester-data] no active semester in database');
            return;
        }

        const sem = semRows[0];
        activeSemesterCode = sem.code;

        const { rows: courseRows } = await query(
            `SELECT course_data FROM catalog_courses
             WHERE semester_code = $1
             ORDER BY course_code`,
            [sem.code],
        );
        const courses = courseRows.map((r) => r.course_data);
        const etagRaw = sem.catalog_etag
            || crypto.createHash('sha1').update(`${sem.code}:${courses.length}:${sem.catalog_updated_at || ''}`).digest('hex');
        catalogCache = {
            courses,
            semesterCode: sem.code,
            etag: formatEtag(etagRaw),
            count: courses.length,
        };

        const cal = sem.academic_calendar && typeof sem.academic_calendar === 'object'
            ? sem.academic_calendar
            : {};
        scheduleCache = {
            semester: {
                code: sem.code,
                label: sem.label,
                classesStart: sem.classes_start.toISOString().slice(0, 10),
                lastTeachingDay: sem.last_teaching_day.toISOString().slice(0, 10),
            },
            holidays: cal.holidays || {},
            scheduleExceptions: cal.scheduleExceptions || {},
            noClassPeriods: cal.noClassPeriods || [],
        };

        const { rows: extraRows } = await query(
            `SELECT lecture_hall, day_of_week, start_time, end_time, reason
             FROM extra_occupied_slots
             WHERE semester_code = $1
             ORDER BY lecture_hall, day_of_week, start_time`,
            [sem.code],
        );
        extraOccupiedCache = extraRows.map((r) => ({
            lectureHall: r.lecture_hall,
            day: r.day_of_week,
            startTime: r.start_time,
            endTime: r.end_time,
            reason: r.reason || '',
        }));

        const { rows: countRows } = await query(
            'SELECT COUNT(DISTINCT kerberos)::int AS n FROM student_enrollments WHERE semester_code = $1',
            [sem.code],
        );
        enrollmentsCount = countRows[0]?.n || 0;

        cacheReady = true;
        cacheError = null;
        console.log(
            `[semester-data] active semester ${sem.code}: `
            + `${courses.length} courses, ${enrollmentsCount} enrolled students`,
        );
    } catch (e) {
        cacheReady = false;
        cacheError = e.message;
        console.error('[semester-data] cache refresh failed:', e.message);
        throw e;
    }
}

function ensureCacheReady() {
    if (!cacheReady) {
        const err = new Error(cacheError || 'semester_data_not_loaded');
        err.code = 'semester_data_not_loaded';
        throw err;
    }
}

async function loadCatalog(semesterCode) {
    const code = await resolveSemesterCode(semesterCode);
    if (!code) {
        return { courses: [], semesterCode: null, etag: '"empty"', count: 0 };
    }
    if (!semesterCode && code === activeSemesterCode && cacheReady) {
        return catalogCache;
    }
    const { rows } = await query(
        `SELECT s.code, s.catalog_etag, s.catalog_updated_at, c.course_data
         FROM semesters s
         LEFT JOIN catalog_courses c ON c.semester_code = s.code
         WHERE s.code = $1
         ORDER BY c.course_code`,
        [code],
    );
    if (!rows.length) {
        return { courses: [], semesterCode: code, etag: '"empty"', count: 0 };
    }
    const courses = rows.filter((r) => r.course_data).map((r) => r.course_data);
    const etagRaw = rows[0].catalog_etag
        || crypto.createHash('sha1').update(`${code}:${courses.length}:${rows[0].catalog_updated_at || ''}`).digest('hex');
    return {
        courses,
        semesterCode: code,
        etag: formatEtag(etagRaw),
        count: courses.length,
    };
}

async function loadCatalogExplorer() {
    const activeCode = await resolveSemesterCode();
    if (!activeCode) {
        return { courses: [], semesterCode: null, etag: '"empty"', count: 0, offeredCount: 0 };
    }

    const activeCatalog = await loadCatalog(activeCode);
    const activeCodes = new Set(
        activeCatalog.courses.map((c) => normalizeCourseCode(c.courseCode)),
    );

    const offeredCourses = activeCatalog.courses.map((c) => ({
        ...c,
        courseCode: normalizeCourseCode(c.courseCode),
        offeredThisSemester: true,
    }));

    const { rows } = await query(
        `SELECT DISTINCT ON (c.course_code)
            c.course_code, c.course_data, s.code AS semester_code
         FROM catalog_courses c
         JOIN semesters s ON s.code = c.semester_code
         ORDER BY c.course_code, s.code DESC`,
    );

    const inactiveCourses = [];
    for (const row of rows) {
        const code = normalizeCourseCode(row.course_code);
        if (activeCodes.has(code)) continue;
        const d = row.course_data && typeof row.course_data === 'object' ? row.course_data : {};
        inactiveCourses.push({
            ...d,
            courseCode: code,
            semesterCode: row.semester_code,
            offeredThisSemester: false,
        });
    }

    inactiveCourses.sort((a, b) => a.courseCode.localeCompare(b.courseCode));
    const courses = [...offeredCourses, ...inactiveCourses];
    const etagRaw = crypto.createHash('sha1').update(
        `${activeCatalog.etag}:${courses.length}:${inactiveCourses.length}`,
    ).digest('hex');

    return {
        courses,
        semesterCode: activeCode,
        etag: formatEtag(etagRaw),
        count: courses.length,
        offeredCount: offeredCourses.length,
    };
}

async function getAcademicCalendar(semesterCode) {
    const code = await resolveSemesterCode(semesterCode);
    if (!code) return null;
    if (!semesterCode && code === activeSemesterCode && cacheReady && scheduleCache) {
        return scheduleCache;
    }
    const { rows } = await query(
        `SELECT code, label, classes_start, last_teaching_day, academic_calendar
         FROM semesters WHERE code = $1`,
        [code],
    );
    if (!rows.length) return null;
    const sem = rows[0];
    const cal = sem.academic_calendar && typeof sem.academic_calendar === 'object'
        ? sem.academic_calendar
        : {};
    return {
        semester: {
            code: sem.code,
            label: sem.label,
            classesStart: sem.classes_start.toISOString().slice(0, 10),
            lastTeachingDay: sem.last_teaching_day.toISOString().slice(0, 10),
        },
        holidays: cal.holidays || {},
        scheduleExceptions: cal.scheduleExceptions || {},
        noClassPeriods: cal.noClassPeriods || [],
    };
}

async function getExtraOccupied(semesterCode) {
    const code = await resolveSemesterCode(semesterCode);
    if (!code) return [];
    if (!semesterCode && code === activeSemesterCode && cacheReady) {
        return extraOccupiedCache;
    }
    const { rows } = await query(
        `SELECT lecture_hall, day_of_week, start_time, end_time, reason
         FROM extra_occupied_slots
         WHERE semester_code = $1
         ORDER BY lecture_hall, day_of_week, start_time`,
        [code],
    );
    return rows.map((r) => ({
        lectureHall: r.lecture_hall,
        day: r.day_of_week,
        startTime: r.start_time,
        endTime: r.end_time,
        reason: r.reason || '',
    }));
}

async function getEnrolledCourses(kerberos, semesterCode) {
    const kid = normalizeKerberos(kerberos);
    if (!kid) return [];
    const code = await resolveSemesterCode(semesterCode);
    if (!code) return [];
    const { rows } = await query(
        `SELECT course_code FROM student_enrollments
         WHERE semester_code = $1 AND kerberos = $2
         ORDER BY course_code`,
        [code, kid],
    );
    return rows.map((r) => r.course_code);
}

async function getCourseRoster(courseCode, semesterCode) {
    const cc = normalizeCourseCode(courseCode);
    if (!cc) return [];
    const code = await resolveSemesterCode(semesterCode);
    if (!code) return [];
    const { rows } = await query(
        `SELECT student_kerberos, student_name FROM course_rosters
         WHERE semester_code = $1 AND course_code = $2
         ORDER BY student_kerberos`,
        [code, cc],
    );
    return rows
        .map((r) => ({
            id: r.student_kerberos,
            name: r.student_name || '',
        }))
        .filter((r) => r.id);
}

async function getSemesterMeta(semesterCode) {
    const code = await resolveSemesterCode(semesterCode);
    if (!code) {
        return { code: null, label: null, isActive: false, catalogEtag: null, catalogCount: 0 };
    }
    const catalog = await loadCatalog(code);
    const { rows } = await query(
        'SELECT label, is_active FROM semesters WHERE code = $1',
        [code],
    );
    const sem = rows[0];
    return {
        code,
        label: sem?.label || null,
        isActive: Boolean(sem?.is_active),
        catalogEtag: catalog.etag,
        catalogCount: catalog.count,
    };
}

async function getAppReleaseConfig(platform = 'android') {
    const { rows } = await query(
        'SELECT version, build, download_url FROM app_release_config WHERE platform = $1',
        [platform],
    );
    if (!rows.length) {
        return {
            version: '1.0.0',
            build: 1,
            downloadUrl: 'https://classgrid.devclub.in/app/classgrid.apk',
        };
    }
    const r = rows[0];
    return {
        version: r.version,
        build: r.build,
        downloadUrl: r.download_url,
    };
}

async function getHealthStats() {
    if (!cacheReady) {
        return {
            activeSemester: activeSemesterCode,
            catalogCount: 0,
            enrolledStudents: 0,
        };
    }
    return {
        activeSemester: activeSemesterCode,
        catalogCount: catalogCache.count,
        enrolledStudents: enrollmentsCount,
    };
}

function mapOfferingRow(row) {
    const d = row.course_data && typeof row.course_data === 'object' ? row.course_data : {};
    const slot = d.slot && typeof d.slot === 'object' ? d.slot : {};
    const instructors = instructorsFromCourseData(d);
    const primary = instructors.find((i) => i.email) || instructors[0];
    return {
        semesterCode: row.semester_code,
        label: row.label || row.semester_code,
        isActive: Boolean(row.is_active),
        courseCode: row.course_code,
        courseName: d.courseName || '',
        instructor: primary?.name || d.instructor || '',
        instructorEmail: primary?.email || d.instructorEmail || null,
        instructors,
        slotName: slot.name || null,
        lectureTimingStr: slot.lectureTimingStr || null,
        lectureTiming: slot.lectureTiming || null,
        tutorialTiming: slot.tutorialTiming || null,
        labTiming: slot.labTiming || null,
        credits: d.totalCredits ?? null,
        creditStructure: d.creditStructure || null,
        lectureHall: d.lectureHall || null,
        currentStrength: d.currentStrength || null,
    };
}

async function listSemesters() {
    const { rows } = await query(
        `SELECT s.code, s.label, s.is_active,
                COUNT(c.course_code)::int AS catalog_count
         FROM semesters s
         LEFT JOIN catalog_courses c ON c.semester_code = s.code
         GROUP BY s.code, s.label, s.is_active
         ORDER BY s.code DESC`,
    );
    return rows.map((r) => ({
        code: r.code,
        label: r.label,
        isActive: Boolean(r.is_active),
        catalogCount: r.catalog_count,
    }));
}

async function getCourseOfferings(courseCode) {
    const cc = normalizeCourseCode(courseCode);
    const { rows } = await query(
        `SELECT s.code AS semester_code, s.label, s.is_active, c.course_code, c.course_data
         FROM catalog_courses c
         JOIN semesters s ON s.code = c.semester_code
         WHERE c.course_code = $1
         ORDER BY s.code DESC, c.course_code`,
        [cc],
    );
    return rows.map(mapOfferingRow);
}

async function searchInstructors(searchQuery, limit = 30) {
    const q = (searchQuery || '').trim();
    if (q.length < 2) return [];
    const pattern = `%${q.replace(/[%_\\]/g, '\\$&')}%`;
    const { rows } = await query(
        `WITH inst AS (
            SELECT
                lower(i->>'email') AS email,
                trim(i->>'name') AS name,
                c.semester_code,
                c.course_code
            FROM catalog_courses c,
            LATERAL jsonb_array_elements(${INSTRUCTORS_JSON_SQL}) AS i
            WHERE i->>'email' IS NOT NULL
              AND i->>'email' <> ''
              AND (
                  trim(i->>'name') ILIKE $1 ESCAPE '\\'
                  OR lower(i->>'email') ILIKE $1 ESCAPE '\\'
              )
         )
         SELECT
            email,
            (array_agg(name ORDER BY
                CASE WHEN name ILIKE $1 ESCAPE '\\' THEN 0 ELSE 1 END,
                length(name) ASC
            ))[1] AS name,
            COUNT(DISTINCT (semester_code, course_code))::int AS offering_count
         FROM inst
         GROUP BY email
         ORDER BY name
         LIMIT $2`,
        [pattern, limit],
    );
    return rows
        .filter((r) => r.email)
        .map((r) => ({
            name: r.name || r.email,
            email: r.email,
            offeringCount: r.offering_count,
        }));
}

async function getInstructorOfferings(email) {
    const normalized = (email || '').trim().toLowerCase();
    if (!normalized.includes('@')) return null;
    const { rows } = await query(
        `SELECT s.code AS semester_code, s.label, s.is_active, c.course_code, c.course_data
         FROM catalog_courses c
         JOIN semesters s ON s.code = c.semester_code
         WHERE EXISTS (
            SELECT 1
            FROM jsonb_array_elements(${INSTRUCTORS_JSON_SQL}) AS i
            WHERE lower(i->>'email') = $1
         )
         ORDER BY s.code DESC, c.course_code`,
        [normalized],
    );
    if (!rows.length) return null;
    const offerings = rows.map(mapOfferingRow);
    const matchName = offerings
        .flatMap((o) => o.instructors.filter((i) => i.email === normalized))
        .map((i) => i.name)
        .find(Boolean);
    return {
        instructor: { name: matchName || normalized, email: normalized },
        offerings,
    };
}

function kerberosMeta(kerberos) {
    const m = (kerberos || '').match(/^([a-z0-9]{3})([0-9]{2})/i);
    return {
        branch: m ? m[1].toUpperCase() : null,
        entryYear: m ? `20${m[2]}` : null,
    };
}

async function searchStudents(searchQuery, limit = 30) {
    const q = (searchQuery || '').trim();
    if (q.length < 2) return [];
    const pattern = `%${q.replace(/[%_\\]/g, '\\$&')}%`;
    const { rows } = await query(
        `WITH matches AS (
            SELECT
                lower(r.student_kerberos) AS kerberos,
                trim(r.student_name) AS name
            FROM course_rosters r
            WHERE (
                lower(r.student_kerberos) ILIKE $1 ESCAPE '\\'
                OR trim(r.student_name) ILIKE $1 ESCAPE '\\'
            )
         ),
         grouped AS (
            SELECT
                kerberos,
                (array_agg(name ORDER BY
                    CASE WHEN name ILIKE $1 ESCAPE '\\' THEN 0 ELSE 1 END,
                    length(name) ASC
                ))[1] AS name
            FROM matches
            GROUP BY kerberos
         )
         SELECT
            g.kerberos,
            g.name,
            COALESCE(e.enrollment_count, 0)::int AS enrollment_count
         FROM grouped g
         LEFT JOIN (
            SELECT lower(kerberos) AS kerberos, COUNT(DISTINCT semester_code)::int AS enrollment_count
            FROM student_enrollments
            GROUP BY lower(kerberos)
         ) e ON e.kerberos = g.kerberos
         ORDER BY g.name
         LIMIT $2`,
        [pattern, limit],
    );
    return rows
        .filter((r) => r.kerberos)
        .map((r) => ({
            kerberos: r.kerberos,
            name: r.name || r.kerberos,
            enrollmentCount: r.enrollment_count,
        }));
}

async function getStudentOfferings(kerberos) {
    const normalized = normalizeKerberos(kerberos);
    if (!normalized) return null;

    const { rows: offeringRows } = await query(
        `SELECT s.code AS semester_code, s.label, s.is_active, c.course_code, c.course_data
         FROM student_enrollments e
         JOIN catalog_courses c
            ON c.semester_code = e.semester_code AND c.course_code = e.course_code
         JOIN semesters s ON s.code = e.semester_code
         WHERE lower(e.kerberos) = $1
         ORDER BY s.code DESC, c.course_code`,
        [normalized],
    );

    const { rows: knownRows } = await query(
        `SELECT 1 AS ok
         FROM course_rosters
         WHERE lower(student_kerberos) = $1
         LIMIT 1`,
        [normalized],
    );
    if (!offeringRows.length && !knownRows.length) return null;

    const { rows: nameRows } = await query(
        `SELECT (array_agg(student_name ORDER BY semester_code DESC, length(student_name) DESC))[1] AS name
         FROM course_rosters
         WHERE lower(student_kerberos) = $1 AND trim(student_name) <> ''`,
        [normalized],
    );

    const { rows: hostelRows } = await query(
        `SELECT hostel FROM students WHERE kerberos = $1`,
        [normalized],
    );

    const offerings = offeringRows.map(mapOfferingRow);
    const meta = kerberosMeta(normalized);

    return {
        student: {
            kerberos: normalized,
            name: nameRows[0]?.name || normalized,
            hostel: hostelRows[0]?.hostel ?? null,
            branch: meta.branch,
            entryYear: meta.entryYear,
        },
        offerings,
    };
}

async function upsertStudentHostel(kerberos, hostel) {
    const normalized = normalizeKerberos(kerberos);
    const value = (hostel || '').toString().trim();
    if (!normalized || !value) return;
    await query(
        `INSERT INTO students (kerberos, hostel, updated_at)
         VALUES ($1, $2, now())
         ON CONFLICT (kerberos) DO UPDATE SET
            hostel = EXCLUDED.hostel,
            updated_at = now()`,
        [normalized, value],
    );
}

async function getStudentHostel(kerberos) {
    const normalized = normalizeKerberos(kerberos);
    if (!normalized) return null;
    const { rows } = await query(
        `SELECT hostel FROM students WHERE kerberos = $1`,
        [normalized],
    );
    const value = (rows[0]?.hostel || '').toString().trim();
    return value || null;
}

function getActiveSemesterCode() {
    return activeSemesterCode;
}

function isCacheReady() {
    return cacheReady;
}

// Warm cache at module load when DATABASE_URL is set.
const config = require('./config');
if (config.databaseUrl) {
    refreshActiveCache().catch(() => {});
}

module.exports = {
    DAY_NAME_TO_CODE,
    refreshActiveCache,
    ensureCacheReady,
    loadCatalog,
    loadCatalogExplorer,
    getAcademicCalendar,
    getExtraOccupied,
    getEnrolledCourses,
    getCourseRoster,
    getSemesterMeta,
    getAppReleaseConfig,
    getHealthStats,
    listSemesters,
    getCourseOfferings,
    searchInstructors,
    getInstructorOfferings,
    searchStudents,
    getStudentOfferings,
    upsertStudentHostel,
    getStudentHostel,
    getActiveSemesterCode,
    resolveSemesterCode,
    isCacheReady,
    notModified,
    normalizeCourseCode,
    normalizeKerberos,
};
