'use strict';

const express = require('express');
const config = require('./config');
const semesterData = require('./semesterData');

const router = express.Router();

const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;

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
            next(e);
        }
    };
}

router.get('/semesters', withDb(async (_req, res) => {
    const semesters = await semesterData.listSemesters();
    res.set('Cache-Control', 'public, max-age=300, must-revalidate');
    res.json({ semesters });
}));

router.get('/courses/:courseCode/offerings', withDb(async (req, res) => {
    const courseCode = semesterData.normalizeCourseCode(req.params.courseCode);
    if (!COURSE_CODE_RE.test(courseCode)) {
        res.status(400).json({ error: 'invalid_course_code' });
        return;
    }
    const offerings = await semesterData.getCourseOfferings(courseCode);
    res.set('Cache-Control', 'public, max-age=300, must-revalidate');
    res.json({ courseCode, offerings });
}));

router.get('/instructors/search', withDb(async (req, res) => {
    const q = (req.query.q || '').trim();
    if (q.length < 2) {
        res.status(400).json({ error: 'query_too_short' });
        return;
    }
    const results = await semesterData.searchInstructors(q);
    res.set('Cache-Control', 'public, max-age=60, must-revalidate');
    res.json({ results });
}));

router.get('/instructors/:email/offerings', withDb(async (req, res) => {
    const email = decodeURIComponent(req.params.email || '').trim().toLowerCase();
    if (!email.includes('@')) {
        res.status(400).json({ error: 'invalid_email' });
        return;
    }
    const data = await semesterData.getInstructorOfferings(email);
    if (!data) {
        res.status(404).json({ error: 'instructor_not_found' });
        return;
    }
    res.set('Cache-Control', 'public, max-age=300, must-revalidate');
    res.json(data);
}));

router.get('/students/search', withDb(async (req, res) => {
    const q = (req.query.q || '').trim();
    if (q.length < 2) {
        res.status(400).json({ error: 'query_too_short' });
        return;
    }
    const results = await semesterData.searchStudents(q);
    res.set('Cache-Control', 'public, max-age=60, must-revalidate');
    res.json({ results });
}));

router.get('/students/:kerberos/offerings', withDb(async (req, res) => {
    const kerberos = semesterData.normalizeKerberos(decodeURIComponent(req.params.kerberos || ''));
    if (!kerberos || !semesterData.isStudentKerberos(kerberos)) {
        res.status(404).json({ error: 'student_not_found' });
        return;
    }
    const data = await semesterData.getStudentOfferings(kerberos);
    if (!data) {
        res.status(404).json({ error: 'student_not_found' });
        return;
    }
    res.set('Cache-Control', 'public, max-age=300, must-revalidate');
    res.json(data);
}));

module.exports = router;
