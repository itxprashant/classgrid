#!/usr/bin/env node
'use strict';

/**
 * Import course catalog from CSV into Postgres.
 * Usage: DATABASE_URL=... node scripts/db/import_catalog.js --semester=2601 [--csv=data/Courses_Offered.csv]
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');
const { parseCoursesFromCsv } = require('./parse_catalog_csv');
const { importCatalogForSemester } = require('./import_catalog_core');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
if (!semesterCode) {
    console.error('Usage: node scripts/db/import_catalog.js --semester=CODE [--csv=path]');
    process.exit(1);
}

const csvPath = args.csv
    ? path.resolve(args.csv)
    : path.join(repoRoot, 'data', 'Courses_Offered.csv');

async function main() {
    if (!fs.existsSync(csvPath)) {
        console.error(`CSV not found: ${csvPath}`);
        process.exit(1);
    }

    const courses = parseCoursesFromCsv(csvPath, semesterCode);

    await withClient(async (client) => {
        const { rows } = await client.query('SELECT code FROM semesters WHERE code = $1', [semesterCode]);
        if (!rows.length) {
            console.error(`Semester ${semesterCode} not found. Run import_academic_calendar.js first.`);
            process.exit(1);
        }

        await client.query('BEGIN');
        const count = await importCatalogForSemester(client, semesterCode, courses);
        await client.query('COMMIT');
        console.log(`Imported ${count} courses for semester ${semesterCode}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
