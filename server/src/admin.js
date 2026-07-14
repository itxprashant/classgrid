'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireAdmin } = require('./adminAuth');
const semesterData = require('./semesterData');
const { recordAuditSafe, rowToAuditEntry } = require('./auditLog');

const router = express.Router();

const REPORT_STATUSES = new Set(['open', 'reviewed', 'dismissed', 'actioned']);
const FEEDBACK_CATEGORIES = new Set(['feature', 'improvement', 'bug', 'other']);
const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function clampInt(raw, fallback, min, max) {
    const n = Number.parseInt(String(raw ?? ''), 10);
    if (!Number.isFinite(n)) return fallback;
    return Math.min(max, Math.max(min, n));
}

function rowToFeedback(row) {
    return {
        id: row.id,
        kerberos: row.kerberos || null,
        reporterName: row.reporter_name || null,
        reporterEmail: row.reporter_email || null,
        message: row.message,
        category: row.category,
        pageContext: row.page_context || null,
        client: row.client,
        createdAt: row.created_at.toISOString(),
    };
}

function rowToReport(row) {
    return {
        id: row.id,
        reporterKerberos: row.reporter_kerberos,
        reporterName: row.reporter_name,
        targetKind: row.target_kind,
        targetId: row.target_id,
        targetSnapshot: row.target_snapshot || {},
        reason: row.reason,
        details: row.details || '',
        status: row.status,
        reviewedByKerberos: row.reviewed_by_kerberos || null,
        reviewedAt: row.reviewed_at ? row.reviewed_at.toISOString() : null,
        createdAt: row.created_at.toISOString(),
    };
}

router.use(requireAdmin);

router.get('/me', (req, res) => {
    res.json({ ok: true, kerberos: req.adminKerberos });
});

router.get('/summary', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    try {
        const [health, explorer, feedbackCounts, openReports] = await Promise.all([
            semesterData.getHealthStats(),
            semesterData.loadCatalogExplorer(),
            db.query(
                `SELECT
                    COUNT(*)::int AS total,
                    COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours')::int AS last24h,
                    COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::int AS last7d
                 FROM app_feedback`,
            ),
            db.query(
                `SELECT COUNT(*)::int AS open_count FROM content_reports WHERE status = 'open'`,
            ),
        ]);

        res.json({
            health: {
                activeSemester: health.activeSemester,
                catalogCount: health.catalogCount,
                enrolledStudents: health.enrolledStudents,
                semesterDataLoaded: semesterData.isCacheReady(),
            },
            explorer: {
                semesterCode: explorer.semesterCode,
                count: explorer.count,
                offeredCount: explorer.offeredCount,
            },
            feedback: feedbackCounts.rows[0],
            reports: {
                open: openReports.rows[0].open_count,
            },
        });
    } catch (e) {
        console.error('[admin] summary failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.get('/feedback', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const limit = clampInt(req.query.limit, 50, 1, 100);
    const offset = clampInt(req.query.offset, 0, 0, 100000);
    const category = String(req.query.category || '').trim().toLowerCase();

    const params = [limit, offset];
    let where = '';
    if (category && FEEDBACK_CATEGORIES.has(category)) {
        where = ' WHERE category = $3';
        params.push(category);
    }

    try {
        const [list, count] = await Promise.all([
            db.query(
                `SELECT id, kerberos, reporter_name, reporter_email, message, category,
                        page_context, client, created_at
                 FROM app_feedback
                 ${where}
                 ORDER BY created_at DESC
                 LIMIT $1 OFFSET $2`,
                params,
            ),
            db.query(
                `SELECT COUNT(*)::int AS total FROM app_feedback${where}`,
                where ? [category] : [],
            ),
        ]);

        res.json({
            items: list.rows.map(rowToFeedback),
            total: count.rows[0].total,
            limit,
            offset,
        });
    } catch (e) {
        console.error('[admin] feedback list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.get('/reports', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const limit = clampInt(req.query.limit, 50, 1, 100);
    const offset = clampInt(req.query.offset, 0, 0, 100000);
    const status = String(req.query.status || 'open').trim().toLowerCase();
    const statusFilter = REPORT_STATUSES.has(status) ? status : 'open';

    try {
        const [list, count] = await Promise.all([
            db.query(
                `SELECT id, reporter_kerberos, reporter_name, target_kind, target_id,
                        target_snapshot, reason, details, status,
                        reviewed_by_kerberos, reviewed_at, created_at
                 FROM content_reports
                 WHERE status = $3
                 ORDER BY created_at DESC
                 LIMIT $1 OFFSET $2`,
                [limit, offset, statusFilter],
            ),
            db.query(
                `SELECT COUNT(*)::int AS total FROM content_reports WHERE status = $1`,
                [statusFilter],
            ),
        ]);

        res.json({
            items: list.rows.map(rowToReport),
            total: count.rows[0].total,
            limit,
            offset,
            status: statusFilter,
        });
    } catch (e) {
        console.error('[admin] reports list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.get('/audit-log', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const limit = clampInt(req.query.limit, 50, 1, 100);
    const offset = clampInt(req.query.offset, 0, 0, 100000);
    const action = String(req.query.action || '').trim();
    const targetKind = String(req.query.targetKind || '').trim();
    const since = String(req.query.since || '').trim();
    const actorRaw = req.query.actorKerberos;
    const actorKerberos = actorRaw != null && actorRaw !== ''
        ? String(actorRaw).trim().toLowerCase()
        : '';

    const conditions = [];
    const params = [];
    let i = 1;

    if (action) {
        conditions.push(`action = $${i++}`);
        params.push(action);
    }
    if (targetKind) {
        conditions.push(`target_kind = $${i++}`);
        params.push(targetKind);
    }
    if (since) {
        if (!DATE_RE.test(since)) {
            res.status(400).json({ error: 'invalid_since' });
            return;
        }
        conditions.push(`occurred_at >= $${i++}::date`);
        params.push(since);
    }
    if (actorRaw != null && actorRaw !== '') {
        if (!actorKerberos) {
            res.status(400).json({ error: 'invalid_actor' });
            return;
        }
        conditions.push(`actor_kerberos = $${i++}`);
        params.push(actorKerberos);
    }

    const where = conditions.length ? ` WHERE ${conditions.join(' AND ')}` : '';
    const listParams = [...params, limit, offset];
    const limitParam = i++;
    const offsetParam = i;

    try {
        const [list, count] = await Promise.all([
            db.query(
                `SELECT id, occurred_at, action, actor_kerberos, actor_name,
                        target_kind, target_id, metadata, client, ip
                 FROM app_audit_log
                 ${where}
                 ORDER BY occurred_at DESC
                 LIMIT $${limitParam} OFFSET $${offsetParam}`,
                listParams,
            ),
            db.query(
                `SELECT COUNT(*)::int AS total FROM app_audit_log${where}`,
                params,
            ),
        ]);

        res.json({
            entries: list.rows.map(rowToAuditEntry),
            total: count.rows[0].total,
            limit,
            offset,
        });
    } catch (e) {
        console.error('[admin] audit-log list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.patch('/reports/:id', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const id = String(req.params.id || '').trim();
    if (!UUID_RE.test(id)) {
        res.status(400).json({ error: 'invalid_id' });
        return;
    }

    const status = String(req.body?.status || '').trim().toLowerCase();
    if (!REPORT_STATUSES.has(status)) {
        res.status(400).json({ error: 'invalid_status' });
        return;
    }

    try {
        const prior = await db.query(
            'SELECT status FROM content_reports WHERE id = $1::uuid',
            [id],
        );
        if (prior.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const fromStatus = prior.rows[0].status;

        const result = await db.query(
            `UPDATE content_reports
             SET status = $2,
                 reviewed_by_kerberos = $3,
                 reviewed_at = now()
             WHERE id = $1::uuid
             RETURNING id, reporter_kerberos, reporter_name, target_kind, target_id,
                       target_snapshot, reason, details, status,
                       reviewed_by_kerberos, reviewed_at, created_at`,
            [id, status, req.adminKerberos],
        );
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'admin.report.reviewed',
            targetKind: 'content_report',
            targetId: row.id,
            metadata: {
                fromStatus,
                toStatus: status,
                targetKind: row.target_kind,
                targetId: row.target_id,
            },
        });
        res.json({ report: rowToReport(row) });
    } catch (e) {
        console.error('[admin] report patch failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/content/course-events/:id', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const id = String(req.params.id || '').trim();
    if (!UUID_RE.test(id)) {
        res.status(400).json({ error: 'invalid_id' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM course_events WHERE id = $1::uuid
             RETURNING id, course_code, event_date, title, type`,
            [id],
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'admin.course_event.deleted',
            targetKind: 'course_event',
            targetId: row.id,
            metadata: {
                id: row.id,
                courseCode: row.course_code,
                title: row.title,
                type: row.type,
            },
        });
        res.json({ ok: true, id: row.id });
    } catch (e) {
        console.error('[admin] delete course event failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/content/occupied-rooms/:id', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const id = String(req.params.id || '').trim();
    if (!UUID_RE.test(id)) {
        res.status(400).json({ error: 'invalid_id' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM occupied_rooms WHERE id = $1::uuid
             RETURNING id, room_name, occupancy_date, start_hhmm, end_hhmm`,
            [id],
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'admin.occupied_room.deleted',
            targetKind: 'occupied_room',
            targetId: row.id,
            metadata: {
                id: row.id,
                room: row.room_name,
                start: row.start_hhmm,
                end: row.end_hhmm,
            },
        });
        res.json({ ok: true, id: row.id });
    } catch (e) {
        console.error('[admin] delete occupied room failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/content/course-policies/:semester/:courseCode', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const semesterCode = String(req.params.semester || '').trim();
    const courseCode = semesterData.normalizeCourseCode(req.params.courseCode);
    if (!semesterCode || !COURSE_CODE_RE.test(courseCode)) {
        res.status(400).json({ error: 'invalid_target' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM course_policies
             WHERE semester_code = $1 AND course_code = $2
             RETURNING semester_code, course_code`,
            [semesterCode, courseCode],
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'admin.course_policy.deleted',
            targetKind: 'course_policy',
            targetId: `${row.semester_code}:${row.course_code}`,
            metadata: {
                semesterCode: row.semester_code,
                courseCode: row.course_code,
            },
        });
        res.json({
            ok: true,
            semesterCode: row.semester_code,
            courseCode: row.course_code,
        });
    } catch (e) {
        console.error('[admin] delete course policy failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

const PUSH_AUDIENCES = new Set(['all', 'signed_in']);
const PUSH_TITLE_MAX = 120;
const PUSH_BODY_MAX = 500;

router.post('/push', async (req, res) => {
    const { isFcmConfigured, sendBroadcast } = require('./firebaseAdmin');

    if (!isFcmConfigured()) {
        res.status(503).json({ error: 'fcm_unconfigured' });
        return;
    }

    const title = String((req.body && req.body.title) || '').trim();
    const body = String((req.body && req.body.body) || '').trim();
    const audience = String((req.body && req.body.audience) || '').trim().toLowerCase();

    if (!title || title.length > PUSH_TITLE_MAX) {
        res.status(400).json({ error: 'invalid_title' });
        return;
    }
    if (!body || body.length > PUSH_BODY_MAX) {
        res.status(400).json({ error: 'invalid_body' });
        return;
    }
    if (!PUSH_AUDIENCES.has(audience)) {
        res.status(400).json({ error: 'invalid_audience' });
        return;
    }

    if (audience === 'signed_in' && !config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    try {
        const { successCount, failureCount } = await sendBroadcast({
            title,
            body,
            audience,
        });
        recordAuditSafe({
            req,
            action: 'admin.push_sent',
            targetKind: 'fcm_broadcast',
            targetId: audience,
            metadata: {
                audience,
                title,
                bodyLength: body.length,
                successCount,
                failureCount,
            },
        });
        res.json({
            ok: true,
            audience,
            successCount,
            failureCount,
        });
    } catch (e) {
        if (e.message === 'fcm_unconfigured') {
            res.status(503).json({ error: 'fcm_unconfigured' });
            return;
        }
        if (e.message === 'database_unavailable') {
            dbUnavailable(res);
            return;
        }
        console.error('[admin] push failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
