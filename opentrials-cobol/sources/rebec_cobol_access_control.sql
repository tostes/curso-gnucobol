-- ============================================================
-- ReBEC COBOL - Access Control
-- ============================================================

SET search_path TO rebec_cobol;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS app_role (
    id SERIAL PRIMARY KEY,
    role_code VARCHAR(30) UNIQUE NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO app_role (role_code, role_name, description)
VALUES
    ('guest', 'Guest', 'Public user without login'),
    ('registrant', 'Registrant', 'User allowed to register and submit trials'),
    ('reviewer', 'Reviewer', 'User allowed to review and approve trials'),
    ('admin', 'Administrator', 'User allowed to manage users and permissions')
ON CONFLICT (role_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS app_user (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role_id INTEGER REFERENCES app_role(id),
    user_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    requested_role VARCHAR(30),
    request_reason TEXT,
    approved_by INTEGER REFERENCES app_user(id),
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    last_login_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_user_request (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL,
    requested_username VARCHAR(80) NOT NULL,
    requested_role VARCHAR(30) NOT NULL,
    request_reason TEXT,
    request_status VARCHAR(30) NOT NULL DEFAULT 'pending',
    reviewed_by INTEGER REFERENCES app_user(id),
    reviewed_at TIMESTAMP,
    review_comment TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_login_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES app_user(id),
    username_attempt VARCHAR(80),
    login_success BOOLEAN NOT NULL,
    message TEXT,
    created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_user_status
ON app_user(user_status);

CREATE INDEX IF NOT EXISTS idx_app_user_role_id
ON app_user(role_id);

CREATE INDEX IF NOT EXISTS idx_app_user_request_status
ON app_user_request(request_status);

ALTER TABLE trial
ADD COLUMN IF NOT EXISTS created_by_user_id INTEGER REFERENCES app_user(id);

ALTER TABLE trial
ADD COLUMN IF NOT EXISTS submitted_by_user_id INTEGER REFERENCES app_user(id);

ALTER TABLE trial
ADD COLUMN IF NOT EXISTS reviewed_by_user_id INTEGER REFERENCES app_user(id);

ALTER TABLE trial
ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMP;

ALTER TABLE trial
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP;

CREATE OR REPLACE FUNCTION app_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS TABLE (
    login_success BOOLEAN,
    user_id INTEGER,
    username VARCHAR,
    full_name VARCHAR,
    role_code VARCHAR,
    message TEXT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        true AS login_success,
        u.id AS user_id,
        u.username,
        u.full_name,
        r.role_code,
        'Login successful'::TEXT AS message
    FROM app_user u
    JOIN app_role r ON r.id = u.role_id
    WHERE u.username = p_username
      AND u.user_status = 'active'
      AND u.password_hash = crypt(p_password, u.password_hash);

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            false AS login_success,
            NULL::INTEGER AS user_id,
            NULL::VARCHAR AS username,
            NULL::VARCHAR AS full_name,
            NULL::VARCHAR AS role_code,
            'Invalid username, password, or inactive user'::TEXT AS message;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW vw_pending_user_requests AS
SELECT
    id,
    full_name,
    email,
    requested_username,
    requested_role,
    request_reason,
    request_status,
    created_at
FROM app_user_request
WHERE request_status = 'pending'
ORDER BY created_at;

CREATE OR REPLACE VIEW vw_active_users AS
SELECT
    u.id,
    u.username,
    u.full_name,
    u.email,
    r.role_code,
    r.role_name,
    u.user_status,
    u.created_at,
    u.last_login_at
FROM app_user u
LEFT JOIN app_role r ON r.id = u.role_id
WHERE u.user_status = 'active'
ORDER BY u.username;

-- First admin user for development.
-- Change password after first login.
INSERT INTO app_user (
    username,
    password_hash,
    full_name,
    email,
    role_id,
    user_status,
    requested_role,
    approved_at
)
VALUES (
    'admin',
    crypt('admin123', gen_salt('bf')),
    'System Administrator',
    'admin@example.org',
    (SELECT id FROM app_role WHERE role_code = 'admin'),
    'active',
    'admin',
    now()
)
ON CONFLICT (username) DO NOTHING;
