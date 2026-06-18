#!/usr/bin/env node
'use strict';

/**
 * Sync lecture halls from room allotment PDF into Postgres catalog.
 * Usage: DATABASE_URL=... node scripts/db/sync_venues.js --semester=2601
 */

const { execSync } = require('child_process');
const path = require('path');
const { withClient, parseArgs } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
if (!semesterCode) {
    console.error('Usage: node scripts/db/sync_venues.js --semester=CODE');
    process.exit(1);
}

async function main() {
    const extractScript = path.join(__dirname, '..', 'extract_venue_map.py');
    const raw = execSync(`python3 "${extractScript}"`, { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
    const pdfData = JSON.parse(raw);

    await withClient(async (client) => {
        const { rows } = await client.query(
            'SELECT course_code, course_data FROM catalog_courses WHERE semester_code = $1',
            [semesterCode],
        );
        let updated = 0;
        await client.query('BEGIN');
        for (const row of rows) {
            const code = row.course_code;
            const venues = pdfData[code];
            if (!venues || !venues.length) continue;
            const newHall = venues.join(', ');
            const data = { ...row.course_data, lectureHall: newHall };
            if (row.course_data?.lectureHall === newHall) continue;
            await client.query(
                `UPDATE catalog_courses SET course_data = $3::jsonb
                 WHERE semester_code = $1 AND course_code = $2`,
                [semesterCode, code, JSON.stringify(data)],
            );
            updated += 1;
        }
        await client.query(
            'UPDATE semesters SET catalog_updated_at = now(), updated_at = now() WHERE code = $1',
            [semesterCode],
        );
        await client.query('COMMIT');
        console.log(`Updated lecture halls for ${updated} courses in semester ${semesterCode}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
