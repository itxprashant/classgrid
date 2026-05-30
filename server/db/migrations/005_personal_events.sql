-- Private calendar events — visible only to the owning kerberos id.

CREATE TABLE IF NOT EXISTS personal_events (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kerberos         VARCHAR(64) NOT NULL,
    event_date       DATE NOT NULL,
    title            TEXT NOT NULL,
    type             VARCHAR(32) NOT NULL,
    schedule         VARCHAR(16) NOT NULL DEFAULT 'fullday',
    time_hhmm        CHAR(4),
    start_hhmm       CHAR(4),
    end_hhmm         CHAR(4),
    note             TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT personal_events_type_check CHECK (
        type IN ('quiz', 'deadline', 'exam', 'extra-class', 'presentation', 'others')
    ),
    CONSTRAINT personal_events_schedule_check CHECK (
        schedule IN ('fullday', 'at', 'timed', 'eod')
    ),
    CONSTRAINT personal_events_time_hhmm_check CHECK (
        time_hhmm IS NULL OR time_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    ),
    CONSTRAINT personal_events_start_hhmm_check CHECK (
        start_hhmm IS NULL OR start_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    ),
    CONSTRAINT personal_events_end_hhmm_check CHECK (
        end_hhmm IS NULL OR end_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    )
);

CREATE INDEX IF NOT EXISTS idx_personal_events_kerberos_date
    ON personal_events (kerberos, event_date);
