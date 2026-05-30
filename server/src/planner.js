'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');

const router = express.Router();

const MAX_COURSES = 64;
const MAX_TIMETABLE_KEYS = 128;

function kerberosFromSession(session) {
    return (session.kerberos || '').trim().toLowerCase();
}

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function isSessionArray(value) {
    return Array.isArray(value);
}

function isPlainObject(value) {
    return value && typeof value === 'object' && !Array.isArray(value);
}

function validatePlanBody(body) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const { selectedCourses, timetableData } = body;
    if (!isSessionArray(selectedCourses)) return { error: 'invalid_selected_courses' };
    if (!isPlainObject(timetableData)) return { error: 'invalid_timetable_data' };
    if (selectedCourses.length > MAX_COURSES) return { error: 'too_many_courses' };
    if (Object.keys(timetableData).length > MAX_TIMETABLE_KEYS) return { error: 'too_many_timetable_entries' };

    for (const course of selectedCourses) {
        if (!course || typeof course !== 'object' || typeof course.courseCode !== 'string') {
            return { error: 'invalid_course_entry' };
        }
    }

    return {
        value: {
            selectedCourses,
            timetableData,
        },
    };
}

router.get('/me/plan', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    try {
        const result = await db.query(
            `SELECT selected_courses, timetable_data, updated_at
             FROM user_plans
             WHERE kerberos = $1`,
            [kerberos]
        );
        if (result.rowCount === 0) {
            res.json({ selectedCourses: [], timetableData: {}, updatedAt: null });
            return;
        }
        const row = result.rows[0];
        res.json({
            selectedCourses: row.selected_courses,
            timetableData: row.timetable_data,
            updatedAt: row.updated_at.toISOString(),
        });
    } catch (e) {
        console.error('[planner] get failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.put('/me/plan', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    const parsed = validatePlanBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }

    const { selectedCourses, timetableData } = parsed.value;

    try {
        const result = await db.query(
            `INSERT INTO user_plans (kerberos, selected_courses, timetable_data, updated_at)
             VALUES ($1, $2::jsonb, $3::jsonb, now())
             ON CONFLICT (kerberos) DO UPDATE SET
                selected_courses = EXCLUDED.selected_courses,
                timetable_data = EXCLUDED.timetable_data,
                updated_at = now()
             RETURNING selected_courses, timetable_data, updated_at`,
            [kerberos, JSON.stringify(selectedCourses), JSON.stringify(timetableData)]
        );
        const row = result.rows[0];
        res.json({
            selectedCourses: row.selected_courses,
            timetableData: row.timetable_data,
            updatedAt: row.updated_at.toISOString(),
        });
    } catch (e) {
        console.error('[planner] put failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
