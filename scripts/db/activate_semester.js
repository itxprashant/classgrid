#!/usr/bin/env node
'use strict';

/**
 * Set the active semester (deactivates all others).
 * Usage: DATABASE_URL=... node scripts/db/activate_semester.js --semester=2601
 */

const { withClient, parseArgs } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
if (!semesterCode) {
    console.error('Usage: node scripts/db/activate_semester.js --semester=CODE');
    process.exit(1);
}

async function main() {
    await withClient(async (client) => {
        const { rows } = await client.query('SELECT code FROM semesters WHERE code = $1', [semesterCode]);
        if (!rows.length) {
            console.error(`Semester ${semesterCode} not found`);
            process.exit(1);
        }
        await client.query('BEGIN');
        await client.query('UPDATE semesters SET is_active = false');
        await client.query('UPDATE semesters SET is_active = true WHERE code = $1', [semesterCode]);
        await client.query('COMMIT');
        console.log(`Activated semester ${semesterCode}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
