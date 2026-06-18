'use strict';

const express = require('express');
const config = require('./config');
const semesterData = require('./semesterData');

const router = express.Router();

function dbUnavailable(_req, res) {
    res.status(503).json({ error: 'database_unavailable' });
}

router.get('/semester/schedule', async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }
    try {
        const semester = (req.query.semester || '').trim() || undefined;
        const schedule = await semesterData.getAcademicCalendar(semester);
        if (!schedule) {
            res.status(404).json({ error: 'semester_not_found' });
            return;
        }
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json(schedule);
    } catch (e) {
        next(e);
    }
});

router.get('/semester/meta', async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }
    try {
        const semester = (req.query.semester || '').trim() || undefined;
        const meta = await semesterData.getSemesterMeta(semester);
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json(meta);
    } catch (e) {
        next(e);
    }
});

router.get('/extra-occupied', async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }
    try {
        const semester = (req.query.semester || '').trim() || undefined;
        const slots = await semesterData.getExtraOccupied(semester);
        res.set('Cache-Control', 'public, max-age=0, must-revalidate');
        res.json({ slots });
    } catch (e) {
        next(e);
    }
});

module.exports = router;
