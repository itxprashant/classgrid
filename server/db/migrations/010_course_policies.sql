-- Per-semester course policy documents (marking, attendance, audit/withdrawal).
-- One row per (semester_code, course_code); editable by enrolled students.

CREATE TABLE IF NOT EXISTS course_policies (
    semester_code           TEXT NOT NULL REFERENCES semesters (code) ON DELETE CASCADE,
    course_code             TEXT NOT NULL,
    marking_scheme          TEXT NOT NULL DEFAULT '',
    attendance_policy       TEXT NOT NULL DEFAULT '',
    audit_withdrawal_policy TEXT NOT NULL DEFAULT '',
    other_notes             TEXT NOT NULL DEFAULT '',
    created_kerberos        VARCHAR(64),
    created_name            VARCHAR(255) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_kerberos        VARCHAR(64),
    updated_name            VARCHAR(255) NOT NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (semester_code, course_code)
);

CREATE INDEX IF NOT EXISTS course_policies_course_idx
    ON course_policies (course_code);
