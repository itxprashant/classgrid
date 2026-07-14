-- Optional vs force-update thresholds and per-release changelog history.

ALTER TABLE app_release_config
    ADD COLUMN IF NOT EXISTS minimum_version TEXT,
    ADD COLUMN IF NOT EXISTS minimum_build INTEGER;

UPDATE app_release_config
SET
    minimum_version = COALESCE(minimum_version, version),
    minimum_build = COALESCE(minimum_build, build)
WHERE minimum_version IS NULL OR minimum_build IS NULL;

ALTER TABLE app_release_config
    ALTER COLUMN minimum_version SET NOT NULL,
    ALTER COLUMN minimum_build SET NOT NULL;

CREATE TABLE IF NOT EXISTS app_release_history (
    platform        TEXT NOT NULL,
    build           INTEGER NOT NULL,
    version         TEXT NOT NULL,
    download_url    TEXT NOT NULL,
    release_notes   TEXT NOT NULL DEFAULT '',
    published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (platform, build)
);

CREATE INDEX IF NOT EXISTS app_release_history_platform_published_idx
    ON app_release_history (platform, published_at DESC);
