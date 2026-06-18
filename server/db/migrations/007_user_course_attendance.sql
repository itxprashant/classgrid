-- Per-user attendance counters by course and session kind (lecture/tutorial/lab).
-- Sparse per-date marks live in by_date JSONB; stats computed on clients.

CREATE TABLE IF NOT EXISTS user_course_attendance (
    kerberos      VARCHAR(64) NOT NULL,
    course_code   VARCHAR(32) NOT NULL,
    session_kind  VARCHAR(16) NOT NULL CHECK (session_kind IN ('lecture', 'tutorial', 'lab')),
    present       INTEGER NOT NULL DEFAULT 0 CHECK (present >= 0),
    absent        INTEGER NOT NULL DEFAULT 0 CHECK (absent >= 0),
    excused       INTEGER NOT NULL DEFAULT 0 CHECK (excused >= 0),
    by_date       JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (kerberos, course_code, session_kind),
    CONSTRAINT user_course_attendance_by_date_is_object
        CHECK (jsonb_typeof(by_date) = 'object')
);

CREATE INDEX IF NOT EXISTS idx_user_course_attendance_kerberos
    ON user_course_attendance (kerberos);
