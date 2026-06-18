#!/usr/bin/env node
'use strict';

/**
 * Import legacy extra-occupied weekly overlay slots.
 * Usage: DATABASE_URL=... node scripts/db/import_extra_occupied.js --semester=2601 [--file=data/extra_occupied.json]
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
if (!semesterCode) {
    console.error('Usage: node scripts/db/import_extra_occupied.js --semester=CODE [--file=path]');
    process.exit(1);
}

const filePath = args.file
    ? path.resolve(args.file)
    : path.join(repoRoot, 'data', 'extra_occupied.json');

async function main() {
    const slots = JSON.parse(fs.readFileSync(filePath, 'utf8'));

    await withClient(async (client) => {
        await client.query('BEGIN');
        await client.query('DELETE FROM extra_occupied_slots WHERE semester_code = $1', [semesterCode]);
        for (const slot of slots) {
            if (!slot || !slot.lectureHall) continue;
            await client.query(
                `INSERT INTO extra_occupied_slots
                 (semester_code, lecture_hall, day_of_week, start_time, end_time, reason)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                    semesterCode,
                    slot.lectureHall,
                    slot.day,
                    slot.startTime,
                    slot.endTime,
                    slot.reason || null,
                ],
            );
        }
        await client.query('COMMIT');
        console.log(`Imported ${slots.length} extra-occupied slots for ${semesterCode}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
