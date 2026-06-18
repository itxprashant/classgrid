'use strict';

const express = require('express');
const config = require('./config');
const semesterData = require('./semesterData');

const router = express.Router();

const DEFAULT_ANDROID = {
    version: '1.0.0',
    build: 1,
    downloadUrl: 'https://classgrid.devclub.in/app/classgrid.apk',
};

/**
 * Minimum Android app version required to use the API (force-update gate).
 * Source of truth: app_release_config in Postgres.
 *
 * GET /api/app/version
 * → { android: { version, build, downloadUrl } }
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
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json({
            android: {
                version: version || DEFAULT_ANDROID.version,
                build: Number.isFinite(build) ? build : DEFAULT_ANDROID.build,
                downloadUrl: downloadUrl || DEFAULT_ANDROID.downloadUrl,
            },
        });
    } catch (e) {
        next(e);
    }
});

module.exports = router;
