#!/usr/bin/env node
'use strict';

/**
 * Bulk-import historical catalog CSVs from data/courses_offered_historical/.
 * Usage: DATABASE_URL=... node scripts/db/import_historical_catalog.js [--dir=path] [--semester=2502] [--dry-run]
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');
const { parseCoursesFromCsv } = require('./parse_catalog_csv');
const { semesterMetaFromCode } = require('./semester_code_meta');
const { upsertSemesterStub, importCatalogForSemester } = require('./import_catalog_core');

const args = parseArgs(process.argv);
const dirPath = args.dir
    ? path.resolve(args.dir)
    : path.join(repoRoot, 'data', 'courses_offered_historical');
const dryRun = Boolean(args['dry-run']);

function listCsvFiles() {
    if (!fs.existsSync(dirPath)) {
        console.error(`Directory not found: ${dirPath}`);
        process.exit(1);
    }
    const files = fs.readdirSync(dirPath)
        .filter((f) => f.endsWith('.csv'))
        .map((f) => ({
            semesterCode: path.basename(f, '.csv'),
            csvPath: path.join(dirPath, f),
        }))
        .filter(({ semesterCode }) => /^\d{4}$/.test(semesterCode))
        .sort((a, b) => a.semesterCode.localeCompare(b.semesterCode));

    if (args.semester) {
        return files.filter((f) => f.semesterCode === args.semester);
    }
    return files;
}

async function importOne(client, { semesterCode, csvPath }) {
    const meta = semesterMetaFromCode(semesterCode);
    const courses = parseCoursesFromCsv(csvPath, semesterCode);

    if (dryRun) {
        console.log(`[dry-run] ${semesterCode}: ${courses.length} courses (${meta.label})`);
        return courses.length;
    }

    const { rows: activeRows } = await client.query(
        'SELECT is_active FROM semesters WHERE code = $1',
        [semesterCode],
    );
    if (activeRows.length && activeRows[0].is_active) {
        console.warn(`Skipping ${semesterCode}: semester is active (use import_catalog.js for current term)`);
        return 0;
    }

    await upsertSemesterStub(client, semesterCode, meta);
    const count = await importCatalogForSemester(client, semesterCode, courses);
    console.log(`Imported ${count} courses for ${semesterCode} (${meta.label})`);
    return count;
}

async function main() {
    const files = listCsvFiles();
    if (!files.length) {
        console.error('No CSV files found to import.');
        process.exit(1);
    }

    console.log(`Importing ${files.length} historical catalog(s) from ${dirPath}${dryRun ? ' (dry-run)' : ''}`);

    if (dryRun) {
        for (const file of files) {
            await importOne(null, file);
        }
        return;
    }

    await withClient(async (client) => {
        await client.query('BEGIN');
        let total = 0;
        for (const file of files) {
            total += await importOne(client, file);
        }
        await client.query('COMMIT');
        console.log(`Done. ${total} total course rows across ${files.length} semester(s).`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
