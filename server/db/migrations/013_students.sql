-- Student directory overlay (hostel and future profile fields).
-- Search/detail still use course_rosters + student_enrollments; this table is optional metadata.

CREATE TABLE IF NOT EXISTS students (
    kerberos    VARCHAR(64) PRIMARY KEY,
    hostel      TEXT,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS course_rosters_student_kerberos_lower_idx
    ON course_rosters (lower(student_kerberos));
