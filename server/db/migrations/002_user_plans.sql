-- Per-user planner state: selected courses + tutorial/lab session choices.
-- Private to each kerberos id (not shared like course_events).

CREATE TABLE IF NOT EXISTS user_plans (
    kerberos          VARCHAR(64) PRIMARY KEY,
    selected_courses  JSONB NOT NULL DEFAULT '[]'::jsonb,
    timetable_data    JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT user_plans_selected_courses_is_array CHECK (jsonb_typeof(selected_courses) = 'array'),
    CONSTRAINT user_plans_timetable_data_is_object CHECK (jsonb_typeof(timetable_data) = 'object')
);
