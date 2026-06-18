#!/usr/bin/env node
'use strict';

/**
 * Upsert Android APK version gate config.
 * Usage: node scripts/db/import_app_version.js [--pubspec=app/pubspec.yaml]
 *    or: node scripts/db/import_app_version.js --version=1.1.0 --build=6 --url=https://...
 */

const fs = require('fs');
const path = require('path');
const { withClient, parseArgs, repoRoot } = require('./pg');

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

    await withClient(async (client) => {
        await client.query(
            `INSERT INTO app_release_config (platform, version, build, download_url, updated_at)
             VALUES ('android', $1, $2, $3, now())
             ON CONFLICT (platform) DO UPDATE SET
                version = EXCLUDED.version,
                build = EXCLUDED.build,
                download_url = EXCLUDED.download_url,
                updated_at = now()`,
            [version, build, downloadUrl],
        );
        console.log(`App release config: android ${version}+${build}`);
    });
}

main().catch((e) => {
    console.error(e);
    process.exit(1);
});
