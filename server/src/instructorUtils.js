'use strict';

const { normalizeEmail, parseInstructorsFromRow, instructorsFromCourseData } = require('./parse_instructors');

/** SQL fragment: instructors JSONB array for a catalog_courses row. */
const INSTRUCTORS_JSON_SQL = `CASE
    WHEN jsonb_typeof(c.course_data->'instructors') = 'array'
     AND jsonb_array_length(c.course_data->'instructors') > 0
    THEN c.course_data->'instructors'
    WHEN c.course_data->>'instructorEmail' IS NOT NULL
     AND c.course_data->>'instructorEmail' <> ''
    THEN jsonb_build_array(
        jsonb_build_object(
            'name', COALESCE(c.course_data->>'instructor', ''),
            'email', lower(c.course_data->>'instructorEmail')
        )
    )
    ELSE '[]'::jsonb
END`;

module.exports = {
    normalizeEmail,
    parseInstructorsFromRow,
    instructorsFromCourseData,
    INSTRUCTORS_JSON_SQL,
};
