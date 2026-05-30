'use strict';

const crypto = require('crypto');
const fs = require('fs');
const express = require('express');
const config = require('./config');

const router = express.Router();

// Loaded once at boot and cached in memory. The catalog is a static, multi-MB
// JSON file refreshed only at semester boundaries, so we keep the parsed array,
// its raw body length, and a strong ETag for conditional requests.
let catalog = [];
let etag = null;
let semesterCode = null;
let loadedPath = null;

function loadCatalog() {
    const p = config.catalogPath;
    try {
        const raw = fs.readFileSync(p, 'utf8');
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
            catalog = parsed;
            loadedPath = p;
            etag = '"' + crypto.createHash('sha1').update(raw).digest('hex') + '"';
            semesterCode = (parsed.find((c) => c && c.semesterCode) || {}).semesterCode || null;
            console.log(`[catalog] loaded ${catalog.length} courses from ${p}`);
        } else {
            console.warn(`[catalog] ${p} did not contain an array; using empty data`);
            catalog = [];
            loadedPath = p;
            etag = '"empty"';
            semesterCode = null;
        }
    } catch (e) {
        console.warn(`[catalog] could not load ${p}: ${e.message}`);
        catalog = [];
        loadedPath = null;
        etag = '"empty"';
        semesterCode = null;
    }
}

loadCatalog();

function notModified(req) {
    const inm = req.headers['if-none-match'];
    if (!inm || !etag) return false;
    // Handle comma-separated lists and weak validators defensively.
    return inm.split(',').map((s) => s.trim()).some((tag) => tag === etag || tag === 'W/' + etag);
}

router.get('/catalog', (req, res) => {
    res.set('ETag', etag);
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    if (notModified(req)) {
        res.status(304).end();
        return;
    }
    res.json({ courses: catalog, semesterCode, count: catalog.length });
});

router.get('/catalog/meta', (req, res) => {
    res.set('ETag', etag);
    res.set('Cache-Control', 'public, max-age=0, must-revalidate');
    if (notModified(req)) {
        res.status(304).end();
        return;
    }
    res.json({ semesterCode, count: catalog.length, etag });
});

module.exports = router;
