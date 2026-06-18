#!/usr/bin/env node
'use strict';

/**
 * Import academic calendar into semesters table.
 * Usage: DATABASE_URL=... node scripts/db/import_academic_calendar.js [--file=data/academic_calendar.json]
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');

const args = parseArgs(process.argv);
const filePath = args.file
    ? path.resolve(args.file)
    : path.join(repoRoot, 'data', 'academic_calendar.json');

async function main() {
    const cal = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const sem = cal.semester;
    if (!sem || !sem.code) {
        console.error('academic_calendar.json must include semester.code');
        process.exit(1);
    }

    await withClient(async (client) => {
        await client.query(
            `INSERT INTO semesters (code, label, classes_start, last_teaching_day, is_active, academic_calendar)
             VALUES ($1, $2, $3::date, $4::date, false, $5::jsonb)
             ON CONFLICT (code) DO UPDATE SET
                label = EXCLUDED.label,
                classes_start = EXCLUDED.classes_start,
                last_teaching_day = EXCLUDED.last_teaching_day,
                academic_calendar = EXCLUDED.academic_calendar,
                updated_at = now()`,
            [
                sem.code,
                sem.label,
                sem.classesStart,
                sem.lastTeachingDay,
                JSON.stringify({
                    holidays: cal.holidays || {},
                    scheduleExceptions: cal.scheduleExceptions || {},
                    noClassPeriods: cal.noClassPeriods || [],
                }),
            ],
        );
        console.log(`Upserted academic calendar for semester ${sem.code}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
