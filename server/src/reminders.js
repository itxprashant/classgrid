'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');

const router = express.Router();

const KEY_RE = /^[a-zA-Z0-9|._:-]{1,256}$/;
const MAX_TITLE = 200;
const MAX_BODY = 500;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function kerberosFromSession(session) {
    return (session.kerberos || '').trim().toLowerCase();
}

function rowToReminder(row) {
    return {
        key: row.reminder_key,
        title: row.title,
        body: row.body,
        eventStart: row.event_start.toISOString(),
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString(),
    };
}

function parseEventStart(value) {
    if (value == null || value === '') return { error: 'invalid_event_start' };
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return { error: 'invalid_event_start' };
    return { value: d };
}

function validateReminderBody(body, { partial } = { partial: false }) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const out = {};

    if (!partial || body.key !== undefined) {
        const key = String(body.key || '').trim();
        if (!KEY_RE.test(key)) return { error: 'invalid_key' };
        out.key = key;
    }
    if (!partial || body.title !== undefined) {
        const title = String(body.title || '').trim();
        if (!title || title.length > MAX_TITLE) return { error: 'invalid_title' };
        out.title = title;
    }
    if (!partial || body.body !== undefined) {
        const text = String(body.body || '').trim();
        if (!text || text.length > MAX_BODY) return { error: 'invalid_body_text' };
        out.body = text;
    }
    if (!partial || body.eventStart !== undefined) {
        const parsed = parseEventStart(body.eventStart);
        if (parsed.error) return parsed;
        out.eventStart = parsed.value;
    }

    return { value: out };
}

async function purgeExpired(kerberos) {
    await db.query(
        `DELETE FROM user_reminders
         WHERE kerberos = $1 AND event_start <= now()`,
        [kerberos]
    );
}

router.get('/me/reminders', requireSession, async (req, res) => {
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
        await purgeExpired(kerberos);
        const result = await db.query(
            `SELECT reminder_key, title, body, event_start, created_at, updated_at
             FROM user_reminders
             WHERE kerberos = $1 AND event_start > now()
             ORDER BY event_start ASC`,
            [kerberos]
        );
        res.json({ reminders: result.rows.map(rowToReminder) });
    } catch (e) {
        console.error('[reminders] list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.post('/me/reminders', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    const parsed = validateReminderBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }
    const body = parsed.value;

    if (!body.eventStart || body.eventStart <= new Date()) {
        res.status(400).json({ error: 'event_in_past' });
        return;
    }

    try {
        const result = await db.query(
            `INSERT INTO user_reminders (kerberos, reminder_key, title, body, event_start, updated_at)
             VALUES ($1, $2, $3, $4, $5, now())
             ON CONFLICT (kerberos, reminder_key)
             DO UPDATE SET
                 title = EXCLUDED.title,
                 body = EXCLUDED.body,
                 event_start = EXCLUDED.event_start,
                 updated_at = now()
             RETURNING reminder_key, title, body, event_start, created_at, updated_at`,
            [kerberos, body.key, body.title, body.body, body.eventStart]
        );
        res.status(201).json({ reminder: rowToReminder(result.rows[0]) });
    } catch (e) {
        console.error('[reminders] upsert failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.put('/me/reminders', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    const raw = req.body && req.body.reminders;
    if (!Array.isArray(raw)) {
        res.status(400).json({ error: 'invalid_reminders' });
        return;
    }
    if (raw.length > 500) {
        res.status(400).json({ error: 'too_many_reminders' });
        return;
    }

    const now = new Date();
    const normalized = [];
    for (const item of raw) {
        const parsed = validateReminderBody(item);
        if (parsed.error) {
            res.status(400).json({ error: parsed.error });
            return;
        }
        const body = parsed.value;
        if (!body.eventStart || body.eventStart <= now) continue;
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
        await client.query('DELETE FROM user_reminders WHERE kerberos = $1', [kerberos]);
        for (const body of normalized) {
            await client.query(
                `INSERT INTO user_reminders (kerberos, reminder_key, title, body, event_start, updated_at)
                 VALUES ($1, $2, $3, $4, $5, now())`,
                [kerberos, body.key, body.title, body.body, body.eventStart]
            );
        }
        await client.query('COMMIT');

        const result = await db.query(
            `SELECT reminder_key, title, body, event_start, created_at, updated_at
             FROM user_reminders
             WHERE kerberos = $1 AND event_start > now()
             ORDER BY event_start ASC`,
            [kerberos]
        );
        res.json({ reminders: result.rows.map(rowToReminder) });
    } catch (e) {
        await client.query('ROLLBACK');
        console.error('[reminders] sync failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    } finally {
        client.release();
    }
});

router.delete('/me/reminders/:key', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = kerberosFromSession(req.session);
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    let key;
    try {
        key = decodeURIComponent(String(req.params.key || '').trim());
    } catch (_) {
        res.status(400).json({ error: 'invalid_key' });
        return;
    }
    if (!KEY_RE.test(key)) {
        res.status(400).json({ error: 'invalid_key' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM user_reminders
             WHERE kerberos = $1 AND reminder_key = $2
             RETURNING reminder_key`,
            [kerberos, key]
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        res.json({ ok: true, key: result.rows[0].reminder_key });
    } catch (e) {
        console.error('[reminders] delete failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
