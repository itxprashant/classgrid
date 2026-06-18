'use strict';

const express = require('express');
const config = require('./config');
const { requireSession } = require('./session');
const semesterData = require('./semesterData');

const router = express.Router();

const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;

function dbUnavailable(_req, res) {
    res.status(503).json({ error: 'database_unavailable' });
}

router.get('/courses/:courseCode/students', async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }
    try {
        const courseCode = semesterData.normalizeCourseCode(req.params.courseCode);
        if (!COURSE_CODE_RE.test(courseCode)) {
            res.status(400).json({ error: 'invalid_course_code' });
            return;
        }
        const semester = (req.query.semester || '').trim() || undefined;
        const students = await semesterData.getCourseRoster(courseCode, semester);
        res.json({ courseCode, count: students.length, students });
    } catch (e) {
        next(e);
    }
});

router.get('/me/courses', requireSession, async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }
    try {
        const kerberos = semesterData.normalizeKerberos(req.session.kerberos);
        if (!kerberos) {
            res.json({ kerberos: null, courses: [] });
            return;
        }
        const semester = (req.query.semester || '').trim() || undefined;
        const courses = await semesterData.getEnrolledCourses(kerberos, semester);
        res.json({ kerberos, courses });
    } catch (e) {
        next(e);
    }
});

router.get('/me', requireSession, async (req, res, next) => {
    const { kerberos, name, picture, email } = req.session;
    let { hostel } = req.session;
    if (!hostel && kerberos && config.databaseUrl) {
        try {
            hostel = await semesterData.getStudentHostel(kerberos);
        } catch (e) {
            next(e);
            return;
        }
    }
    res.json({
        kerberos,
        name,
        picture,
        email,
        hostel: hostel || null,
    });
});

router.get('/health', async (req, res, next) => {
    try {
        const stats = config.databaseUrl
            ? await semesterData.getHealthStats()
            : { activeSemester: null, catalogCount: 0, enrolledStudents: 0 };
        res.json({
            ok: true,
            database: Boolean(config.databaseUrl),
            semesterDataLoaded: semesterData.isCacheReady(),
            ...stats,
        });
    } catch (e) {
        next(e);
    }
});

async function getEnrolledCourses(kerberos) {
    if (!config.databaseUrl) return [];
    return semesterData.getEnrolledCourses(kerberos);
}

module.exports = router;
module.exports.getEnrolledCourses = getEnrolledCourses;
