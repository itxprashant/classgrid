#!/usr/bin/env node
'use strict';

/**
 * Upsert Android APK version gate config and append release history.
 *
 * Usage:
 *   node scripts/db/import_app_version.js [--pubspec=app/pubspec.yaml]
 *   node scripts/db/import_app_version.js --version=1.1.0 --build=6 --url=https://...
 *
 * Options:
 *   --notes-file=CHANGELOG.md   Parse release notes for --version (default: repo CHANGELOG.md)
 *   --skip-notes                Skip changelog parse + history insert (dev only)
 *   --bump-minimum              Set minimum_version/build to the new release (force update)
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');
const { parseChangelogSection } = require('../lib/parse_changelog');

const args = parseArgs(process.argv);

function parsePubspec(filePath) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const match = raw.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/m);
    if (!match) throw new Error(`Could not parse version from ${filePath}`);
    const version = match[1];
    const build = Number(match[2]);
    const downloadUrl = args.url
        || `https://classgrid.devclub.in/app/classgrid-${version}+${build}.apk`;
    return { version, build, downloadUrl };
}

function resolveNotesFile() {
    if (args['notes-file']) {
        return path.resolve(args['notes-file']);
    }
    return path.join(repoRoot, 'CHANGELOG.md');
}

async function main() {
    let version;
    let build;
    let downloadUrl;

    if (args.version && args.build) {
        version = args.version;
        build = Number(args.build);
        downloadUrl = args.url || `https://classgrid.devclub.in/app/classgrid-${version}+${build}.apk`;
    } else {
        const pubspec = args.pubspec
            ? path.resolve(args.pubspec)
            : path.join(repoRoot, 'app', 'pubspec.yaml');
        ({ version, build, downloadUrl } = parsePubspec(pubspec));
    }

    let releaseNotes = '';
    if (!args['skip-notes']) {
        const notesFile = resolveNotesFile();
        releaseNotes = parseChangelogSection(notesFile, version);
    }

    const bumpMinimum = Boolean(args['bump-minimum']);

    await withClient(async (client) => {
        if (bumpMinimum) {
            await client.query(
                `INSERT INTO app_release_config (
                    platform, version, build, download_url,
                    minimum_version, minimum_build, updated_at
                 )
                 VALUES ('android', $1, $2, $3, $1, $2, now())
                 ON CONFLICT (platform) DO UPDATE SET
                    version = EXCLUDED.version,
                    build = EXCLUDED.build,
                    download_url = EXCLUDED.download_url,
                    minimum_version = EXCLUDED.minimum_version,
                    minimum_build = EXCLUDED.minimum_build,
                    updated_at = now()`,
                [version, build, downloadUrl],
            );
        } else {
            await client.query(
                `INSERT INTO app_release_config (
                    platform, version, build, download_url,
                    minimum_version, minimum_build, updated_at
                 )
                 VALUES ('android', $1, $2, $3, $1, $2, now())
                 ON CONFLICT (platform) DO UPDATE SET
                    version = EXCLUDED.version,
                    build = EXCLUDED.build,
                    download_url = EXCLUDED.download_url,
                    updated_at = now()`,
                [version, build, downloadUrl],
            );
        }

        if (!args['skip-notes']) {
            await client.query(
                `INSERT INTO app_release_history (
                    platform, build, version, download_url, release_notes, published_at
                 )
                 VALUES ('android', $1, $2, $3, $4, now())
                 ON CONFLICT (platform, build) DO UPDATE SET
                    version = EXCLUDED.version,
                    download_url = EXCLUDED.download_url,
                    release_notes = EXCLUDED.release_notes,
                    published_at = now()`,
                [build, version, downloadUrl, releaseNotes],
            );
        }

        const { rows } = await client.query(
            `SELECT minimum_version, minimum_build FROM app_release_config WHERE platform = 'android'`,
        );
        const min = rows[0];
        console.log(
            `App release config: android latest ${version}+${build}, `
            + `minimum ${min.minimum_version}+${min.minimum_build}`,
        );
        if (!args['skip-notes']) {
            console.log(`Release history: build ${build} (${releaseNotes.split('\n').length} lines of notes)`);
        }
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
