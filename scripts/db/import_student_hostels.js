#!/usr/bin/env node
'use strict';

/**
 * Upsert student hostel values from a CSV export (OAuth identities / LDAP).
 *
 * Expected columns: providerAccountId (kerberos), name, hostel
 *
 * Usage:
 *   node scripts/db/import_student_hostels.js
 *   node scripts/db/import_student_hostels.js --file=data/student_hostels.csv
 *   node scripts/db/import_student_hostels.js --dry-run
 *
 * Production:
 *   ./scripts/db/run_on_prod.sh import_student_hostels.js
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');
const { isStudentKerberos, normalizeKerberos } = require('./student_kerberos');

const args = parseArgs(process.argv);
const dryRun = Boolean(args['dry-run']);
const file = path.resolve(
    repoRoot,
    args.file || 'data/student_hostels.csv',
);

const BATCH = 250;

function parseCsvLine(line) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('"providerAccountId"')) return null;
    const parts = trimmed.split(',');
    if (parts.length < 3) return null;
    const kerberos = parts[0].trim().replace(/^"|"$/g, '').toLowerCase();
    const hostel = parts[parts.length - 1].trim().replace(/^"|"$/g, '');
    if (!kerberos || !hostel || !isStudentKerberos(kerberos)) return null;
    return { kerberos, hostel };
}

function loadRows() {
    if (!fs.existsSync(file)) {
        console.error(`[import_student_hostels] file not found: ${file}`);
        process.exit(1);
    }
    const text = fs.readFileSync(file, 'utf8');
    const rows = [];
    const seen = new Set();
    for (const line of text.split(/\r?\n/)) {
        const row = parseCsvLine(line);
        if (!row) continue;
        if (seen.has(row.kerberos)) continue;
        seen.add(row.kerberos);
        rows.push(row);
    }
    return rows;
}

async function upsertBatch(client, batch) {
    const kerberosList = batch.map((r) => r.kerberos);
    const hostelList = batch.map((r) => r.hostel);
    await client.query(
        `INSERT INTO students (kerberos, hostel, updated_at)
         SELECT k, h, now()
         FROM unnest($1::text[], $2::text[]) AS t(k, h)
         ON CONFLICT (kerberos) DO UPDATE SET
            hostel = EXCLUDED.hostel,
            updated_at = now()`,
        [kerberosList, hostelList],
    );
}

async function main() {
    const rows = loadRows();
    console.log(`[import_student_hostels] ${rows.length} rows from ${file}`);
    if (dryRun) {
        console.log('[import_student_hostels] dry run — first 5:', rows.slice(0, 5));
        return;
    }
    await withClient(async (client) => {
        await client.query('BEGIN');
        try {
            for (let i = 0; i < rows.length; i += BATCH) {
                const batch = rows.slice(i, i + BATCH);
                await upsertBatch(client, batch);
                console.log(`[import_student_hostels] upserted ${Math.min(i + BATCH, rows.length)}/${rows.length}`);
            }
            await client.query('COMMIT');
        } catch (e) {
            await client.query('ROLLBACK');
            throw e;
        }
    });
    console.log('[import_student_hostels] done.');
}

main().catch((e) => {
    console.error('[import_student_hostels] failed:', e.message || e);
    process.exit(1);
});
