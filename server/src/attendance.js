'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');

const router = express.Router();

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const COURSE_RE = /^[A-Z]{2,4}\d{2,4}[A-Z]?$/i;
const KINDS = new Set(['lecture', 'tutorial', 'lab']);
const STATUSES = new Set(['present', 'absent', 'excused']);
const MAX_BUCKETS = 48;
const MAX_BY_DATE_KEYS = 500;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function kerberosFromSession(session) {
    return (session.kerberos || '').trim().toLowerCase();
}

function rowToBucket(row) {
    return {
        courseCode: row.course_code,
        sessionKind: row.session_kind,
        present: row.present,
        absent: row.absent,
        excused: row.excused,
        byDate: row.by_date || {},
        updatedAt: row.updated_at.toISOString(),
    };
}

function normalizeCourseCode(value) {
    const code = String(value || '').trim().toUpperCase();
    if (!COURSE_RE.test(code)) return null;
    return code;
}

function normalizeSessionKind(value) {
    const kind = String(value || '').trim().toLowerCase();
    if (!KINDS.has(kind)) return null;
    return kind;
}

function normalizeDate(value) {
    const date = String(value || '').trim();
    if (!DATE_RE.test(date)) return null;
    return date;
}

function normalizeStatus(value) {
    if (value == null) return null;
    const status = String(value).trim().toLowerCase();
    if (!STATUSES.has(status)) return { error: 'invalid_status' };
    return { value: status };
}

function validateByDateMap(raw) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
        return { error: 'invalid_by_date' };
    }
    const keys = Object.keys(raw);
    if (keys.length > MAX_BY_DATE_KEYS) return { error: 'too_many_dates' };

    const out = {};
    for (const key of keys) {
        if (!DATE_RE.test(key)) return { error: 'invalid_date' };
        const status = normalizeStatus(raw[key]);
        if (status.error) return status;
        out[key] = status.value;
    }
    return { value: out };
}

function validateBucketBody(body, { partial } = { partial: false }) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const out = {};

    if (!partial || body.courseCode !== undefined) {
        const courseCode = normalizeCourseCode(body.courseCode);
        if (!courseCode) return { error: 'invalid_course_code' };
        out.courseCode = courseCode;
    }
    if (!partial || body.sessionKind !== undefined) {
        const sessionKind = normalizeSessionKind(body.sessionKind);
        if (!sessionKind) return { error: 'invalid_session_kind' };
        out.sessionKind = sessionKind;
    }
    if (!partial || body.present !== undefined) {
        const present = Number(body.present);
        if (!Number.isInteger(present) || present < 0) return { error: 'invalid_present' };
        out.present = present;
    }
    if (!partial || body.absent !== undefined) {
        const absent = Number(body.absent);
        if (!Number.isInteger(absent) || absent < 0) return { error: 'invalid_absent' };
        out.absent = absent;
    }
    if (!partial || body.excused !== undefined) {
        const excused = Number(body.excused);
        if (!Number.isInteger(excused) || excused < 0) return { error: 'invalid_excused' };
        out.excused = excused;
    }
    if (!partial || body.byDate !== undefined) {
        const parsed = validateByDateMap(body.byDate);
        if (parsed.error) return parsed;
        out.byDate = parsed.value;
    }

    return { value: out };
}

function applyMarkTransition(row, date, newStatus) {
    const byDate = { ...(row.by_date || {}) };
    let present = row.present;
    let absent = row.absent;
    let excused = row.excused;

    const oldStatus = byDate[date];
    if (oldStatus && STATUSES.has(oldStatus)) {
        if (oldStatus === 'present') present = Math.max(0, present - 1);
        if (oldStatus === 'absent') absent = Math.max(0, absent - 1);
        if (oldStatus === 'excused') excused = Math.max(0, excused - 1);
        delete byDate[date];
    }

    if (newStatus) {
        if (newStatus === 'present') present += 1;
        if (newStatus === 'absent') absent += 1;
        if (newStatus === 'excused') excused += 1;
        byDate[date] = newStatus;
    }

    return { present, absent, excused, byDate };
}

router.get('/me/attendance', requireSession, async (req, res) => {
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
            `SELECT course_code, session_kind, present, absent, excused, by_date, updated_at
             FROM user_course_attendance
             WHERE kerberos = $1
             ORDER BY course_code ASC, session_kind ASC`,
            [kerberos]
        );
        res.json({ buckets: result.rows.map(rowToBucket) });
    } catch (e) {
        console.error('[attendance] list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.put('/me/attendance', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    const raw = req.body && req.body.buckets;
    if (!Array.isArray(raw)) {
        res.status(400).json({ error: 'invalid_buckets' });
        return;
    }
    if (raw.length > MAX_BUCKETS) {
        res.status(400).json({ error: 'too_many_buckets' });
        return;
    }

    const normalized = [];
    const seen = new Set();
    for (const item of raw) {
        const parsed = validateBucketBody(item);
        if (parsed.error) {
            res.status(400).json({ error: parsed.error });
            return;
        }
        const body = parsed.value;
        const key = `${body.courseCode}|${body.sessionKind}`;
        if (seen.has(key)) {
            res.status(400).json({ error: 'duplicate_bucket' });
            return;
        }
        seen.add(key);
        normalized.push(body);
    }

    const pool = db.getPool();
    if (!pool) {
        dbUnavailable(res);
        return;
    }
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query('DELETE FROM user_course_attendance WHERE kerberos = $1', [kerberos]);
        for (const body of normalized) {
            await client.query(
                `INSERT INTO user_course_attendance
                    (kerberos, course_code, session_kind, present, absent, excused, by_date, updated_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, now())`,
                [
                    kerberos,
                    body.courseCode,
                    body.sessionKind,
                    body.present ?? 0,
                    body.absent ?? 0,
                    body.excused ?? 0,
                    JSON.stringify(body.byDate ?? {}),
                ]
            );
        }
        await client.query('COMMIT');

        const result = await db.query(
            `SELECT course_code, session_kind, present, absent, excused, by_date, updated_at
             FROM user_course_attendance
             WHERE kerberos = $1
             ORDER BY course_code ASC, session_kind ASC`,
            [kerberos]
        );
        res.json({ buckets: result.rows.map(rowToBucket) });
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('[attendance] sync failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    } finally {
        client.release();
    }
});

router.patch('/me/attendance', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    const courseCode = normalizeCourseCode(req.body && req.body.courseCode);
    const sessionKind = normalizeSessionKind(req.body && req.body.sessionKind);
    const date = normalizeDate(req.body && req.body.date);
    if (!courseCode || !sessionKind || !date) {
        res.status(400).json({ error: 'invalid_mark' });
        return;
    }

    let newStatus = null;
    if (req.body && req.body.status != null && req.body.status !== '') {
        const parsed = normalizeStatus(req.body.status);
        if (parsed.error) {
            res.status(400).json({ error: parsed.error });
            return;
        }
        newStatus = parsed.value;
    }

    try {
        const existing = await db.query(
            `SELECT present, absent, excused, by_date
             FROM user_course_attendance
             WHERE kerberos = $1 AND course_code = $2 AND session_kind = $3`,
            [kerberos, courseCode, sessionKind]
        );

        const base = existing.rowCount > 0
            ? existing.rows[0]
            : { present: 0, absent: 0, excused: 0, by_date: {} };

        const next = applyMarkTransition(base, date, newStatus);

        const result = await db.query(
            `INSERT INTO user_course_attendance
                (kerberos, course_code, session_kind, present, absent, excused, by_date, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, now())
             ON CONFLICT (kerberos, course_code, session_kind)
             DO UPDATE SET
                 present = EXCLUDED.present,
                 absent = EXCLUDED.absent,
                 excused = EXCLUDED.excused,
                 by_date = EXCLUDED.by_date,
                 updated_at = now()
             RETURNING course_code, session_kind, present, absent, excused, by_date, updated_at`,
            [
                kerberos,
                courseCode,
                sessionKind,
                next.present,
                next.absent,
                next.excused,
                JSON.stringify(next.byDate),
            ]
        );

        res.json({ bucket: rowToBucket(result.rows[0]) });
    } catch (e) {
        console.error('[attendance] patch failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
