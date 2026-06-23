-- ============================================================
-- ReBEC COBOL - Database API Layer
-- ============================================================
--
-- Purpose:
--   Stable PostgreSQL API layer for the COBOL terminal application.
--
-- Architectural rule:
--   COBOL should call views/functions/procedures.
--   Business rules should live in PostgreSQL.
--
-- Expected schema:
--   rebec_cobol
--
-- Dependencies:
--   - rebec_cobol_schema.sql
--   - rebec_cobol_access_control.sql
--   - pgcrypto extension
--
-- ============================================================

SET search_path TO rebec_cobol, public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Utility function: sanitize text for COBOL/psql output
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_cobol_clean_text(p_value TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT
        btrim(
            replace(
                replace(
                    replace(coalesce(p_value, ''), '|', ' '),
                    chr(10), ' '
                ),
                chr(13), ' '
            )
        );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_cobol_clean_text(TEXT)
IS 'Sanitizes text for COBOL consumption through psql -At -F pipe output.';

-- ============================================================
-- 2. Public trial API
-- ============================================================

CREATE OR REPLACE VIEW rebec_cobol.vw_public_trials AS
SELECT
    t.id,
    t.trial_id,
    t.status,
    t.date_registration AS registration_date,
    t.date_enrolment AS enrolment_date,
    t.public_title,
    t.scientific_title,
    rs.xml_value AS recruitment_status,
    st.xml_value AS study_type,
    ph.xml_value AS phase,
    t.target_size,
    t.primary_sponsor,
    t.url,
    t.utrn,
    sd.generated_study_design AS study_design,
    t.hc_freetext AS health_conditions
FROM rebec_cobol.trial t
LEFT JOIN rebec_cobol.vocab_recruitment_status rs
    ON rs.id = t.recruitment_status_id
LEFT JOIN rebec_cobol.vocab_study_type st
    ON st.id = t.study_type_id
LEFT JOIN rebec_cobol.vocab_phase ph
    ON ph.id = t.phase_id
LEFT JOIN rebec_cobol.trial_study_design sd
    ON sd.trial_id = t.id
WHERE t.status IN ('approved', 'published');

COMMENT ON VIEW rebec_cobol.vw_public_trials
IS 'Public trial list. Only trials with status approved or published are exposed.';

-- ------------------------------------------------------------
-- Public trial list
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.fn_public_trial_list(
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    trial_id TEXT,
    status TEXT,
    registration_date TEXT,
    public_title TEXT,
    recruitment_status TEXT,
    study_type TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.id,
        rebec_cobol.fn_cobol_clean_text(v.trial_id::TEXT) AS trial_id,
        rebec_cobol.fn_cobol_clean_text(v.status::TEXT) AS status,
        coalesce(v.registration_date::TEXT, '') AS registration_date,
        rebec_cobol.fn_cobol_clean_text(v.public_title::TEXT) AS public_title,
        rebec_cobol.fn_cobol_clean_text(v.recruitment_status::TEXT) AS recruitment_status,
        rebec_cobol.fn_cobol_clean_text(v.study_type::TEXT) AS study_type
    FROM rebec_cobol.vw_public_trials v
    ORDER BY v.id
    LIMIT greatest(coalesce(p_limit, 20), 1)
    OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_public_trial_list(INTEGER, INTEGER)
IS 'Returns a paginated list of public trials for trial_list.cbl.';

-- ------------------------------------------------------------
-- Public trial detail by internal database ID
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.fn_public_trial_view_by_id(
    p_id INTEGER
)
RETURNS TABLE (
    id INTEGER,
    trial_id TEXT,
    utrn TEXT,
    status TEXT,
    url TEXT,
    public_contact_name TEXT,
    public_contact_phone TEXT,
    public_contact_email TEXT,
    registration_date TEXT,
    enrolment_date TEXT,
    target_size TEXT,
    recruitment_status TEXT,
    study_type TEXT,
    study_design TEXT,
    phase TEXT,
    primary_sponsor TEXT,
    public_title TEXT,
    scientific_title TEXT,
    health_conditions TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.id,
        rebec_cobol.fn_cobol_clean_text(v.trial_id::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.utrn::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.status::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.url::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_name::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_phone::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_email::TEXT),
        coalesce(v.registration_date::TEXT, ''),
        coalesce(v.enrolment_date::TEXT, ''),
        rebec_cobol.fn_cobol_clean_text(v.target_size::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.recruitment_status::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.study_type::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.study_design::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.phase::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.primary_sponsor::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.public_title::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.scientific_title::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.health_conditions::TEXT)
    FROM rebec_cobol.vw_public_trials v
    LEFT JOIN LATERAL (
        SELECT
            concat_ws(' ', c.firstname, c.middlename, c.lastname) AS contact_name,
            c.telephone AS contact_phone,
            c.email AS contact_email
        FROM rebec_cobol.trial_contact c
        WHERE c.trial_id = v.id
          AND c.contact_type = 'public'
        ORDER BY c.id
        LIMIT 1
    ) pc ON true
    WHERE v.id = p_id
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_public_trial_view_by_id(INTEGER)
IS 'Returns public trial details by internal database ID for trial_view.cbl.';

-- ------------------------------------------------------------
-- Public trial detail by RBR/trial_id
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.fn_public_trial_view_by_rbr(
    p_trial_id TEXT
)
RETURNS TABLE (
    id INTEGER,
    trial_id TEXT,
    utrn TEXT,
    status TEXT,
    url TEXT,
    public_contact_name TEXT,
    public_contact_phone TEXT,
    public_contact_email TEXT,
    registration_date TEXT,
    enrolment_date TEXT,
    target_size TEXT,
    recruitment_status TEXT,
    study_type TEXT,
    study_design TEXT,
    phase TEXT,
    primary_sponsor TEXT,
    public_title TEXT,
    scientific_title TEXT,
    health_conditions TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.id,
        rebec_cobol.fn_cobol_clean_text(v.trial_id::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.utrn::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.status::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.url::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_name::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_phone::TEXT),
        rebec_cobol.fn_cobol_clean_text(pc.contact_email::TEXT),
        coalesce(v.registration_date::TEXT, ''),
        coalesce(v.enrolment_date::TEXT, ''),
        rebec_cobol.fn_cobol_clean_text(v.target_size::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.recruitment_status::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.study_type::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.study_design::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.phase::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.primary_sponsor::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.public_title::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.scientific_title::TEXT),
        rebec_cobol.fn_cobol_clean_text(v.health_conditions::TEXT)
    FROM rebec_cobol.vw_public_trials v
    LEFT JOIN LATERAL (
        SELECT
            concat_ws(' ', c.firstname, c.middlename, c.lastname) AS contact_name,
            c.telephone AS contact_phone,
            c.email AS contact_email
        FROM rebec_cobol.trial_contact c
        WHERE c.trial_id = v.id
          AND c.contact_type = 'public'
        ORDER BY c.id
        LIMIT 1
    ) pc ON true
    WHERE upper(v.trial_id::TEXT) = upper(btrim(p_trial_id))
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_public_trial_view_by_rbr(TEXT)
IS 'Returns public trial details by RBR/trial_id for trial_view.cbl.';

-- ============================================================
-- 3. Authentication API
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_app_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS TABLE (
    login_success BOOLEAN,
    user_id INTEGER,
    username TEXT,
    full_name TEXT,
    role_code TEXT,
    message TEXT
)
LANGUAGE plpgsql
VOLATILE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_user_id INTEGER;
    v_username TEXT;
    v_full_name TEXT;
    v_role_code TEXT;
BEGIN
    SELECT
        u.id,
        u.username::TEXT,
        u.full_name::TEXT,
        r.role_code::TEXT
    INTO
        v_user_id,
        v_username,
        v_full_name,
        v_role_code
    FROM rebec_cobol.app_user u
    JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.username = p_username
      AND u.user_status = 'active'
      AND u.password_hash = crypt(p_password, u.password_hash)
    LIMIT 1;

    IF v_user_id IS NULL THEN
        INSERT INTO rebec_cobol.app_login_log (
            user_id,
            username_attempt,
            login_success,
            message
        )
        VALUES (
            NULL,
            p_username,
            false,
            'Invalid username, password, or inactive user'
        );

        RETURN QUERY
        SELECT
            false,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            'Invalid username, password, or inactive user'::TEXT;

        RETURN;
    END IF;

    UPDATE rebec_cobol.app_user
    SET last_login_at = now()
    WHERE id = v_user_id;

    INSERT INTO rebec_cobol.app_login_log (
        user_id,
        username_attempt,
        login_success,
        message
    )
    VALUES (
        v_user_id,
        p_username,
        true,
        'Login successful'
    );

    RETURN QUERY
    SELECT
        true,
        v_user_id,
        rebec_cobol.fn_cobol_clean_text(v_username),
        rebec_cobol.fn_cobol_clean_text(v_full_name),
        rebec_cobol.fn_cobol_clean_text(v_role_code),
        'Login successful'::TEXT;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_app_login(TEXT, TEXT)
IS 'Authenticates an application user and returns session data for LOGIN.cbl.';

-- ------------------------------------------------------------
-- Compatibility wrapper for older LOGIN.cbl versions
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS rebec_cobol.app_login(TEXT, TEXT);

CREATE FUNCTION rebec_cobol.app_login(
    p_username TEXT,
    p_password TEXT
)
RETURNS TABLE (
    login_success BOOLEAN,
    user_id INTEGER,
    username TEXT,
    full_name TEXT,
    role_code TEXT,
    message TEXT
)
LANGUAGE sql
VOLATILE
SET search_path TO rebec_cobol, public
AS $$
    SELECT *
    FROM rebec_cobol.fn_app_login(p_username, p_password);
$$;

COMMENT ON FUNCTION rebec_cobol.app_login(TEXT, TEXT)
IS 'Compatibility wrapper. Prefer fn_app_login in new COBOL code.';

-- ============================================================
-- 4. User access request API
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_request_user_access(
    p_full_name TEXT,
    p_email TEXT,
    p_requested_username TEXT,
    p_requested_role TEXT,
    p_request_reason TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    request_id INTEGER,
    message TEXT
)
LANGUAGE plpgsql
VOLATILE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_requested_role TEXT;
    v_request_id INTEGER;
BEGIN
    v_requested_role := lower(btrim(coalesce(p_requested_role, '')));

    IF btrim(coalesce(p_full_name, '')) = '' THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Full name is required'::TEXT;
        RETURN;
    END IF;

    IF btrim(coalesce(p_email, '')) = '' THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Email is required'::TEXT;
        RETURN;
    END IF;

    IF btrim(coalesce(p_requested_username, '')) = '' THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Requested username is required'::TEXT;
        RETURN;
    END IF;

    IF v_requested_role NOT IN ('registrant', 'reviewer') THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Requested role must be registrant or reviewer'::TEXT;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rebec_cobol.app_user u
        WHERE lower(u.username) = lower(btrim(p_requested_username))
           OR lower(u.email) = lower(btrim(p_email))
    ) THEN
        RETURN QUERY
        SELECT false, NULL::INTEGER, 'There is already an application user with this username or email'::TEXT;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rebec_cobol.app_user_request r
        WHERE r.request_status = 'pending'
          AND (
              lower(r.requested_username) = lower(btrim(p_requested_username))
              OR lower(r.email) = lower(btrim(p_email))
          )
    ) THEN
        RETURN QUERY
        SELECT false, NULL::INTEGER, 'There is already a pending request with this username or email'::TEXT;
        RETURN;
    END IF;

    INSERT INTO rebec_cobol.app_user_request (
        full_name,
        email,
        requested_username,
        requested_role,
        request_reason,
        request_status
    )
    VALUES (
        btrim(p_full_name),
        btrim(p_email),
        btrim(p_requested_username),
        v_requested_role,
        coalesce(p_request_reason, ''),
        'pending'
    )
    RETURNING id INTO v_request_id;

    RETURN QUERY
    SELECT
        true,
        v_request_id,
        'Access request created successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_request_user_access(TEXT, TEXT, TEXT, TEXT, TEXT)
IS 'Creates a pending access request for registrant or reviewer accounts.';

-- ------------------------------------------------------------
-- Pending user requests list
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.fn_list_pending_user_requests()
RETURNS TABLE (
    request_id INTEGER,
    full_name TEXT,
    email TEXT,
    requested_username TEXT,
    requested_role TEXT,
    request_reason TEXT,
    created_at TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        rebec_cobol.fn_cobol_clean_text(r.full_name::TEXT),
        rebec_cobol.fn_cobol_clean_text(r.email::TEXT),
        rebec_cobol.fn_cobol_clean_text(r.requested_username::TEXT),
        rebec_cobol.fn_cobol_clean_text(r.requested_role::TEXT),
        rebec_cobol.fn_cobol_clean_text(r.request_reason::TEXT),
        coalesce(to_char(r.created_at, 'YYYY-MM-DD HH24:MI:SS'), '')
    FROM rebec_cobol.app_user_request r
    WHERE r.request_status = 'pending'
    ORDER BY r.created_at, r.id;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_list_pending_user_requests()
IS 'Lists pending user access requests for admin_user_requests.cbl.';

-- ------------------------------------------------------------
-- Approve user request
-- ------------------------------------------------------------
--
-- Implemented as FUNCTION instead of PROCEDURE because COBOL
-- currently consumes SELECT output through psql.
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.sp_approve_user_request(
    p_request_id INTEGER,
    p_admin_user_id INTEGER,
    p_initial_password TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    new_user_id INTEGER,
    message TEXT
)
LANGUAGE plpgsql
VOLATILE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_request rebec_cobol.app_user_request%ROWTYPE;
    v_role_id INTEGER;
    v_new_user_id INTEGER;
    v_admin_role TEXT;
BEGIN
    IF p_request_id IS NULL THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Request ID is required'::TEXT;
        RETURN;
    END IF;

    IF p_admin_user_id IS NULL THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Admin user ID is required'::TEXT;
        RETURN;
    END IF;

    IF btrim(coalesce(p_initial_password, '')) = '' THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Initial password is required'::TEXT;
        RETURN;
    END IF;

    SELECT r.role_code::TEXT
    INTO v_admin_role
    FROM rebec_cobol.app_user u
    JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.id = p_admin_user_id
      AND u.user_status = 'active'
    LIMIT 1;

    IF coalesce(v_admin_role, '') <> 'admin' THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Only active admin users can approve requests'::TEXT;
        RETURN;
    END IF;

    SELECT *
    INTO v_request
    FROM rebec_cobol.app_user_request
    WHERE id = p_request_id
      AND request_status = 'pending'
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Pending request not found'::TEXT;
        RETURN;
    END IF;

    SELECT id
    INTO v_role_id
    FROM rebec_cobol.app_role
    WHERE role_code = v_request.requested_role
      AND is_active = true
    LIMIT 1;

    IF v_role_id IS NULL THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'Requested role is not valid or inactive'::TEXT;
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM rebec_cobol.app_user u
        WHERE lower(u.username) = lower(v_request.requested_username)
           OR lower(u.email) = lower(v_request.email)
    ) THEN
        RETURN QUERY SELECT false, NULL::INTEGER, 'User with same username or email already exists'::TEXT;
        RETURN;
    END IF;

    INSERT INTO rebec_cobol.app_user (
        username,
        password_hash,
        full_name,
        email,
        role_id,
        user_status,
        requested_role,
        request_reason,
        approved_by,
        approved_at
    )
    VALUES (
        v_request.requested_username,
        crypt(p_initial_password, gen_salt('bf')),
        v_request.full_name,
        v_request.email,
        v_role_id,
        'active',
        v_request.requested_role,
        v_request.request_reason,
        p_admin_user_id,
        now()
    )
    RETURNING id INTO v_new_user_id;

    UPDATE rebec_cobol.app_user_request
    SET
        request_status = 'approved',
        reviewed_by = p_admin_user_id,
        reviewed_at = now(),
        review_comment = 'Approved'
    WHERE id = p_request_id;

    RETURN QUERY
    SELECT
        true,
        v_new_user_id,
        'User request approved successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.sp_approve_user_request(INTEGER, INTEGER, TEXT)
IS 'Approves a pending access request and creates an active application user.';

-- ------------------------------------------------------------
-- Reject user request
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION rebec_cobol.sp_reject_user_request(
    p_request_id INTEGER,
    p_admin_user_id INTEGER,
    p_review_comment TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
VOLATILE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_admin_role TEXT;
BEGIN
    IF p_request_id IS NULL THEN
        RETURN QUERY SELECT false, 'Request ID is required'::TEXT;
        RETURN;
    END IF;

    IF p_admin_user_id IS NULL THEN
        RETURN QUERY SELECT false, 'Admin user ID is required'::TEXT;
        RETURN;
    END IF;

    SELECT r.role_code::TEXT
    INTO v_admin_role
    FROM rebec_cobol.app_user u
    JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.id = p_admin_user_id
      AND u.user_status = 'active'
    LIMIT 1;

    IF coalesce(v_admin_role, '') <> 'admin' THEN
        RETURN QUERY SELECT false, 'Only active admin users can reject requests'::TEXT;
        RETURN;
    END IF;

    UPDATE rebec_cobol.app_user_request
    SET
        request_status = 'rejected',
        reviewed_by = p_admin_user_id,
        reviewed_at = now(),
        review_comment = coalesce(p_review_comment, '')
    WHERE id = p_request_id
      AND request_status = 'pending';

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Pending request not found'::TEXT;
        RETURN;
    END IF;

    RETURN QUERY SELECT true, 'User request rejected successfully'::TEXT;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.sp_reject_user_request(INTEGER, INTEGER, TEXT)
IS 'Rejects a pending access request.';

-- ============================================================
-- 5. Active users API
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_list_active_users()
RETURNS TABLE (
    user_id INTEGER,
    username TEXT,
    full_name TEXT,
    email TEXT,
    role_code TEXT,
    user_status TEXT,
    created_at TEXT,
    last_login_at TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id,
        rebec_cobol.fn_cobol_clean_text(u.username::TEXT),
        rebec_cobol.fn_cobol_clean_text(u.full_name::TEXT),
        rebec_cobol.fn_cobol_clean_text(u.email::TEXT),
        rebec_cobol.fn_cobol_clean_text(r.role_code::TEXT),
        rebec_cobol.fn_cobol_clean_text(u.user_status::TEXT),
        coalesce(to_char(u.created_at, 'YYYY-MM-DD HH24:MI:SS'), ''),
        coalesce(to_char(u.last_login_at, 'YYYY-MM-DD HH24:MI:SS'), '')
    FROM rebec_cobol.app_user u
    LEFT JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.user_status = 'active'
    ORDER BY u.username;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_list_active_users()
IS 'Lists active application users for future admin screens.';

-- ============================================================
-- End of database API layer
-- ============================================================

