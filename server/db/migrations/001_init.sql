-- ClassGrid initial schema: shared course calendar events.
-- Mirrors the event shape in src/utils/calendarEvents.js.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version     TEXT PRIMARY KEY,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS course_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_code     VARCHAR(32) NOT NULL,
    event_date      DATE NOT NULL,
    title           TEXT NOT NULL,
    type            VARCHAR(32) NOT NULL,
    schedule        VARCHAR(16) NOT NULL DEFAULT 'fullday',
    time_hhmm       CHAR(4),
    start_hhmm      CHAR(4),
    end_hhmm        CHAR(4),
    note            TEXT,
    created_kerberos VARCHAR(64),
    created_name    VARCHAR(255) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_kerberos VARCHAR(64),
    updated_name    VARCHAR(255) NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT course_events_type_check CHECK (
        type IN ('quiz', 'deadline', 'exam', 'extra-class', 'presentation', 'others')
    ),
    CONSTRAINT course_events_schedule_check CHECK (
        schedule IN ('fullday', 'at', 'timed', 'eod')
    ),
    CONSTRAINT course_events_time_hhmm_check CHECK (
        time_hhmm IS NULL OR time_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    ),
    CONSTRAINT course_events_start_hhmm_check CHECK (
        start_hhmm IS NULL OR start_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    ),
    CONSTRAINT course_events_end_hhmm_check CHECK (
        end_hhmm IS NULL OR end_hhmm ~ '^[0-2][0-9][0-5][0-9]$'
    )
);

CREATE INDEX IF NOT EXISTS idx_course_events_course_date
    ON course_events (course_code, event_date);

CREATE INDEX IF NOT EXISTS idx_course_events_event_date
    ON course_events (event_date);
