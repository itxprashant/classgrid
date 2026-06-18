'use strict';

const express = require('express');
const config = require('./config');
const semesterData = require('./semesterData');

const router = express.Router();

function dbUnavailable(_req, res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function withDb(handler) {
    if (!config.databaseUrl) {
        return dbUnavailable;
    }
    return async (req, res, next) => {
        try {
            await handler(req, res);
        } catch (e) {
            if (e.message === 'database_not_configured') {
                dbUnavailable(req, res);
                return;
            }
            next(e);
        }
    };
}

router.get('/catalog', withDb(async (req, res) => {
    const semester = (req.query.semester || '').trim() || undefined;
    const catalog = await semesterData.loadCatalog(semester);
    res.set('ETag', catalog.etag);
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    if (semesterData.notModified(req, catalog.etag)) {
        res.status(304).end();
        return;
    }
    res.json({
        courses: catalog.courses,
        semesterCode: catalog.semesterCode,
        count: catalog.count,
    });
}));

router.get('/catalog/explorer', withDb(async (req, res) => {
    const catalog = await semesterData.loadCatalogExplorer();
    res.set('ETag', catalog.etag);
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    if (semesterData.notModified(req, catalog.etag)) {
        res.status(304).end();
        return;
    }
    res.json({
        courses: catalog.courses,
        semesterCode: catalog.semesterCode,
        count: catalog.count,
        offeredCount: catalog.offeredCount,
    });
}));

router.get('/catalog/meta', withDb(async (req, res) => {
    const semester = (req.query.semester || '').trim() || undefined;
    const catalog = await semesterData.loadCatalog(semester);
    res.set('ETag', catalog.etag);
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    if (semesterData.notModified(req, catalog.etag)) {
        res.status(304).end();
        return;
    }
    res.json({
        semesterCode: catalog.semesterCode,
        count: catalog.count,
        etag: catalog.etag,
    });
}));

module.exports = router;
