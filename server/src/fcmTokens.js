'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { readSession, requireSession } = require('./session');

const router = express.Router();

const FCM_TOKEN_MIN = 80;
const FCM_TOKEN_MAX = 4096;
const FCM_TOKEN_RE = /^[A-Za-z0-9_:\-]+$/;
const PLATFORMS = new Set(['android']);

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function optionalSession(req, res, next) {
    const session = readSession(req);
    if (session) req.session = session;
    next();
}

function normalizeKerberos(session) {
    if (!session || !session.kerberos) return null;
    const k = String(session.kerberos).trim().toLowerCase();
    return k || null;
}

function validateToken(raw) {
    const token = String(raw || '').trim();
    if (token.length < FCM_TOKEN_MIN || token.length > FCM_TOKEN_MAX) {
        return null;
    }
    if (!FCM_TOKEN_RE.test(token)) {
        return null;
    }
    return token;
}

router.post('/me/fcm-token', optionalSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const token = validateToken(req.body && req.body.token);
    if (!token) {
        res.status(400).json({ error: 'invalid_token' });
        return;
    }

    const platform = String((req.body && req.body.platform) || 'android').trim().toLowerCase();
    if (!PLATFORMS.has(platform)) {
        res.status(400).json({ error: 'invalid_platform' });
        return;
    }

    const kerberos = normalizeKerberos(req.session);

    try {
        await db.query(
            `INSERT INTO user_fcm_tokens (fcm_token, kerberos, platform, updated_at)
             VALUES ($1, $2, $3, now())
             ON CONFLICT (fcm_token) DO UPDATE SET
                kerberos = EXCLUDED.kerberos,
                platform = EXCLUDED.platform,
                updated_at = now()`,
            [token, kerberos, platform],
        );
        res.json({ ok: true, kerberos: kerberos || null });
    } catch (e) {
        console.error('[fcm-token] upsert failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/me/fcm-token', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const token = validateToken(req.body && req.body.token);
    if (!token) {
        res.status(400).json({ error: 'invalid_token' });
        return;
    }

    const kerberos = normalizeKerberos(req.session);

    try {
        const result = await db.query(
            `DELETE FROM user_fcm_tokens
             WHERE fcm_token = $1 AND (kerberos IS NULL OR kerberos = $2)`,
            [token, kerberos],
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        res.json({ ok: true });
    } catch (e) {
        console.error('[fcm-token] delete failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
