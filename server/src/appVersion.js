'use strict';

const express = require('express');
const config = require('./config');
const { loadAndroidApp, logAndroidAppLoaded } = require('./androidVersion');

const router = express.Router();

const androidApp = loadAndroidApp(config);
logAndroidAppLoaded(config, androidApp);

/**
 * Minimum Android app version required to use the API (force-update gate).
 * Source of truth: server/data/android-version.json (deployed with ./deploy.sh --api).
 *
 * GET /api/app/version
 * → { android: { version, build, downloadUrl } }
 */
router.get('/app/version', (req, res) => {
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    res.json({ android: androidApp });
});

module.exports = router;
