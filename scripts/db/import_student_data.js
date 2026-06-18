#!/usr/bin/env node
'use strict';

/**
 * Fetch student enrollments + course rosters from IITD LDAP and import to Postgres.
 *
 * LDAP is only reachable on IITD intranet / VPN (ldapweb.iitd.ac.in).
 *
 * Usage:
 *   # On VPN: fetch JSON only (no database)
 *   node scripts/db/import_student_data.js --semester=2502 --fetch-only
 *
 *   # On VPN or off: import previously fetched JSON into Postgres
 *   DATABASE_URL=... node scripts/db/import_student_data.js --semester=2502 --from-json
 *
 *   # On VPN: fetch from LDAP and write Postgres in one step
 *   DATABASE_URL=... node scripts/db/import_student_data.js --semester=2502
 *
 * Options:
 *   --semester=CODE     Required. IITD semester code (e.g. 2502, 2601).
 *   --prefix=2502-        LDAP course page prefix (default: ${semester}-).
 *   --out-dir=PATH      JSON export dir (default: data/ldap_exports/CODE).
 *   --from-json         Read studentCourses.json + courseStudents.json from --out-dir.
 *   --fetch-only        Fetch LDAP → JSON only; skip Postgres.
 *   --dry-run           With --from-json: parse and print counts, no DB writes.
 *
 * Requires a `semesters` row for --semester (FK). For archived terms, import catalog
 * or calendar first, e.g. import_historical_catalog.js --semester=2502.
 */

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
const semesterPrefix = args.prefix || (semesterCode ? `${semesterCode}-` : '');
const fetchOnly = Boolean(args['fetch-only']);
const fromJson = Boolean(args['from-json']);
const dryRun = Boolean(args['dry-run']);
const outDir = args['out-dir']
    || (semesterCode ? path.join(repoRoot, 'data', 'ldap_exports', semesterCode) : '');

if (!semesterCode) {
    console.error(
        'Usage: node scripts/db/import_student_data.js --semester=CODE [--fetch-only | --from-json]\n'
        + 'See scripts/fetch_student_enrollments.sh for the VPN workflow.',
    );
    process.exit(1);
}

const BASE_URL = 'https://ldapweb.iitd.ac.in/LDAP/courses';

async function fetchStudentDataFromLdap() {
    console.log(`Fetching course pages from ${BASE_URL} (prefix ${semesterPrefix})…`);
    console.log('Requires IITD intranet or VPN.');

    const response = await fetch(`${BASE_URL}/gpaliases.html`);
    if (!response.ok) {
        throw new Error(`Failed to fetch LDAP aliases: HTTP ${response.status}`);
    }
    const text = await response.text();

    const linkRegex = /href="([^"]+)"/g;
    const links = [];
    let match;
    while ((match = linkRegex.exec(text)) !== null) {
        const link = match[1];
        if (link.startsWith(semesterPrefix) && (link.endsWith('.shtml') || link.endsWith('.html'))) {
            links.push(link);
        }
    }
    console.log(`Found ${links.length} course pages.`);

    if (links.length === 0) {
        console.warn(
            `No links matched prefix "${semesterPrefix}". `
            + 'Check --semester / --prefix, or confirm you are on IITD VPN.',
        );
    }

    const studentCourses = {};
    const courseStudents = {};
    const BATCH_SIZE = 50;

    for (let i = 0; i < links.length; i += BATCH_SIZE) {
        const batch = links.slice(i, i + BATCH_SIZE);
        console.log(`Processing batch ${i + 1}-${Math.min(i + BATCH_SIZE, links.length)}…`);
        await Promise.all(batch.map(async (link) => {
            try {
                const courseCodeMatch = link.match(/-([A-Z0-9]+)\./);
                if (!courseCodeMatch) return;
                const courseCode = courseCodeMatch[1];

                const courseRes = await fetch(`${BASE_URL}/${link}`);
                if (!courseRes.ok) return;
                const courseText = await courseRes.text();

                const rowRegex = /<TR><TD[^>]*>([a-z0-9]+)<\/TD>\s*<TD>([^<]+)<\/TD>/gi;
                let rowMatch;
                while ((rowMatch = rowRegex.exec(courseText)) !== null) {
                    const kid = rowMatch[1].trim().toLowerCase();
                    const name = rowMatch[2].trim();
                    if (kid.length < 5) continue;

                    if (!studentCourses[kid]) studentCourses[kid] = [];
                    if (!studentCourses[kid].includes(courseCode)) {
                        studentCourses[kid].push(courseCode);
                    }

                    if (!courseStudents[courseCode]) courseStudents[courseCode] = [];
                    if (!courseStudents[courseCode].find((s) => s.id === kid)) {
                        courseStudents[courseCode].push({ id: kid, name });
                    }
                }
            } catch (err) {
                console.error(`Error processing ${link}:`, err.message);
            }
        }));
    }

    return { studentCourses, courseStudents };
}

function writeJsonExport(dir, data) {
    fs.mkdirSync(dir, { recursive: true });
    const studentPath = path.join(dir, 'studentCourses.json');
    const rosterPath = path.join(dir, 'courseStudents.json');
    const metaPath = path.join(dir, 'meta.json');

    fs.writeFileSync(studentPath, JSON.stringify(data.studentCourses, null, 2));
    fs.writeFileSync(rosterPath, JSON.stringify(data.courseStudents, null, 2));
    fs.writeFileSync(metaPath, JSON.stringify({
        semesterCode,
        semesterPrefix,
        fetchedAt: new Date().toISOString(),
        studentCount: Object.keys(data.studentCourses).length,
        courseCount: Object.keys(data.courseStudents).length,
        source: BASE_URL,
    }, null, 2));

    console.log(`Wrote ${studentPath}`);
    console.log(`Wrote ${rosterPath}`);
    console.log(`Wrote ${metaPath}`);
}

function readJsonExport(dir) {
    const studentPath = path.join(dir, 'studentCourses.json');
    const rosterPath = path.join(dir, 'courseStudents.json');

    if (!fs.existsSync(studentPath) || !fs.existsSync(rosterPath)) {
        throw new Error(
            `Missing JSON in ${dir}. Run on VPN first:\n`
            + `  node scripts/db/import_student_data.js --semester=${semesterCode} --fetch-only`,
        );
    }

    return {
        studentCourses: JSON.parse(fs.readFileSync(studentPath, 'utf8')),
        courseStudents: JSON.parse(fs.readFileSync(rosterPath, 'utf8')),
    };
}

async function importToPostgres(studentCourses, courseStudents) {
    if (dryRun) {
        console.log(
            `[dry-run] Would import ${Object.keys(studentCourses).length} students, `
            + `${Object.keys(courseStudents).length} course rosters for ${semesterCode}`,
        );
        return;
    }

    await withClient(async (client) => {
        const sem = await client.query('SELECT code FROM semesters WHERE code = $1', [semesterCode]);
        if (sem.rowCount === 0) {
            throw new Error(
                `No semesters row for ${semesterCode}. Create it first `
                + '(import_academic_calendar.js, import_catalog.js, or import_historical_catalog.js).',
            );
        }

        await client.query('BEGIN');
        await client.query('DELETE FROM student_enrollments WHERE semester_code = $1', [semesterCode]);
        await client.query('DELETE FROM course_rosters WHERE semester_code = $1', [semesterCode]);

        for (const [kerberos, courseList] of Object.entries(studentCourses)) {
            for (const cc of courseList) {
                await client.query(
                    `INSERT INTO student_enrollments (semester_code, kerberos, course_code)
                     VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
                    [semesterCode, kerberos, cc.toUpperCase()],
                );
            }
        }

        for (const [courseCode, roster] of Object.entries(courseStudents)) {
            for (const row of roster) {
                await client.query(
                    `INSERT INTO course_rosters (semester_code, course_code, student_kerberos, student_name)
                     VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING`,
                    [semesterCode, courseCode.toUpperCase(), row.id, row.name || ''],
                );
            }
        }

        await client.query('COMMIT');
        console.log(
            `Imported ${Object.keys(studentCourses).length} students, `
            + `${Object.keys(courseStudents).length} course rosters for ${semesterCode}`,
        );
    });
}

async function main() {
    let data;

    if (fromJson) {
        console.log(`Loading JSON from ${outDir}…`);
        data = readJsonExport(outDir);
    } else {
        data = await fetchStudentDataFromLdap();
        writeJsonExport(outDir, data);
    }

    if (fetchOnly) {
        console.log(
            `Fetch-only complete (${Object.keys(data.studentCourses).length} students). `
            + 'Import later with --from-json and DATABASE_URL set.',
        );
        return;
    }

    await importToPostgres(data.studentCourses, data.courseStudents);
}

main().catch((e) => {
    console.error(e.message || e);
    process.exit(1);
});
