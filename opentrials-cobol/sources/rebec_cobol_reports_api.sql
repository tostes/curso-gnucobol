-- ============================================================
-- ReBEC COBOL - Reports API
-- ============================================================
--
-- Purpose:
--   Reporting layer for the COBOL terminal application.
--
-- Architectural rule:
--   COBOL calls report functions.
--   PostgreSQL calculates report data.
--
-- Schema:
--   rebec_cobol
--
-- ============================================================

SET search_path TO rebec_cobol, public;

-- ============================================================
-- 1. Report: registry dashboard
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_registry_dashboard()
RETURNS TABLE (
    metric_code TEXT,
    metric_label TEXT,
    metric_value TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        'total_trials'::TEXT,
        'Total trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial

    UNION ALL

    SELECT
        'published_trials'::TEXT,
        'Published trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial
    WHERE status = 'published'

    UNION ALL

    SELECT
        'approved_trials'::TEXT,
        'Approved trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial
    WHERE status = 'approved'

    UNION ALL

    SELECT
        'public_trials'::TEXT,
        'Public trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial
    WHERE status IN ('approved', 'published')

    UNION ALL

    SELECT
        'recruiting_trials'::TEXT,
        'Recruiting trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial t
    JOIN rebec_cobol.vocab_recruitment_status rs
        ON rs.id = t.recruitment_status_id
    WHERE t.status IN ('approved', 'published')
      AND rs.code = 'recruiting'

    UNION ALL

    SELECT
        'not_yet_recruiting_trials'::TEXT,
        'Not yet recruiting trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial t
    JOIN rebec_cobol.vocab_recruitment_status rs
        ON rs.id = t.recruitment_status_id
    WHERE t.status IN ('approved', 'published')
      AND rs.code = 'not_yet_recruiting'

    UNION ALL

    SELECT
        'possibly_outdated_recruitment_trials'::TEXT,
        'Possibly outdated recruitment trials'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial t
    JOIN rebec_cobol.vocab_recruitment_status rs
        ON rs.id = t.recruitment_status_id
    WHERE t.status IN ('approved', 'published')
      AND rs.code IN ('not_yet_recruiting', 'recruiting')
      AND t.date_enrolment IS NOT NULL
      AND t.date_enrolment <= (current_date - interval '12 months')::date

    UNION ALL

    SELECT
        'pending_user_requests'::TEXT,
        'Pending user requests'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.app_user_request
    WHERE request_status = 'pending'

    UNION ALL

    SELECT
        'active_registrants'::TEXT,
        'Active registrants'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.app_user u
    JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.user_status = 'active'
      AND r.role_code = 'registrant'

    UNION ALL

    SELECT
        'active_reviewers'::TEXT,
        'Active reviewers'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.app_user u
    JOIN rebec_cobol.app_role r
        ON r.id = u.role_id
    WHERE u.user_status = 'active'
      AND r.role_code = 'reviewer'

    UNION ALL

    SELECT
        'registered_this_month'::TEXT,
        'Trials registered this month'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial
    WHERE date_registration >= date_trunc('month', current_date)::date
      AND date_registration < (date_trunc('month', current_date) + interval '1 month')::date

    UNION ALL

    SELECT
        'registered_this_year'::TEXT,
        'Trials registered this year'::TEXT,
        count(*)::TEXT
    FROM rebec_cobol.trial
    WHERE date_registration >= date_trunc('year', current_date)::date
      AND date_registration < (date_trunc('year', current_date) + interval '1 year')::date;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_registry_dashboard()
IS 'Executive dashboard report for registry management.';


-- ============================================================
-- 2. Report: trials by recruitment status
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_trials_by_recruitment_status()
RETURNS TABLE (
    recruitment_status_code TEXT,
    recruitment_status_label TEXT,
    total_trials INTEGER,
    percentage NUMERIC(10,2)
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT count(*)::NUMERIC
    INTO v_total
    FROM rebec_cobol.trial
    WHERE status IN ('approved', 'published');

    RETURN QUERY
    SELECT
        rs.code::TEXT AS recruitment_status_code,
        rs.xml_value::TEXT AS recruitment_status_label,
        count(t.id)::INTEGER AS total_trials,
        CASE
            WHEN coalesce(v_total, 0) = 0 THEN 0::NUMERIC(10,2)
            ELSE round((count(t.id)::NUMERIC / v_total) * 100, 2)
        END AS percentage
    FROM rebec_cobol.vocab_recruitment_status rs
    LEFT JOIN rebec_cobol.trial t
        ON t.recruitment_status_id = rs.id
       AND t.status IN ('approved', 'published')
    WHERE rs.is_active = true
    GROUP BY
        rs.code,
        rs.xml_value,
        rs.sort_order
    ORDER BY
        rs.sort_order,
        rs.xml_value;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_trials_by_recruitment_status()
IS 'Counts public trials by recruitment status.';


-- ============================================================
-- 3. Report: possibly outdated recruitment trials
-- ============================================================
--
-- Business rule:
--
-- A trial is flagged as Possibly outdated when:
--
--   1. The trial is public:
--        status IN ('approved', 'published')
--
--   2. Recruitment status is still active or expected:
--        recruitment status IN ('Recruiting', 'Not yet recruiting')
--
--   3. The enrolment date is older than 12 months:
--        date_enrolment <= current_date - 12 months
--
-- Interpretation:
--
--   These trials may require follow-up because they still appear
--   as recruiting or not yet recruiting even though the enrolment
--   reference date is more than 12 months old.
--
-- COBOL consumer:
--   future reports_menu.cbl
--
-- Example:
--   SELECT * FROM rebec_cobol.fn_report_possibly_outdated_recruitment_trials(20, 0);
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_possibly_outdated_recruitment_trials(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    trial_id TEXT,
    status TEXT,
    recruitment_status TEXT,
    registration_date TEXT,
    enrolment_date TEXT,
    months_since_enrolment INTEGER,
    flag TEXT,
    public_title TEXT,
    primary_sponsor TEXT
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        rebec_cobol.fn_cobol_clean_text(t.trial_id::TEXT) AS trial_id,
        rebec_cobol.fn_cobol_clean_text(t.status::TEXT) AS status,
        rebec_cobol.fn_cobol_clean_text(rs.xml_value::TEXT) AS recruitment_status,
        coalesce(t.date_registration::TEXT, '') AS registration_date,
        coalesce(t.date_enrolment::TEXT, '') AS enrolment_date,
        (
            extract(year from age(current_date, t.date_enrolment))::INTEGER * 12
            +
            extract(month from age(current_date, t.date_enrolment))::INTEGER
        ) AS months_since_enrolment,
        'Possibly outdated'::TEXT AS flag,
        rebec_cobol.fn_cobol_clean_text(t.public_title::TEXT) AS public_title,
        rebec_cobol.fn_cobol_clean_text(t.primary_sponsor::TEXT) AS primary_sponsor
    FROM rebec_cobol.trial t
    JOIN rebec_cobol.vocab_recruitment_status rs
        ON rs.id = t.recruitment_status_id
    WHERE t.status IN ('approved', 'published')
      AND rs.code IN ('not_yet_recruiting', 'recruiting')
      AND t.date_enrolment IS NOT NULL
      AND t.date_enrolment <= (current_date - interval '12 months')::date
    ORDER BY
        t.date_enrolment ASC,
        t.id
    LIMIT greatest(coalesce(p_limit, 50), 1)
    OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_possibly_outdated_recruitment_trials(INTEGER, INTEGER)
IS 'Lists public recruiting or not-yet-recruiting trials whose enrolment date is older than 12 months and flags them as Possibly outdated.';


-- ============================================================
-- 4. Report: count of possibly outdated recruitment trials
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_possibly_outdated_recruitment_count()
RETURNS TABLE (
    total_trials INTEGER
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        count(*)::INTEGER
    FROM rebec_cobol.trial t
    JOIN rebec_cobol.vocab_recruitment_status rs
        ON rs.id = t.recruitment_status_id
    WHERE t.status IN ('approved', 'published')
      AND rs.code IN ('not_yet_recruiting', 'recruiting')
      AND t.date_enrolment IS NOT NULL
      AND t.date_enrolment <= (current_date - interval '12 months')::date;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_possibly_outdated_recruitment_count()
IS 'Counts public recruiting or not-yet-recruiting trials whose enrolment date is older than 12 months.';


-- ============================================================
-- 5. Report: trials by study type
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_trials_by_study_type()
RETURNS TABLE (
    study_type_code TEXT,
    study_type_label TEXT,
    total_trials INTEGER,
    percentage NUMERIC(10,2)
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT count(*)::NUMERIC
    INTO v_total
    FROM rebec_cobol.trial
    WHERE status IN ('approved', 'published');

    RETURN QUERY
    SELECT
        st.code::TEXT,
        st.xml_value::TEXT,
        count(t.id)::INTEGER,
        CASE
            WHEN coalesce(v_total, 0) = 0 THEN 0::NUMERIC(10,2)
            ELSE round((count(t.id)::NUMERIC / v_total) * 100, 2)
        END
    FROM rebec_cobol.vocab_study_type st
    LEFT JOIN rebec_cobol.trial t
        ON t.study_type_id = st.id
       AND t.status IN ('approved', 'published')
    WHERE st.is_active = true
    GROUP BY
        st.code,
        st.xml_value,
        st.sort_order
    ORDER BY
        st.sort_order,
        st.xml_value;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_trials_by_study_type()
IS 'Counts public trials by study type.';


-- ============================================================
-- 6. Report: trials by public status
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_report_trials_by_status()
RETURNS TABLE (
    status_code TEXT,
    total_trials INTEGER,
    percentage NUMERIC(10,2)
)
LANGUAGE plpgsql
STABLE
SET search_path TO rebec_cobol, public
AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT count(*)::NUMERIC
    INTO v_total
    FROM rebec_cobol.trial;

    RETURN QUERY
    SELECT
        t.status::TEXT,
        count(*)::INTEGER,
        CASE
            WHEN coalesce(v_total, 0) = 0 THEN 0::NUMERIC(10,2)
            ELSE round((count(*)::NUMERIC / v_total) * 100, 2)
        END
    FROM rebec_cobol.trial t
    GROUP BY t.status
    ORDER BY count(*) DESC, t.status;
END;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_report_trials_by_status()
IS 'Counts all trials by internal status.';


-- ============================================================
-- End of Reports API
-- ============================================================
