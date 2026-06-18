#!/usr/bin/env node
'use strict';

/** Re-apply labels + term dates from semester_code_meta for every row in semesters. */
const { withClient, parseArgs } = require('./pg');
const { semesterMetaFromCode } = require('./semester_code_meta');

const dryRun = Boolean(parseArgs(process.argv)['dry-run']);

async function main() {
    await withClient(async (client) => {
        const { rows } = await client.query('SELECT code FROM semesters ORDER BY code');
        if (!rows.length) {
            console.log('No semesters in DB.');
            return;
        }
        if (!dryRun) await client.query('BEGIN');
        for (const { code } of rows) {
            const meta = semesterMetaFromCode(code);
            console.log(`${code} → ${meta.label} (${meta.classesStart} … ${meta.lastTeachingDay})`);
            if (!dryRun) {
                await client.query(
                    `UPDATE semesters
                     SET label = $2,
                         classes_start = $3::date,
                         last_teaching_day = $4::date,
                         updated_at = now()
                     WHERE code = $1`,
                    [code, meta.label, meta.classesStart, meta.lastTeachingDay],
                );
            }
        }
        if (!dryRun) await client.query('COMMIT');
        console.log(dryRun ? 'Dry run — no rows updated.' : `Updated ${rows.length} semester row(s).`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
