-- Feature feedback and UGC content reports.
--
-- Triage (newest first):
--   SELECT id, target_kind, target_id, reason, reporter_kerberos, created_at, target_snapshot
--   FROM content_reports WHERE status = 'open' ORDER BY created_at DESC;
--
--   SELECT id, kerberos, category, left(message, 120), created_at
--   FROM app_feedback ORDER BY created_at DESC LIMIT 50;
--
--   UPDATE content_reports SET status = 'reviewed' WHERE id = '…';

CREATE TABLE IF NOT EXISTS app_feedback (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kerberos        VARCHAR(64),
    reporter_name   VARCHAR(255),
    reporter_email  VARCHAR(255),
    message         TEXT NOT NULL,
    category        VARCHAR(32) NOT NULL DEFAULT 'feature',
    page_context    TEXT,
    client          VARCHAR(16) NOT NULL DEFAULT 'web',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT app_feedback_category_check CHECK (
        category IN ('feature', 'improvement', 'bug', 'other')
    ),
    CONSTRAINT app_feedback_client_check CHECK (
        client IN ('web', 'android')
    ),
    CONSTRAINT app_feedback_message_len CHECK (
        char_length(message) >= 10 AND char_length(message) <= 4000
    )
);

CREATE INDEX IF NOT EXISTS app_feedback_created_at_idx
    ON app_feedback (created_at DESC);

CREATE INDEX IF NOT EXISTS app_feedback_kerberos_created_idx
    ON app_feedback (kerberos, created_at DESC)
    WHERE kerberos IS NOT NULL;

CREATE TABLE IF NOT EXISTS content_reports (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_kerberos   VARCHAR(64) NOT NULL,
    reporter_name       VARCHAR(255) NOT NULL,
    target_kind         VARCHAR(32) NOT NULL,
    target_id           TEXT NOT NULL,
    target_snapshot     JSONB NOT NULL DEFAULT '{}',
    reason              VARCHAR(32) NOT NULL,
    details             TEXT NOT NULL DEFAULT '',
    status              VARCHAR(16) NOT NULL DEFAULT 'open',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT content_reports_kind_check CHECK (
        target_kind IN ('course_event', 'course_policy', 'occupied_room', 'other')
    ),
    CONSTRAINT content_reports_reason_check CHECK (
        reason IN ('spam', 'wrong_info', 'offensive', 'duplicate', 'other')
    ),
    CONSTRAINT content_reports_status_check CHECK (
        status IN ('open', 'reviewed', 'dismissed', 'actioned')
    ),
    CONSTRAINT content_reports_details_len CHECK (
        char_length(details) <= 2000
    )
);

CREATE INDEX IF NOT EXISTS content_reports_status_created_idx
    ON content_reports (status, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS content_reports_open_unique
    ON content_reports (reporter_kerberos, target_kind, target_id)
    WHERE status = 'open';
