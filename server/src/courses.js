'use strict';

const fs = require('fs');
const path = require('path');
const express = require('express');
const config = require('./config');
const { requireSession } = require('./session');

const router = express.Router();

let studentCourses = {};
let loadedPath = null;

function loadStudentCourses() {
    const p = config.studentCoursesPath;
    try {
        const raw = fs.readFileSync(p, 'utf8');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            studentCourses = parsed;
            loadedPath = p;
            const count = Object.keys(studentCourses).length;
            console.log(`[courses] loaded ${count} students from ${p}`);
        } else {
            console.warn(`[courses] ${p} did not contain a map; using empty data`);
            studentCourses = {};
            loadedPath = p;
        }
    } catch (e) {
        console.warn(`[courses] could not load ${p}: ${e.message}`);
        studentCourses = {};
        loadedPath = null;
    }
}

loadStudentCourses();

router.get('/me/courses', requireSession, (req, res) => {
    const kerberos = (req.session.kerberos || '').toLowerCase().trim();
    if (!kerberos) {
        res.json({ kerberos: null, courses: [] });
        return;
    }
    const courses = studentCourses[kerberos] || [];
    res.json({ kerberos, courses });
});

router.get('/me', requireSession, (req, res) => {
    const { kerberos, name, picture, email } = req.session;
    res.json({ kerberos, name, picture, email });
});

router.get('/health', (req, res) => {
    res.json({
        ok: true,
        students: Object.keys(studentCourses).length,
        path: loadedPath,
    });
});

function getEnrolledCourses(kerberos) {
    const key = (kerberos || '').toLowerCase().trim();
    if (!key) return [];
    return studentCourses[key] || [];
}

module.exports = router;
module.exports.getEnrolledCourses = getEnrolledCourses;
