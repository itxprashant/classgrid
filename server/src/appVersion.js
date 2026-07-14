'use strict';

const express = require('express');
const config = require('./config');
const semesterData = require('./semesterData');

const router = express.Router();

const DEFAULT_ANDROID = {
    version: '1.0.0',
    build: 1,
    downloadUrl: 'https://classgrid.devclub.in/app/classgrid.apk',
    minimumVersion: '1.0.0',
    minimumBuild: 1,
    latestReleaseNotes: '',
};

function buildAndroidPayload(raw) {
    const latestVersion = (raw.version || DEFAULT_ANDROID.version).trim();
    const latestBuild = Number.isFinite(Number(raw.build)) ? Number(raw.build) : DEFAULT_ANDROID.build;
    const downloadUrl = (raw.downloadUrl || DEFAULT_ANDROID.downloadUrl).trim();
    const minimumVersion = (raw.minimumVersion || latestVersion).trim();
    const minimumBuild = Number.isFinite(Number(raw.minimumBuild))
        ? Number(raw.minimumBuild)
        : latestBuild;
    const releaseNotes = (raw.latestReleaseNotes || '').toString();

    const latest = {
        version: latestVersion,
        build: latestBuild,
        downloadUrl,
        releaseNotes,
    };
    const minimum = {
        version: minimumVersion,
        build: minimumBuild,
    };

    return {
        version: latestVersion,
        build: latestBuild,
        downloadUrl,
        minimum,
        latest,
    };
}

/**
 * Android app version gate + optional update info.
 * Source of truth: app_release_config + app_release_history in Postgres.
 *
 * GET /api/app/version
 * → { android: { version, build, downloadUrl, minimum, latest } }
 */
router.get('/app/version', async (req, res, next) => {
    try {
        let androidApp = DEFAULT_ANDROID;
        if (config.databaseUrl) {
            androidApp = await semesterData.getAppReleaseConfig('android');
        }
        const version = (process.env.ANDROID_APP_VERSION || androidApp.version).trim();
        const build = Number(process.env.ANDROID_APP_BUILD || androidApp.build);
        const downloadUrl = (process.env.ANDROID_APK_URL || androidApp.downloadUrl).trim();
        const payload = buildAndroidPayload({
            version: version || DEFAULT_ANDROID.version,
            build: Number.isFinite(build) ? build : DEFAULT_ANDROID.build,
            downloadUrl: downloadUrl || DEFAULT_ANDROID.downloadUrl,
            minimumVersion: androidApp.minimumVersion,
            minimumBuild: androidApp.minimumBuild,
            latestReleaseNotes: androidApp.latestReleaseNotes,
        });
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json({ android: payload });
    } catch (e) {
        next(e);
    }
});

/**
 * Paginated release history for in-app changelog.
 *
 * GET /api/app/changelog?platform=android&limit=20&offset=0
 */
router.get('/app/changelog', async (req, res, next) => {
    try {
        if (!config.databaseUrl) {
            return res.status(503).json({ error: 'database_unavailable' });
        }
        const platform = (req.query.platform || 'android').toString().trim() || 'android';
        const limit = req.query.limit;
        const offset = req.query.offset;
        const data = await semesterData.listAppReleaseHistory(platform, { limit, offset });
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json(data);
    } catch (e) {
        next(e);
    }
});

module.exports = router;
