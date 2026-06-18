'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');
const semesterData = require('./semesterData');

const router = express.Router();

const TARGET_KINDS = new Set(['course_event', 'course_policy', 'occupied_room', 'other']);
const REPORT_REASONS = new Set(['spam', 'wrong_info', 'offensive', 'duplicate', 'other']);
const COURSE_CODE_RE = /^[A-Za-z0-9]{2,16}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_DETAILS_LEN = 2000;
const MAX_OTHER_ID_LEN = 128;
const MAX_OTHER_LABEL_LEN = 256;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function actorFromSession(session) {
    return {
        kerberos: semesterData.normalizeKerberos(session.kerberos),
        name: (session.name || session.kerberos || 'Unknown').trim(),
    };
}

function pgDateToKey(val) {
    if (!val) return '';
    if (typeof val === 'string') return val.slice(0, 10);
    const y = val.getUTCFullYear();
    const m = String(val.getUTCMonth() + 1).padStart(2, '0');
    const d = String(val.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function normalizeCourseCode(code) {
    return semesterData.normalizeCourseCode(code);
}

function validateReportBody(body) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const targetKind = String(body.targetKind || '').trim().toLowerCase();
    if (!TARGET_KINDS.has(targetKind)) return { error: 'invalid_target_kind' };

    const targetId = String(body.targetId || '').trim();
    if (!targetId || targetId.length > 128) return { error: 'invalid_target_id' };

    const reason = String(body.reason || '').trim().toLowerCase();
    if (!REPORT_REASONS.has(reason)) return { error: 'invalid_reason' };

    const details = String(body.details || '').trim().slice(0, MAX_DETAILS_LEN);

    let pageContext = null;
    let label = null;
    if (targetKind === 'other') {
        if (body.pageContext != null && body.pageContext !== '') {
            pageContext = String(body.pageContext).trim().slice(0, 256) || null;
        }
        if (body.label != null && body.label !== '') {
            label = String(body.label).trim().slice(0, MAX_OTHER_LABEL_LEN) || null;
        }
    }

    return {
        value: {
            targetKind,
            targetId: targetKind === 'other'
                ? targetId.slice(0, MAX_OTHER_ID_LEN)
                : targetId,
            reason,
            details,
            pageContext,
            label,
        },
    };
}

async function snapshotCourseEvent(id) {
    const result = await db.query(
        `SELECT id, course_code, event_date, title, type, schedule,
                time_hhmm, start_hhmm, end_hhmm, note,
                created_kerberos, created_name, created_at,
                updated_kerberos, updated_name, updated_at
         FROM course_events WHERE id = $1::uuid`,
        [id],
    );
    if (result.rowCount === 0) return null;
    const row = result.rows[0];
    return {
        kind: 'course_event',
        id: row.id,
        courseCode: row.course_code,
        date: pgDateToKey(row.event_date),
        title: row.title,
        type: row.type,
        schedule: row.schedule,
        time: row.time_hhmm || undefined,
        start: row.start_hhmm || undefined,
        end: row.end_hhmm || undefined,
        note: row.note || undefined,
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

async function snapshotCoursePolicy(targetId) {
    let semesterCode;
    let courseCode;

    if (targetId.includes(':')) {
        const parts = targetId.split(':');
        semesterCode = parts[0].trim();
        courseCode = normalizeCourseCode(parts.slice(1).join(':'));
    } else {
        courseCode = normalizeCourseCode(targetId);
        semesterCode = await semesterData.resolveSemesterCode();
    }

    if (!semesterCode || !COURSE_CODE_RE.test(courseCode)) return null;

    const result = await db.query(
        `SELECT semester_code, course_code,
                marking_scheme, attendance_policy, audit_withdrawal_policy, other_notes,
                created_kerberos, created_name, created_at,
                updated_kerberos, updated_name, updated_at
         FROM course_policies
         WHERE semester_code = $1 AND course_code = $2`,
        [semesterCode, courseCode],
    );
    if (result.rowCount === 0) return null;
    const row = result.rows[0];
    return {
        kind: 'course_policy',
        semesterCode: row.semester_code,
        courseCode: row.course_code,
        markingScheme: row.marking_scheme || '',
        attendancePolicy: row.attendance_policy || '',
        auditWithdrawalPolicy: row.audit_withdrawal_policy || '',
        otherNotes: row.other_notes || '',
        updatedBy: {
            kerberos: row.updated_kerberos || undefined,
            name: row.updated_name,
            at: row.updated_at.toISOString(),
        },
    };
}

async function snapshotOccupiedRoom(id) {
    const result = await db.query(
        `SELECT id, room_name, occupancy_date, start_hhmm, end_hhmm, note,
                marked_kerberos, marked_name, created_at
         FROM occupied_rooms WHERE id = $1::uuid`,
        [id],
    );
    if (result.rowCount === 0) return null;
    const row = result.rows[0];
    return {
        kind: 'occupied_room',
        id: row.id,
        room: row.room_name,
        date: pgDateToKey(row.occupancy_date),
        start: row.start_hhmm,
        end: row.end_hhmm,
        note: row.note || undefined,
        markedBy: {
            kerberos: row.marked_kerberos || undefined,
            name: row.marked_name,
            at: row.created_at.toISOString(),
        },
    };
}

async function buildSnapshot(parsed) {
    const { targetKind, targetId, pageContext, label } = parsed;

    if (targetKind === 'course_event') {
        if (!UUID_RE.test(targetId)) return { error: 'invalid_target_id' };
        const snapshot = await snapshotCourseEvent(targetId);
        if (!snapshot) return { error: 'target_not_found' };
        return { snapshot, canonicalTargetId: targetId };
    }

    if (targetKind === 'course_policy') {
        const snapshot = await snapshotCoursePolicy(targetId);
        if (!snapshot) return { error: 'target_not_found' };
        return {
            snapshot,
            canonicalTargetId: `${snapshot.semesterCode}:${snapshot.courseCode}`,
        };
    }

    if (targetKind === 'occupied_room') {
        if (!UUID_RE.test(targetId)) return { error: 'invalid_target_id' };
        const snapshot = await snapshotOccupiedRoom(targetId);
        if (!snapshot) return { error: 'target_not_found' };
        return { snapshot, canonicalTargetId: targetId };
    }

    return {
        snapshot: {
            kind: 'other',
            targetId,
            pageContext: pageContext || undefined,
            label: label || undefined,
        },
        canonicalTargetId: targetId,
    };
}

router.post('/reports', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const parsed = validateReportBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }

    const actor = actorFromSession(req.session);
    if (!actor.kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    let built;
    try {
        built = await buildSnapshot(parsed.value);
    } catch (e) {
        console.error('[reports] snapshot failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
        return;
    }

    if (built.error) {
        const status = built.error === 'target_not_found' ? 404 : 400;
        res.status(status).json({ error: built.error });
        return;
    }

    const { snapshot, canonicalTargetId } = built;
    const { targetKind, reason, details } = parsed.value;

    try {
        const result = await db.query(
            `INSERT INTO content_reports (
                reporter_kerberos, reporter_name,
                target_kind, target_id, target_snapshot,
                reason, details
             ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7)
             RETURNING id, created_at`,
            [
                actor.kerberos,
                actor.name,
                targetKind,
                canonicalTargetId,
                JSON.stringify(snapshot),
                reason,
                details,
            ],
        );
        const row = result.rows[0];
        res.status(201).json({
            id: row.id,
            createdAt: row.created_at.toISOString(),
        });
    } catch (e) {
        if (e.code === '23505') {
            res.status(409).json({ error: 'duplicate_report' });
            return;
        }
        console.error('[reports] create failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
