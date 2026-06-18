-- Admin triage audit on content reports.

ALTER TABLE content_reports
    ADD COLUMN IF NOT EXISTS reviewed_by_kerberos VARCHAR(64),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
