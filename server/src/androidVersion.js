'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_DOWNLOAD_URL =
    'https://drive.google.com/file/d/1_3fPAEBmWddY7HQ18oXbgiOwQSYJdr3I/view?usp=sharing';

const DEFAULTS = {
    version: '1.0.0',
    build: 1,
    downloadUrl: DEFAULT_DOWNLOAD_URL,
};

/**
 * Load minimum Android app version from server/data/android-version.json
 * (rsynced to /opt/classgrid-api/data/ on deploy). Env vars override file values.
 */
function loadAndroidApp(config) {
    const filePath = config.androidVersionPath;
    let fromFile = { ...DEFAULTS };

    try {
        const raw = fs.readFileSync(filePath, 'utf8');
        const parsed = JSON.parse(raw);
        const a = parsed && (parsed.android || parsed);
        if (a && typeof a === 'object') {
            fromFile = {
                version: String(a.version ?? DEFAULTS.version).trim(),
                build: Number(a.build ?? DEFAULTS.build),
                downloadUrl: String(a.downloadUrl ?? DEFAULTS.downloadUrl).trim(),
            };
        }
    } catch (e) {
        console.warn(`[app-version] could not load ${filePath}: ${e.message}`);
    }

    const version = (process.env.ANDROID_APP_VERSION || fromFile.version).trim();
    const build = Number(process.env.ANDROID_APP_BUILD || fromFile.build);
    const downloadUrl = (process.env.ANDROID_APK_URL || fromFile.downloadUrl).trim();

    return {
        version: version || DEFAULTS.version,
        build: Number.isFinite(build) ? build : DEFAULTS.build,
        downloadUrl: downloadUrl || DEFAULTS.downloadUrl,
    };
}

function logAndroidAppLoaded(config, androidApp) {
    console.log(
        `[app-version] android minimum ${androidApp.version}+${androidApp.build} `
        + `from ${path.resolve(config.androidVersionPath)}`,
    );
}

module.exports = { loadAndroidApp, logAndroidAppLoaded };
