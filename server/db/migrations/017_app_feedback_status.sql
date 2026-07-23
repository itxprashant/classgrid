-- Admin triage status on feature feedback (mirrors content_reports).

ALTER TABLE app_feedback
    ADD COLUMN IF NOT EXISTS status VARCHAR(16) NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS reviewed_by_kerberos VARCHAR(64),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'app_feedback_status_check'
    ) THEN
        ALTER TABLE app_feedback
            ADD CONSTRAINT app_feedback_status_check
            CHECK (status IN ('open', 'reviewed', 'dismissed', 'actioned'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS app_feedback_status_created_idx
    ON app_feedback (status, created_at DESC);
