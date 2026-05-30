'use strict';

const fs = require('fs');
const express = require('express');
const config = require('./config');
const { requireSession } = require('./session');

const router = express.Router();

let studentCourses = {};
let studentCoursesPath = null;

let courseStudents = {};
let courseStudentsPath = null;

const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;

function loadStudentCourses() {
    const p = config.studentCoursesPath;
    try {
        const raw = fs.readFileSync(p, 'utf8');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            studentCourses = parsed;
            studentCoursesPath = p;
            const count = Object.keys(studentCourses).length;
            console.log(`[courses] loaded ${count} students from ${p}`);
        } else {
            console.warn(`[courses] ${p} did not contain a map; using empty data`);
            studentCourses = {};
            studentCoursesPath = p;
        }
    } catch (e) {
        console.warn(`[courses] could not load ${p}: ${e.message}`);
        studentCourses = {};
        studentCoursesPath = null;
    }
}

function loadCourseStudents() {
    const p = config.courseStudentsPath;
    try {
        const raw = fs.readFileSync(p, 'utf8');
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
            courseStudents = parsed;
            courseStudentsPath = p;
            const count = Object.keys(courseStudents).length;
            console.log(`[courses] loaded roster data for ${count} courses from ${p}`);
        } else {
            console.warn(`[courses] ${p} did not contain a map; using empty roster data`);
            courseStudents = {};
            courseStudentsPath = p;
        }
    } catch (e) {
        console.warn(`[courses] could not load ${p}: ${e.message}`);
        courseStudents = {};
        courseStudentsPath = null;
    }
}

loadStudentCourses();
loadCourseStudents();

function normalizeCourseCode(code) {
    return (code || '').trim().toUpperCase();
}

function rosterForCourse(courseCode) {
    const key = normalizeCourseCode(courseCode);
    const raw = courseStudents[key];
    if (!Array.isArray(raw)) return [];
    return raw
        .filter((row) => row && typeof row.id === 'string')
        .map((row) => ({
            id: row.id.trim(),
            name: typeof row.name === 'string' ? row.name.trim() : '',
        }))
        .filter((row) => row.id.length > 0);
}

router.get('/courses/:courseCode/students', (req, res) => {
    const courseCode = normalizeCourseCode(req.params.courseCode);
    if (!COURSE_CODE_RE.test(courseCode)) {
        res.status(400).json({ error: 'invalid_course_code' });
        return;
    }
    const students = rosterForCourse(courseCode);
    res.json({ courseCode, count: students.length, students });
});

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
        coursesWithRoster: Object.keys(courseStudents).length,
        studentCoursesPath,
        courseStudentsPath,
    });
});

function getEnrolledCourses(kerberos) {
    const key = (kerberos || '').toLowerCase().trim();
    if (!key) return [];
    return studentCourses[key] || [];
}

module.exports = router;
module.exports.getEnrolledCourses = getEnrolledCourses;
