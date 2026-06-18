-- Speed up instructor search across catalog history (prof explorer).
CREATE INDEX IF NOT EXISTS catalog_courses_instructor_email_idx
    ON catalog_courses (lower(course_data->>'instructorEmail'))
    WHERE course_data->>'instructorEmail' IS NOT NULL
      AND course_data->>'instructorEmail' <> '';
