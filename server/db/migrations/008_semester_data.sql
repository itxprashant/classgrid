-- Semester reference data: catalog, enrollments, rosters, academic calendar,
-- legacy extra-occupied overlay, and app release config.

CREATE TABLE IF NOT EXISTS semesters (
    code                TEXT PRIMARY KEY,
    label               TEXT NOT NULL,
    classes_start       DATE NOT NULL,
    last_teaching_day   DATE NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT false,
    academic_calendar   JSONB NOT NULL DEFAULT '{}'::jsonb,
    catalog_etag        TEXT,
    catalog_updated_at  TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT semesters_academic_calendar_is_object
        CHECK (jsonb_typeof(academic_calendar) = 'object')
);

-- Only one semester may be active at a time.
CREATE UNIQUE INDEX IF NOT EXISTS semesters_one_active
    ON semesters (is_active)
    WHERE is_active = true;

CREATE TABLE IF NOT EXISTS catalog_courses (
    semester_code   TEXT NOT NULL REFERENCES semesters (code) ON DELETE CASCADE,
    course_code     TEXT NOT NULL,
    course_data     JSONB NOT NULL,
    PRIMARY KEY (semester_code, course_code),

    CONSTRAINT catalog_courses_data_is_object
        CHECK (jsonb_typeof(course_data) = 'object')
);

CREATE INDEX IF NOT EXISTS catalog_courses_semester_idx
    ON catalog_courses (semester_code);

CREATE TABLE IF NOT EXISTS student_enrollments (
    semester_code   TEXT NOT NULL REFERENCES semesters (code) ON DELETE CASCADE,
    kerberos        VARCHAR(64) NOT NULL,
    course_code     TEXT NOT NULL,
    PRIMARY KEY (semester_code, kerberos, course_code)
);

CREATE INDEX IF NOT EXISTS student_enrollments_kerberos_idx
    ON student_enrollments (semester_code, kerberos);

CREATE INDEX IF NOT EXISTS student_enrollments_course_idx
    ON student_enrollments (semester_code, course_code);

CREATE TABLE IF NOT EXISTS course_rosters (
    semester_code       TEXT NOT NULL REFERENCES semesters (code) ON DELETE CASCADE,
    course_code         TEXT NOT NULL,
    student_kerberos    VARCHAR(64) NOT NULL,
    student_name        TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (semester_code, course_code, student_kerberos)
);

CREATE INDEX IF NOT EXISTS course_rosters_course_idx
    ON course_rosters (semester_code, course_code);

CREATE TABLE IF NOT EXISTS extra_occupied_slots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    semester_code   TEXT NOT NULL REFERENCES semesters (code) ON DELETE CASCADE,
    lecture_hall    TEXT NOT NULL,
    day_of_week     SMALLINT NOT NULL,
    start_time      CHAR(4) NOT NULL,
    end_time        CHAR(4) NOT NULL,
    reason          TEXT,

    CONSTRAINT extra_occupied_day_range CHECK (day_of_week >= 0 AND day_of_week <= 6)
);

CREATE INDEX IF NOT EXISTS extra_occupied_semester_idx
    ON extra_occupied_slots (semester_code);

CREATE TABLE IF NOT EXISTS app_release_config (
    platform        TEXT PRIMARY KEY,
    version         TEXT NOT NULL,
    build           INTEGER NOT NULL,
    download_url    TEXT NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
