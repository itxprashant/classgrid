'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { readSession } = require('./session');
const semesterData = require('./semesterData');
const { auditActorFromSession, recordAuditSafe } = require('./auditLog');

const router = express.Router();

const FEEDBACK_CATEGORIES = new Set(['feature', 'improvement', 'bug', 'other']);
const FEEDBACK_CLIENTS = new Set(['web', 'android']);
const MIN_MESSAGE_LEN = 10;
const MAX_MESSAGE_LEN = 4000;
const MAX_PAGE_CONTEXT_LEN = 256;
const KERBEROS_HOURLY_LIMIT = 10;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function normalizeCategory(raw) {
    const c = String(raw || 'feature').trim().toLowerCase();
    return FEEDBACK_CATEGORIES.has(c) ? c : 'feature';
}

function normalizeClient(raw) {
    const c = String(raw || 'web').trim().toLowerCase();
    return FEEDBACK_CLIENTS.has(c) ? c : 'web';
}

function validateFeedbackBody(body) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const message = String(body.message || '').trim();
    if (message.length < MIN_MESSAGE_LEN) return { error: 'message_too_short' };
    if (message.length > MAX_MESSAGE_LEN) return { error: 'message_too_long' };

    let pageContext = null;
    if (body.pageContext != null && body.pageContext !== '') {
        pageContext = String(body.pageContext).trim().slice(0, MAX_PAGE_CONTEXT_LEN) || null;
    }

    return {
        value: {
            message,
            category: normalizeCategory(body.category),
            pageContext,
            client: normalizeClient(body.client),
        },
    };
}

router.post('/feedback', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const parsed = validateFeedbackBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }

    const session = readSession(req);
    const { message, category, pageContext, client } = parsed.value;

    let kerberos = null;
    let reporterName = null;
    let reporterEmail = null;

    if (session) {
        kerberos = semesterData.normalizeKerberos(session.kerberos);
        reporterName = (session.name || session.kerberos || 'Unknown').trim();
        reporterEmail = session.email ? String(session.email).trim().toLowerCase() : null;

        if (kerberos) {
            try {
                const recent = await db.query(
                    `SELECT COUNT(*)::int AS n
                     FROM app_feedback
                     WHERE kerberos = $1 AND created_at > now() - interval '1 hour'`,
                    [kerberos],
                );
                if (recent.rows[0].n >= KERBEROS_HOURLY_LIMIT) {
                    res.status(429).json({ error: 'rate_limited' });
                    return;
                }
            } catch (e) {
                console.error('[feedback] rate check failed:', e.message);
                res.status(500).json({ error: 'internal_error' });
                return;
            }
        }
    }

    try {
        const result = await db.query(
            `INSERT INTO app_feedback (
                kerberos, reporter_name, reporter_email,
                message, category, page_context, client
             ) VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, created_at`,
            [kerberos, reporterName, reporterEmail, message, category, pageContext, client],
        );
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'feedback.submitted',
            targetKind: 'app_feedback',
            targetId: row.id,
            metadata: {
                id: row.id,
                category,
                client,
                messagePreview: message.slice(0, 200),
            },
            actor: auditActorFromSession(session),
            client,
        });
        res.status(201).json({
            id: row.id,
            createdAt: row.created_at.toISOString(),
        });
    } catch (e) {
        console.error('[feedback] create failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
