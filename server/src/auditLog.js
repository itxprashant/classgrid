'use strict';

const config = require('./config');
const db = require('./db');
const { readSession } = require('./session');

function auditActorFromSession(session) {
    if (!session) {
        return { kerberos: null, name: null };
    }
    return {
        kerberos: session.kerberos ? String(session.kerberos).trim().toLowerCase() : null,
        name: (session.name || session.kerberos || null),
    };
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

module.exports = {
    auditActorFromSession,
    recordAudit,
    recordAuditSafe,
    rowToAuditEntry,
};
