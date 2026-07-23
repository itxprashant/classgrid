'use strict';

const config = require('./config');
const db = require('./db');
const { readSession } = require('./session');

function auditActorFromSession(session) {
    if (!session) {
        return { kerberos: null, name: null };
    }
    const kerberos = session.kerberos ? String(session.kerberos).trim().toLowerCase() : null;
    const rawName = session.name != null ? String(session.name).trim() : '';
    // Do not store kerberos as the display name — admin UI enriches from rosters when null.
    const name = rawName && (!kerberos || rawName.toLowerCase() !== kerberos)
        ? rawName
        : null;
    return { kerberos, name };
}

function clientFromRequest(req) {
    if (!req || !req.headers) return null;
    const header = req.headers['x-classgrid-client'];
    if (!header) return null;
    const c = String(header).trim().toLowerCase();
    if (c === 'web' || c === 'android') return c;
    return null;
}

function sanitizeMetadata(metadata) {
    if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
        return {};
    }
    return metadata;
}

async function recordAudit({
    req,
    action,
    targetKind,
    targetId,
    metadata,
    actor,
    client,
}) {
    if (!config.databaseUrl) return;

    const resolvedActor = actor || auditActorFromSession(req ? readSession(req) : null);
    const resolvedClient = client || (req ? clientFromRequest(req) : null);
    const ip = req && req.ip ? req.ip : null;
    const meta = {
        ...sanitizeMetadata(metadata),
        ...(req && req.requestId ? { requestId: req.requestId } : {}),
    };

    await db.query(
        `INSERT INTO app_audit_log (
            action, actor_kerberos, actor_name, target_kind, target_id,
            metadata, client, ip
         ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8::inet)`,
        [
            action,
            resolvedActor.kerberos,
            resolvedActor.name,
            targetKind,
            String(targetId || ''),
            JSON.stringify(meta),
            resolvedClient,
            ip,
        ],
    );
}

function recordAuditSafe(params) {
    recordAudit(params).catch((e) => {
        console.error('[audit] insert failed:', e.message);
    });
}

function rowToAuditEntry(row) {
    return {
        id: row.id,
        occurredAt: row.occurred_at.toISOString(),
        action: row.action,
        actorKerberos: row.actor_kerberos || null,
        actorName: row.actor_name || null,
        targetKind: row.target_kind,
        targetId: row.target_id,
        metadata: row.metadata || {},
        client: row.client || null,
        ip: row.ip ? String(row.ip) : null,
    };
}

function actorNeedsNameLookup(entry) {
    if (!entry || !entry.actorKerberos) return false;
    if (!entry.actorName) return true;
    return entry.actorName.toLowerCase() === entry.actorKerberos.toLowerCase();
}

/** Fill missing actorName from course_rosters for admin display. */
async function enrichAuditActorNames(entries) {
    if (!config.databaseUrl || !Array.isArray(entries) || entries.length === 0) {
        return entries;
    }

    const needLookup = [...new Set(
        entries.filter(actorNeedsNameLookup).map((e) => e.actorKerberos),
    )];
    if (needLookup.length === 0) return entries;

    try {
        const { rows } = await db.query(
            `SELECT lower(student_kerberos) AS kerberos,
                    (array_agg(trim(student_name) ORDER BY semester_code DESC, length(trim(student_name)) DESC))[1] AS name
             FROM course_rosters
             WHERE lower(student_kerberos) = ANY($1::text[])
               AND trim(student_name) <> ''
             GROUP BY lower(student_kerberos)`,
            [needLookup],
        );
        const byKerberos = new Map(
            rows
                .filter((r) => r.name && r.name.toLowerCase() !== r.kerberos)
                .map((r) => [r.kerberos, r.name]),
        );
        for (const entry of entries) {
            if (!actorNeedsNameLookup(entry)) continue;
            const name = byKerberos.get(entry.actorKerberos);
            if (name) entry.actorName = name;
        }
    } catch (e) {
        console.error('[audit] actor name enrich failed:', e.message);
    }

    return entries;
}

module.exports = {
    auditActorFromSession,
    recordAudit,
    recordAuditSafe,
    rowToAuditEntry,
    enrichAuditActorNames,
};
