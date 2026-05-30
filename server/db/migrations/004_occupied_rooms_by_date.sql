-- Markings apply to a specific calendar date, not every week on that weekday.

DELETE FROM occupied_rooms;

DROP INDEX IF EXISTS idx_occupied_rooms_day_time;

ALTER TABLE occupied_rooms DROP COLUMN day_of_week;

ALTER TABLE occupied_rooms ADD COLUMN occupancy_date DATE NOT NULL;

CREATE INDEX IF NOT EXISTS idx_occupied_rooms_date_time
    ON occupied_rooms (occupancy_date, start_hhmm, end_hhmm);
