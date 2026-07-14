CREATE TABLE user_fcm_tokens (
    fcm_token   TEXT PRIMARY KEY,
    kerberos    VARCHAR(64),
    platform    VARCHAR(16) NOT NULL DEFAULT 'android',
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_fcm_tokens_kerberos
    ON user_fcm_tokens (kerberos)
    WHERE kerberos IS NOT NULL;
