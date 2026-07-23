#!/usr/bin/env node
'use strict';

/**
 * Sync lecture halls from room allotment PDF into Postgres catalog.
 * Usage: DATABASE_URL=... node scripts/db/sync_venues.js --semester=2601
 *
 * Prefers data/venue_map.json when present (pre-extracted), else runs
 * scripts/extract_venue_map.py (needs pypdf/PyPDF2).
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, computeCatalogEtag } = require('./pg');

const args = parseArgs(process.argv);
const semesterCode = args.semester;
if (!semesterCode) {
    console.error('Usage: node scripts/db/sync_venues.js --semester=CODE');
    process.exit(1);
}

/** Allotment PDF often lists sections as CVL100A / CVL100B; catalog uses CVL100. */
const SECTION_SUFFIX_RE = /^([A-Z]+\d+)[A-Z]$/;

function mergeVenues(into, code, venues) {
    if (!venues || !venues.length) return;
    const set = new Set(into[code] || []);
    for (const v of venues) {
        if (v) set.add(v);
    }
    into[code] = [...set].sort();
}

/** Fold section-letter codes into their base (CVL100A+B → CVL100). */
function expandSectionVenues(pdfData) {
    const out = {};
    for (const [code, venues] of Object.entries(pdfData)) {
        mergeVenues(out, code, venues);
        const m = SECTION_SUFFIX_RE.exec(code);
        if (m) mergeVenues(out, m[1], venues);
    }
    return out;
}

function loadVenueMap() {
    const repoRoot = path.join(__dirname, '..', '..');
    const mapPath = process.env.VENUE_MAP_JSON
        || path.join(repoRoot, 'data', 'venue_map.json');
    if (fs.existsSync(mapPath)) {
        const pdfData = JSON.parse(fs.readFileSync(mapPath, 'utf8'));
        console.log(`Loaded venue map from ${mapPath} (${Object.keys(pdfData).length} courses)`);
        return expandSectionVenues(pdfData);
    }
    const extractScript = path.join(__dirname, '..', 'extract_venue_map.py');
    const raw = execSync(`python3 "${extractScript}"`, {
        encoding: 'utf8',
        maxBuffer: 50 * 1024 * 1024,
    });
    return expandSectionVenues(JSON.parse(raw));
}

async function main() {
    const pdfData = loadVenueMap();

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
        // Bump catalog_etag so clients (Flutter ETag cache, SPA) refetch halls.
        // Previously only catalog_updated_at changed, so apps kept a 304-stale
        // catalog without lectureHall.
        const now = new Date().toISOString();
        const { rows: countRows } = await client.query(
            'SELECT COUNT(*)::int AS n FROM catalog_courses WHERE semester_code = $1',
            [semesterCode],
        );
        const etag = computeCatalogEtag(semesterCode, countRows[0].n, now);
        await client.query(
            `UPDATE semesters
             SET catalog_etag = $2, catalog_updated_at = now(), updated_at = now()
             WHERE code = $1`,
            [semesterCode, etag],
        );
        await client.query('COMMIT');
        console.log(
            `Updated lecture halls for ${updated} courses in semester ${semesterCode} (etag ${etag})`,
        );
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
