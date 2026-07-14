-- Structured audit trail for UGC writes, auth, and admin actions (monitoring / triage).

CREATE TABLE IF NOT EXISTS app_audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    action          TEXT NOT NULL,
    actor_kerberos  TEXT,
    actor_name      TEXT,
    target_kind     TEXT NOT NULL,
    target_id       TEXT NOT NULL DEFAULT '',
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    client          TEXT,
    ip              INET,

    CONSTRAINT app_audit_log_metadata_is_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS app_audit_log_occurred_at_idx
    ON app_audit_log (occurred_at DESC);

CREATE INDEX IF NOT EXISTS app_audit_log_action_occurred_idx
    ON app_audit_log (action, occurred_at DESC);

CREATE INDEX IF NOT EXISTS app_audit_log_target_idx
    ON app_audit_log (target_kind, target_id);

CREATE INDEX IF NOT EXISTS app_audit_log_actor_kerberos_idx
    ON app_audit_log (actor_kerberos)
    WHERE actor_kerberos IS NOT NULL;
