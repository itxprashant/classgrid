-- Manual room occupancy (bookings not on the official timetable / allotment chart).

CREATE TABLE IF NOT EXISTS occupied_rooms (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_name        VARCHAR(64) NOT NULL,
    day_of_week      SMALLINT NOT NULL,
    start_hhmm       CHAR(4) NOT NULL,
    end_hhmm         CHAR(4) NOT NULL,
    note             TEXT,
    marked_kerberos  VARCHAR(64),
    marked_name      VARCHAR(255) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT occupied_rooms_day_check CHECK (day_of_week >= 0 AND day_of_week <= 6),
    CONSTRAINT occupied_rooms_start_hhmm_check CHECK (start_hhmm ~ '^[0-2][0-9][0-5][0-9]$'),
    CONSTRAINT occupied_rooms_end_hhmm_check CHECK (end_hhmm ~ '^[0-2][0-9][0-5][0-9]$'),
    CONSTRAINT occupied_rooms_time_order_check CHECK (start_hhmm < end_hhmm)
);

CREATE INDEX IF NOT EXISTS idx_occupied_rooms_day_time
    ON occupied_rooms (day_of_week, start_hhmm, end_hhmm);

CREATE INDEX IF NOT EXISTS idx_occupied_rooms_room
    ON occupied_rooms (room_name);
