'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');
const semesterData = require('./semesterData');

const router = express.Router();

const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;
const MAX_FIELD_LEN = 8000;

function normalizeCourseCode(code) {
    return semesterData.normalizeCourseCode(code);
}

function actorFromSession(session) {
    return {
        kerberos: session.kerberos ? String(session.kerberos).trim().toLowerCase() : null,
        name: (session.name || session.kerberos || 'Unknown').trim(),
    };
}

function rowToPolicy(row) {
    return {
        markingScheme: row.marking_scheme || '',
        attendancePolicy: row.attendance_policy || '',
        auditWithdrawalPolicy: row.audit_withdrawal_policy || '',
        otherNotes: row.other_notes || '',
        createdBy: {
            kerberos: row.created_kerberos || undefined,
            name: row.created_name,
            at: row.created_at.toISOString(),
        },
        updatedBy: {
            kerberos: row.updated_kerberos || undefined,
            name: row.updated_name,
            at: row.updated_at.toISOString(),
        },
    };
}

function normalizeField(value) {
    if (value == null) return '';
    return String(value).trim().slice(0, MAX_FIELD_LEN);
}

function validatePolicyBody(body) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const markingScheme = normalizeField(body.markingScheme);
    const attendancePolicy = normalizeField(body.attendancePolicy);
    const auditWithdrawalPolicy = normalizeField(body.auditWithdrawalPolicy);
    const otherNotes = normalizeField(body.otherNotes);

    const hasContent = markingScheme || attendancePolicy || auditWithdrawalPolicy || otherNotes;
    if (!hasContent) return { error: 'empty_policy' };

    return {
        value: {
            markingScheme,
            attendancePolicy,
            auditWithdrawalPolicy,
            otherNotes,
        },
    };
}

function dbUnavailable(_req, res) {
    res.status(503).json({ error: 'database_unavailable' });
}

async function assertEnrolled(kerberos, courseCode, semesterCode) {
    const enrolled = await semesterData.getEnrolledCourses(kerberos, semesterCode);
    const codes = enrolled.map(normalizeCourseCode);
    return codes.includes(normalizeCourseCode(courseCode));
}

router.get('/courses/:courseCode/policy', requireSession, async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    try {
        const courseCode = normalizeCourseCode(req.params.courseCode);
        if (!COURSE_CODE_RE.test(courseCode)) {
            res.status(400).json({ error: 'invalid_course_code' });
            return;
        }

        const semesterCode = await semesterData.resolveSemesterCode(
            (req.query.semester || '').trim() || undefined,
        );
        if (!semesterCode) {
            res.status(503).json({ error: 'semester_unavailable' });
            return;
        }

        const kerberos = semesterData.normalizeKerberos(req.session.kerberos);
        if (!kerberos || !(await assertEnrolled(kerberos, courseCode, semesterCode))) {
            res.status(403).json({ error: 'not_enrolled' });
            return;
        }

        const { rows } = await db.query(
            `SELECT marking_scheme, attendance_policy, audit_withdrawal_policy, other_notes,
                    created_kerberos, created_name, created_at,
                    updated_kerberos, updated_name, updated_at
             FROM course_policies
             WHERE semester_code = $1 AND course_code = $2`,
            [semesterCode, courseCode],
        );

        res.json({
            semesterCode,
            courseCode,
            policy: rows.length ? rowToPolicy(rows[0]) : null,
        });
    } catch (e) {
        next(e);
    }
});

router.put('/courses/:courseCode/policy', requireSession, async (req, res, next) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    try {
        const courseCode = normalizeCourseCode(req.params.courseCode);
        if (!COURSE_CODE_RE.test(courseCode)) {
            res.status(400).json({ error: 'invalid_course_code' });
            return;
        }

        const semesterCode = await semesterData.resolveSemesterCode(
            (req.query.semester || '').trim() || undefined,
        );
        if (!semesterCode) {
            res.status(503).json({ error: 'semester_unavailable' });
            return;
        }

        const kerberos = semesterData.normalizeKerberos(req.session.kerberos);
        if (!kerberos || !(await assertEnrolled(kerberos, courseCode, semesterCode))) {
            res.status(403).json({ error: 'not_enrolled' });
            return;
        }

        const validated = validatePolicyBody(req.body);
        if (validated.error) {
            res.status(400).json({ error: validated.error });
            return;
        }

        const { markingScheme, attendancePolicy, auditWithdrawalPolicy, otherNotes } = validated.value;
        const actor = actorFromSession(req.session);

        const { rows: existing } = await db.query(
            `SELECT semester_code FROM course_policies
             WHERE semester_code = $1 AND course_code = $2`,
            [semesterCode, courseCode],
        );

        let rows;
        if (existing.length === 0) {
            const result = await db.query(
                `INSERT INTO course_policies (
                    semester_code, course_code,
                    marking_scheme, attendance_policy, audit_withdrawal_policy, other_notes,
                    created_kerberos, created_name, updated_kerberos, updated_name
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $7, $8)
                RETURNING marking_scheme, attendance_policy, audit_withdrawal_policy, other_notes,
                          created_kerberos, created_name, created_at,
                          updated_kerberos, updated_name, updated_at`,
                [
                    semesterCode,
                    courseCode,
                    markingScheme,
                    attendancePolicy,
                    auditWithdrawalPolicy,
                    otherNotes,
                    actor.kerberos,
                    actor.name,
                ],
            );
            rows = result.rows;
        } else {
            const result = await db.query(
                `UPDATE course_policies SET
                    marking_scheme = $3,
                    attendance_policy = $4,
                    audit_withdrawal_policy = $5,
                    other_notes = $6,
                    updated_kerberos = $7,
                    updated_name = $8,
                    updated_at = now()
                 WHERE semester_code = $1 AND course_code = $2
                 RETURNING marking_scheme, attendance_policy, audit_withdrawal_policy, other_notes,
                           created_kerberos, created_name, created_at,
                           updated_kerberos, updated_name, updated_at`,
                [
                    semesterCode,
                    courseCode,
                    markingScheme,
                    attendancePolicy,
                    auditWithdrawalPolicy,
                    otherNotes,
                    actor.kerberos,
                    actor.name,
                ],
            );
            rows = result.rows;
        }

        res.json({ policy: rowToPolicy(rows[0]) });
    } catch (e) {
        next(e);
    }
});

module.exports = router;
