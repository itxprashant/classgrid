'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession, readSession } = require('./session');
const { recordAuditSafe } = require('./auditLog');

const router = express.Router();

const EVENT_TYPES = new Set([
    'quiz', 'deadline', 'exam', 'extra-class', 'presentation', 'others',
]);

const EVENT_SCHEDULES = new Set(['fullday', 'at', 'timed', 'eod']);

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const HHMM_RE = /^[0-2][0-9][0-5][0-9]$/;

function pgDateToKey(val) {
    if (!val) return '';
    if (typeof val === 'string') return val.slice(0, 10);
    const y = val.getUTCFullYear();
    const m = String(val.getUTCMonth() + 1).padStart(2, '0');
    const d = String(val.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function rowToEvent(row) {
    const event = {
        id: row.id,
        date: pgDateToKey(row.event_date),
        courseCode: row.course_code,
        title: row.title,
        type: row.type,
        schedule: row.schedule,
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
    if (row.time_hhmm) event.time = row.time_hhmm;
    if (row.start_hhmm) event.start = row.start_hhmm;
    if (row.end_hhmm) event.end = row.end_hhmm;
    if (row.note) event.note = row.note;
    return event;
}

function normalizeCourseCode(code) {
    return String(code || '').trim().toUpperCase();
}

function normalizeHHMM(value) {
    if (value == null || value === '') return null;
    const s = String(value).trim();
    const colon = s.match(/^(\d{2}):(\d{2})$/);
    if (colon) return `${colon[1]}${colon[2]}`;
    if (HHMM_RE.test(s)) return s;
    return null;
}

function parseCourseList(raw) {
    if (!raw || typeof raw !== 'string') return [];
    return [...new Set(
        raw.split(',')
            .map((c) => normalizeCourseCode(c))
            .filter(Boolean)
    )];
}

function scheduleColumns(body) {
    const schedule = EVENT_SCHEDULES.has(body.schedule) ? body.schedule : 'fullday';
    if (schedule === 'at') {
        const time = normalizeHHMM(body.time);
        if (!time) return { error: 'invalid_schedule' };
        return { schedule, time_hhmm: time, start_hhmm: null, end_hhmm: null };
    }
    if (schedule === 'timed') {
        const start = normalizeHHMM(body.start);
        const end = normalizeHHMM(body.end);
        if (!start || !end || start >= end) return { error: 'invalid_schedule' };
        return { schedule, time_hhmm: null, start_hhmm: start, end_hhmm: end };
    }
    return { schedule, time_hhmm: null, start_hhmm: null, end_hhmm: null };
}

function validateEventBody(body, { partial } = { partial: false }) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const out = {};

    if (!partial || body.date !== undefined) {
        if (!DATE_RE.test(body.date || '')) return { error: 'invalid_date' };
        out.date = body.date;
    }
    if (!partial || body.courseCode !== undefined) {
        const courseCode = normalizeCourseCode(body.courseCode);
        if (!courseCode) return { error: 'invalid_course' };
        out.courseCode = courseCode;
    }
    if (!partial || body.title !== undefined) {
        const title = String(body.title || '').trim();
        if (!title) return { error: 'invalid_title' };
        out.title = title;
    }
    if (!partial || body.type !== undefined) {
        const type = body.type === 'other' ? 'others' : body.type;
        if (!EVENT_TYPES.has(type)) return { error: 'invalid_type' };
        out.type = type;
    }
    if (!partial || body.note !== undefined) {
        const note = String(body.note || '').trim();
        out.note = note.length ? note : null;
    }
    if (!partial || body.schedule !== undefined || body.time !== undefined ||
        body.start !== undefined || body.end !== undefined) {
        const sched = scheduleColumns(body);
        if (sched.error) return sched;
        Object.assign(out, sched);
    }

    return { value: out };
}

function actorFromSession(session) {
    return {
        kerberos: session.kerberos ? String(session.kerberos).trim().toLowerCase() : null,
        name: (session.name || session.kerberos || 'Unknown').trim(),
    };
}

function auditMetaFromRow(row) {
    return {
        id: row.id,
        courseCode: row.course_code,
        title: row.title,
        type: row.type,
        date: pgDateToKey(row.event_date),
    };
}

function dbUnavailable(req, res) {
    res.status(503).json({ error: 'database_unavailable' });
}

router.get('/events', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    const from = String(req.query.from || '').trim();
    const to = String(req.query.to || '').trim();
    if (!DATE_RE.test(from) || !DATE_RE.test(to) || from > to) {
        res.status(400).json({ error: 'invalid_range' });
        return;
    }

    let courses = parseCourseList(req.query.courses);
    const session = readSession(req);
    if (session && session.kerberos) {
        const coursesRouter = require('./courses');
        const enrolled = (await coursesRouter.getEnrolledCourses(session.kerberos))
            .map(normalizeCourseCode);
        courses = [...new Set([...courses, ...enrolled])];
    }

    if (courses.length === 0) {
        res.json({ events: [] });
        return;
    }

    try {
        const result = await db.query(
            `SELECT id, course_code, event_date, title, type, schedule,
                    time_hhmm, start_hhmm, end_hhmm, note,
                    created_kerberos, created_name, created_at,
                    updated_kerberos, updated_name, updated_at
             FROM course_events
             WHERE event_date >= $1::date
               AND event_date <= $2::date
               AND course_code = ANY($3::text[])
             ORDER BY event_date ASC, course_code ASC,
                      COALESCE(start_hhmm, time_hhmm, '0000') ASC`,
            [from, to, courses]
        );
        res.json({ events: result.rows.map(rowToEvent) });
    } catch (e) {
        console.error('[calendar] list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.post('/events', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    const parsed = validateEventBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }
    const body = parsed.value;
    const actor = actorFromSession(req.session);

    try {
        const result = await db.query(
            `INSERT INTO course_events (
                course_code, event_date, title, type, schedule,
                time_hhmm, start_hhmm, end_hhmm, note,
                created_kerberos, created_name, updated_kerberos, updated_name
             ) VALUES (
                $1, $2::date, $3, $4, $5,
                $6, $7, $8, $9,
                $10, $11, $10, $11
             )
             RETURNING id, course_code, event_date, title, type, schedule,
                       time_hhmm, start_hhmm, end_hhmm, note,
                       created_kerberos, created_name, created_at,
                       updated_kerberos, updated_name, updated_at`,
            [
                body.courseCode,
                body.date,
                body.title,
                body.type,
                body.schedule,
                body.time_hhmm,
                body.start_hhmm,
                body.end_hhmm,
                body.note,
                actor.kerberos,
                actor.name,
            ]
        );
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'course_event.created',
            targetKind: 'course_event',
            targetId: row.id,
            metadata: auditMetaFromRow(row),
        });
        res.status(201).json({ event: rowToEvent(row) });
    } catch (e) {
        console.error('[calendar] create failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.patch('/events/:id', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    const id = String(req.params.id || '').trim();
    if (!id) {
        res.status(400).json({ error: 'invalid_id' });
        return;
    }

    const parsed = validateEventBody(req.body, { partial: true });
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }
    const body = parsed.value;
    if (Object.keys(body).length === 0) {
        res.status(400).json({ error: 'empty_patch' });
        return;
    }

    const actor = actorFromSession(req.session);
    const sets = [];
    const values = [];
    let i = 1;

    if (body.courseCode !== undefined) {
        sets.push(`course_code = $${i++}`);
        values.push(body.courseCode);
    }
    if (body.date !== undefined) {
        sets.push(`event_date = $${i++}::date`);
        values.push(body.date);
    }
    if (body.title !== undefined) {
        sets.push(`title = $${i++}`);
        values.push(body.title);
    }
    if (body.type !== undefined) {
        sets.push(`type = $${i++}`);
        values.push(body.type);
    }
    if (body.note !== undefined) {
        sets.push(`note = $${i++}`);
        values.push(body.note);
    }
    if (body.schedule !== undefined) {
        sets.push(`schedule = $${i++}`);
        values.push(body.schedule);
        sets.push(`time_hhmm = $${i++}`);
        values.push(body.time_hhmm);
        sets.push(`start_hhmm = $${i++}`);
        values.push(body.start_hhmm);
        sets.push(`end_hhmm = $${i++}`);
        values.push(body.end_hhmm);
    }

    sets.push(`updated_kerberos = $${i++}`);
    values.push(actor.kerberos);
    sets.push(`updated_name = $${i++}`);
    values.push(actor.name);
    sets.push('updated_at = now()');

    const idParam = i;
    values.push(id);

    try {
        const result = await db.query(
            `UPDATE course_events SET ${sets.join(', ')}
             WHERE id = $${idParam}::uuid
             RETURNING id, course_code, event_date, title, type, schedule,
                       time_hhmm, start_hhmm, end_hhmm, note,
                       created_kerberos, created_name, created_at,
                       updated_kerberos, updated_name, updated_at`,
            values
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'course_event.updated',
            targetKind: 'course_event',
            targetId: row.id,
            metadata: auditMetaFromRow(row),
        });
        res.json({ event: rowToEvent(row) });
    } catch (e) {
        console.error('[calendar] update failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/events/:id', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(req, res);
        return;
    }

    const id = String(req.params.id || '').trim();
    if (!id) {
        res.status(400).json({ error: 'invalid_id' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM course_events WHERE id = $1::uuid
             RETURNING id, course_code, event_date, title, type`,
            [id]
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'course_event.deleted',
            targetKind: 'course_event',
            targetId: row.id,
            metadata: auditMetaFromRow(row),
        });
        res.json({ ok: true, id: row.id });
    } catch (e) {
        console.error('[calendar] delete failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
