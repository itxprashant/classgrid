-- Per-user class/event reminder subscriptions (30 min before event_start).
-- The mobile app schedules local OS notifications from these rows.

CREATE TABLE IF NOT EXISTS user_reminders (
    kerberos     VARCHAR(64) NOT NULL,
    reminder_key VARCHAR(256) NOT NULL,
    title        TEXT NOT NULL,
    body         TEXT NOT NULL,
    event_start  TIMESTAMPTZ NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (kerberos, reminder_key)
);

CREATE INDEX IF NOT EXISTS idx_user_reminders_kerberos_event_start
    ON user_reminders (kerberos, event_start);
