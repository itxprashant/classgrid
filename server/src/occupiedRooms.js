'use strict';

const express = require('express');
const config = require('./config');
const db = require('./db');
const { requireSession } = require('./session');
const { recordAuditSafe } = require('./auditLog');

const router = express.Router();

const HHMM_RE = /^[0-2][0-9][0-5][0-9]$/;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function dbUnavailable(res) {
    res.status(503).json({ error: 'database_unavailable' });
}

function normalizeRoomName(name) {
    const s = String(name || '').trim().replace(/\s+/g, ' ');
    if (!s) return '';
    const m = s.match(/^LH\s*(.+)$/i);
    if (m) return `LH ${m[1].trim()}`;
    return s;
}

function normalizeHHMM(value) {
    if (value == null || value === '') return null;
    const s = String(value).trim();
    const colon = s.match(/^(\d{2}):(\d{2})$/);
    if (colon) return `${colon[1]}${colon[2]}`;
    if (HHMM_RE.test(s)) return s;
    return null;
}

function parseDateQuery(raw) {
    if (!raw || typeof raw !== 'string' || !DATE_RE.test(raw.trim())) return null;
    return raw.trim();
}

function parseTimeQuery(raw) {
    const n = parseInt(String(raw || '').trim(), 10);
    if (!Number.isFinite(n) || n < 0 || n > 2359) return null;
    return n;
}

function pgDateToKey(val) {
    if (!val) return '';
    if (typeof val === 'string') return val.slice(0, 10);
    const y = val.getUTCFullYear();
    const m = String(val.getUTCMonth() + 1).padStart(2, '0');
    const d = String(val.getUTCDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
}

function rowToMarking(row) {
    const marking = {
        id: row.id,
        room: row.room_name,
        date: pgDateToKey(row.occupancy_date),
        start: row.start_hhmm,
        end: row.end_hhmm,
        markedBy: {
            kerberos: row.marked_kerberos || undefined,
            name: row.marked_name,
            at: row.created_at.toISOString(),
        },
    };
    if (row.note) marking.note = row.note;
    return marking;
}

function validateMarkBody(body) {
    if (!body || typeof body !== 'object') return { error: 'invalid_body' };

    const room = normalizeRoomName(body.room);
    if (!room || room.length > 64) return { error: 'invalid_room' };

    const date = parseDateQuery(body.date);
    if (!date) return { error: 'invalid_date' };

    const start = normalizeHHMM(body.start);
    const end = normalizeHHMM(body.end);
    if (!start || !end || start >= end) return { error: 'invalid_time_range' };

    let note = null;
    if (body.note != null && body.note !== '') {
        note = String(body.note).trim().slice(0, 500) || null;
    }

    return { value: { room, date, start, end, note } };
}

router.get('/rooms/occupied', async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const date = parseDateQuery(req.query.date);
    const time = parseTimeQuery(req.query.time);
    if (!date || time == null) {
        res.status(400).json({ error: 'invalid_query' });
        return;
    }

    const timeStr = String(time).padStart(4, '0');

    try {
        const result = await db.query(
            `SELECT id, room_name, occupancy_date, start_hhmm, end_hhmm, note,
                    marked_kerberos, marked_name, created_at
             FROM occupied_rooms
             WHERE occupancy_date = $1::date
               AND start_hhmm <= $2
               AND end_hhmm > $2
             ORDER BY room_name ASC`,
            [date, timeStr]
        );
        res.json({ markings: result.rows.map(rowToMarking) });
    } catch (e) {
        console.error('[occupiedRooms] list failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.post('/rooms/occupied', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const parsed = validateMarkBody(req.body);
    if (parsed.error) {
        res.status(400).json({ error: parsed.error });
        return;
    }

    const kerberos = (req.session.kerberos || '').trim().toLowerCase();
    const name = (req.session.name || req.session.kerberos || 'Unknown').trim();
    const { room, date, start, end, note } = parsed.value;

    try {
        const result = await db.query(
            `INSERT INTO occupied_rooms (
                room_name, occupancy_date, start_hhmm, end_hhmm, note,
                marked_kerberos, marked_name, updated_at
             ) VALUES ($1, $2::date, $3, $4, $5, $6, $7, now())
             RETURNING id, room_name, occupancy_date, start_hhmm, end_hhmm, note,
                       marked_kerberos, marked_name, created_at`,
            [room, date, start, end, note, kerberos || null, name]
        );
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'occupied_room.marked',
            targetKind: 'occupied_room',
            targetId: row.id,
            metadata: {
                id: row.id,
                room: row.room_name,
                occupancy_date: pgDateToKey(row.occupancy_date),
                start: row.start_hhmm,
                end: row.end_hhmm,
            },
        });
        res.status(201).json({ marking: rowToMarking(row) });
    } catch (e) {
        console.error('[occupiedRooms] create failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

router.delete('/rooms/occupied/:id', requireSession, async (req, res) => {
    if (!config.databaseUrl) {
        dbUnavailable(res);
        return;
    }

    const kerberos = (req.session.kerberos || '').trim().toLowerCase();
    if (!kerberos) {
        res.status(400).json({ error: 'missing_kerberos' });
        return;
    }

    try {
        const result = await db.query(
            `DELETE FROM occupied_rooms
             WHERE id = $1::uuid AND marked_kerberos = $2
             RETURNING id, room_name, occupancy_date, start_hhmm, end_hhmm`,
            [req.params.id, kerberos]
        );
        if (result.rowCount === 0) {
            res.status(404).json({ error: 'not_found' });
            return;
        }
        const row = result.rows[0];
        recordAuditSafe({
            req,
            action: 'occupied_room.unmarked',
            targetKind: 'occupied_room',
            targetId: row.id,
            metadata: {
                id: row.id,
                room: row.room_name,
                occupancy_date: pgDateToKey(row.occupancy_date),
                start: row.start_hhmm,
                end: row.end_hhmm,
            },
        });
        res.json({ id: row.id });
    } catch (e) {
        console.error('[occupiedRooms] delete failed:', e.message);
        res.status(500).json({ error: 'internal_error' });
    }
});

module.exports = router;
