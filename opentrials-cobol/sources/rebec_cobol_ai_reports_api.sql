-- ============================================================
-- ReBEC COBOL - AI Reports API
-- ============================================================
--
-- Purpose:
--   Build consolidated JSON datasets for AI-generated strategic
--   reports about the clinical trials registry.
--
-- Principle:
--   PostgreSQL performs aggregation, counting, ranking and local
--   analytical preparation.
--
--   AI receives only consolidated indicators, rankings, trends and
--   selected examples, not the full raw database.
--
-- Schema:
--   rebec_cobol
--
-- ============================================================

SET search_path TO rebec_cobol, public;


-- ============================================================
-- 1. Dashboard dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_registry_dashboard_json()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    SELECT jsonb_build_object(
        'total_trials',
            (SELECT count(*) FROM rebec_cobol.trial),

        'public_trials',
            (SELECT count(*)
             FROM rebec_cobol.trial
             WHERE status IN ('approved', 'published')),

        'published_trials',
            (SELECT count(*)
             FROM rebec_cobol.trial
             WHERE status = 'published'),

        'approved_trials',
            (SELECT count(*)
             FROM rebec_cobol.trial
             WHERE status = 'approved'),

        'registered_this_year',
            (SELECT count(*)
             FROM rebec_cobol.trial
             WHERE date_registration >= date_trunc('year', current_date)::date
               AND date_registration <  (date_trunc('year', current_date) + interval '1 year')::date),

        'registered_this_month',
            (SELECT count(*)
             FROM rebec_cobol.trial
             WHERE date_registration >= date_trunc('month', current_date)::date
               AND date_registration <  (date_trunc('month', current_date) + interval '1 month')::date)
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_registry_dashboard_json()
IS 'Builds executive dashboard indicators for AI strategic reporting.';


-- ============================================================
-- 2. Recruitment freshness dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_recruitment_freshness_json()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH base AS (
        SELECT
            t.id,
            t.trial_id,
            t.public_title,
            t.primary_sponsor,
            t.date_registration,
            t.date_enrolment,
            rs.code AS recruitment_status_code,
            rs.xml_value AS recruitment_status_label,
            CASE
                WHEN t.date_enrolment IS NULL THEN NULL
                ELSE (
                    extract(year from age(current_date, t.date_enrolment))::integer * 12
                    +
                    extract(month from age(current_date, t.date_enrolment))::integer
                )
            END AS months_since_enrolment
        FROM rebec_cobol.trial t
        JOIN rebec_cobol.vocab_recruitment_status rs
            ON rs.id = t.recruitment_status_id
        WHERE t.status IN ('approved', 'published')
    ),
    flagged AS (
        SELECT *
        FROM base
        WHERE recruitment_status_code IN ('recruiting', 'not_yet_recruiting')
          AND date_enrolment IS NOT NULL
          AND date_enrolment <= (current_date - interval '12 months')::date
    ),
    risk_bands AS (
        SELECT
            CASE
                WHEN months_since_enrolment BETWEEN 12 AND 23 THEN '12_23_months'
                WHEN months_since_enrolment BETWEEN 24 AND 35 THEN '24_35_months'
                WHEN months_since_enrolment >= 36 THEN '36_plus_months'
                ELSE 'other'
            END AS risk_band,
            count(*) AS total
        FROM flagged
        GROUP BY 1
    ),
    by_status AS (
        SELECT
            recruitment_status_label,
            count(*) AS total
        FROM base
        GROUP BY recruitment_status_label
        ORDER BY total DESC
    ),
    top_flagged_sponsors AS (
        SELECT
            coalesce(nullif(trim(primary_sponsor), ''), 'Unknown') AS sponsor,
            count(*) AS possibly_outdated_trials
        FROM flagged
        GROUP BY 1
        ORDER BY count(*) DESC
        LIMIT 20
    ),
    oldest_examples AS (
        SELECT
            id,
            trial_id,
            left(coalesce(public_title, ''), 180) AS public_title,
            coalesce(primary_sponsor, 'Unknown') AS primary_sponsor,
            recruitment_status_label,
            date_enrolment,
            months_since_enrolment
        FROM flagged
        ORDER BY months_since_enrolment DESC NULLS LAST, id
        LIMIT 15
    )
    SELECT jsonb_build_object(
        'definition',
            'Trials are flagged as possibly outdated when recruitment status is Recruiting or Not yet recruiting and date_enrolment is older than 12 months.',

        'possibly_outdated_total',
            (SELECT count(*) FROM flagged),

        'recruitment_status_distribution',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(s) ORDER BY s.total DESC)
                 FROM by_status s),
                '[]'::jsonb
            ),

        'risk_bands',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(rb) ORDER BY rb.risk_band)
                 FROM risk_bands rb),
                '[]'::jsonb
            ),

        'top_flagged_sponsors',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(tfs) ORDER BY tfs.possibly_outdated_trials DESC)
                 FROM top_flagged_sponsors tfs),
                '[]'::jsonb
            ),

        'oldest_examples',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(oe) ORDER BY oe.months_since_enrolment DESC)
                 FROM oldest_examples oe),
                '[]'::jsonb
            )
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_recruitment_freshness_json()
IS 'Builds recruitment status freshness indicators and examples for AI strategic reporting.';


-- ============================================================
-- 3. Top sponsors dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_top_sponsors_json(
    p_limit INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH base AS (
        SELECT
            coalesce(nullif(trim(t.primary_sponsor), ''), 'Unknown') AS sponsor,
            t.id,
            t.date_registration,
            st.xml_value AS study_type,
            ph.xml_value AS phase,
            rs.code AS recruitment_status_code,
            rs.xml_value AS recruitment_status_label,
            CASE
                WHEN rs.code IN ('recruiting', 'not_yet_recruiting')
                 AND t.date_enrolment IS NOT NULL
                 AND t.date_enrolment <= (current_date - interval '12 months')::date
                THEN 1 ELSE 0
            END AS possibly_outdated
        FROM rebec_cobol.trial t
        LEFT JOIN rebec_cobol.vocab_study_type st
            ON st.id = t.study_type_id
        LEFT JOIN rebec_cobol.vocab_phase ph
            ON ph.id = t.phase_id
        LEFT JOIN rebec_cobol.vocab_recruitment_status rs
            ON rs.id = t.recruitment_status_id
        WHERE t.status IN ('approved', 'published')
    ),
    sponsors AS (
        SELECT
            sponsor,
            count(*) AS total_trials,
            round(
                (count(*)::numeric / nullif((SELECT count(*) FROM base), 0)) * 100,
                2
            ) AS percentage,
            sum(possibly_outdated)::integer AS possibly_outdated_trials,
            count(*) FILTER (
                WHERE date_registration >= (current_date - interval '12 months')::date
            ) AS last_12_months_trials,
            count(*) FILTER (
                WHERE lower(coalesce(study_type, '')) = 'intervention'
            ) AS interventional_trials,
            count(*) FILTER (
                WHERE lower(coalesce(study_type, '')) = 'observational'
            ) AS observational_trials
        FROM base
        GROUP BY sponsor
        ORDER BY count(*) DESC
        LIMIT greatest(coalesce(p_limit, 30), 1)
    )
    SELECT coalesce(
        jsonb_agg(to_jsonb(s) ORDER BY s.total_trials DESC),
        '[]'::jsonb
    )
    FROM sponsors s;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_top_sponsors_json(INTEGER)
IS 'Builds top sponsor indicators for AI strategic reporting.';


-- ============================================================
-- 4. Top health conditions dataset
-- ============================================================
--
-- Current source:
--   trial.hc_freetext
--
-- This version consolidates terms by normalized lowercase key
-- to avoid duplicates such as:
--   Obesity / obesity
--   Dental caries / Dental Caries
--
-- Later improvement:
--   Map terms to DeCS, MeSH or ICD categories locally before AI.
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_top_health_conditions_json(
    p_limit INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH raw_conditions AS (
        SELECT
            t.id,
            t.date_registration,
            rs.code AS recruitment_status_code,
            t.date_enrolment,
            trim(regexp_replace(condition_item, '\s+', ' ', 'g')) AS condition_name
        FROM rebec_cobol.trial t
        LEFT JOIN rebec_cobol.vocab_recruitment_status rs
            ON rs.id = t.recruitment_status_id
        CROSS JOIN LATERAL regexp_split_to_table(
            coalesce(t.hc_freetext, ''),
            '\s*;\s*|\s*\|\s*|\s*,\s*'
        ) AS condition_item
        WHERE t.status IN ('approved', 'published')
          AND coalesce(t.hc_freetext, '') <> ''
    ),
    cleaned AS (
        SELECT
            id,
            date_registration,
            recruitment_status_code,
            date_enrolment,
            lower(trim(condition_name)) AS condition_key,
            initcap(lower(trim(condition_name))) AS condition_name,
            CASE
                WHEN recruitment_status_code IN ('recruiting', 'not_yet_recruiting')
                 AND date_enrolment IS NOT NULL
                 AND date_enrolment <= (current_date - interval '12 months')::date
                THEN 1 ELSE 0
            END AS possibly_outdated
        FROM raw_conditions
        WHERE condition_name <> ''
          AND length(condition_name) >= 3
          AND lower(trim(condition_name)) NOT IN (
              'unspecified',
              'not informed',
              'not specified',
              'unknown',
              'n/a',
              'na',
              'none'
          )
    ),
    ranked AS (
        SELECT
            condition_key,
            min(condition_name) AS condition_name,
            count(DISTINCT id) AS total_trials,
            sum(possibly_outdated)::integer AS possibly_outdated_trials,
            count(DISTINCT id) FILTER (
                WHERE date_registration >= (current_date - interval '12 months')::date
            ) AS last_12_months_trials
        FROM cleaned
        GROUP BY condition_key
        ORDER BY count(DISTINCT id) DESC
        LIMIT greatest(coalesce(p_limit, 30), 1)
    )
    SELECT coalesce(
        jsonb_agg(to_jsonb(r) ORDER BY r.total_trials DESC),
        '[]'::jsonb
    )
    FROM ranked r;
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_top_health_conditions_json(INTEGER)
IS 'Builds top health condition indicators from hc_freetext for AI strategic reporting.';


-- ============================================================
-- 5. Study profile dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_study_profile_json()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH study_type_rows AS (
        SELECT
            coalesce(st.xml_value, 'Unknown') AS study_type,
            count(*) AS total_trials
        FROM rebec_cobol.trial t
        LEFT JOIN rebec_cobol.vocab_study_type st
            ON st.id = t.study_type_id
        WHERE t.status IN ('approved', 'published')
        GROUP BY 1
        ORDER BY count(*) DESC
    ),
    phase_rows AS (
        SELECT
            coalesce(ph.xml_value, 'Unknown') AS phase,
            count(*) AS total_trials
        FROM rebec_cobol.trial t
        LEFT JOIN rebec_cobol.vocab_phase ph
            ON ph.id = t.phase_id
        WHERE t.status IN ('approved', 'published')
        GROUP BY 1
        ORDER BY count(*) DESC
    )
    SELECT jsonb_build_object(
        'study_type_distribution',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(str) ORDER BY str.total_trials DESC)
                 FROM study_type_rows str),
                '[]'::jsonb
            ),
        'phase_distribution',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(pr) ORDER BY pr.total_trials DESC)
                 FROM phase_rows pr),
                '[]'::jsonb
            )
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_study_profile_json()
IS 'Builds study type and phase distribution indicators for AI strategic reporting.';


-- ============================================================
-- 6. Temporal trends dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_temporal_trends_json()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH by_year AS (
        SELECT
            extract(year from date_registration)::integer AS year,
            count(*) AS total_trials
        FROM rebec_cobol.trial
        WHERE status IN ('approved', 'published')
          AND date_registration IS NOT NULL
        GROUP BY 1
        ORDER BY 1
    ),
    last_24_months AS (
        SELECT
            to_char(date_trunc('month', date_registration), 'YYYY-MM') AS month,
            count(*) AS total_trials
        FROM rebec_cobol.trial
        WHERE status IN ('approved', 'published')
          AND date_registration >= (date_trunc('month', current_date) - interval '23 months')::date
          AND date_registration IS NOT NULL
        GROUP BY 1
        ORDER BY 1
    )
    SELECT jsonb_build_object(
        'trials_by_year',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(y) ORDER BY y.year)
                 FROM by_year y),
                '[]'::jsonb
            ),
        'trials_last_24_months',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(m) ORDER BY m.month)
                 FROM last_24_months m),
                '[]'::jsonb
            )
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_temporal_trends_json()
IS 'Builds temporal trend indicators for AI strategic reporting.';


-- ============================================================
-- 7. Data quality dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_data_quality_json()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH base AS (
        SELECT *
        FROM rebec_cobol.trial
        WHERE status IN ('approved', 'published')
    ),
    missing_fields AS (
        SELECT 'public_title' AS field_name, count(*) AS missing_count
        FROM base
        WHERE coalesce(trim(public_title), '') = ''

        UNION ALL

        SELECT 'scientific_title', count(*)
        FROM base
        WHERE coalesce(trim(scientific_title), '') = ''

        UNION ALL

        SELECT 'primary_sponsor', count(*)
        FROM base
        WHERE coalesce(trim(primary_sponsor), '') = ''

        UNION ALL

        SELECT 'date_registration', count(*)
        FROM base
        WHERE date_registration IS NULL

        UNION ALL

        SELECT 'date_enrolment', count(*)
        FROM base
        WHERE date_enrolment IS NULL

        UNION ALL

        SELECT 'target_size', count(*)
        FROM base
        WHERE target_size IS NULL

        UNION ALL

        SELECT 'study_type_id', count(*)
        FROM base
        WHERE study_type_id IS NULL

        UNION ALL

        SELECT 'phase_id', count(*)
        FROM base
        WHERE phase_id IS NULL

        UNION ALL

        SELECT 'recruitment_status_id', count(*)
        FROM base
        WHERE recruitment_status_id IS NULL

        UNION ALL

        SELECT 'hc_freetext', count(*)
        FROM base
        WHERE coalesce(trim(hc_freetext), '') = ''

        UNION ALL

        SELECT 'url', count(*)
        FROM base
        WHERE coalesce(trim(url), '') = ''
    ),
    date_issues AS (
        SELECT
            count(*) FILTER (
                WHERE date_registration IS NOT NULL
                  AND date_enrolment IS NOT NULL
                  AND date_enrolment < date_registration
            ) AS enrolment_before_registration,

            count(*) FILTER (
                WHERE date_registration > current_date
            ) AS future_registration_date,

            count(*) FILTER (
                WHERE date_enrolment > current_date
            ) AS future_enrolment_date
        FROM base
    )
    SELECT jsonb_build_object(
        'missing_fields',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(mf) ORDER BY mf.missing_count DESC)
                 FROM missing_fields mf),
                '[]'::jsonb
            ),

        'date_issues',
            (SELECT to_jsonb(di) FROM date_issues di),

        'interpretation_note',
            'Missing fields and date issues are calculated locally. AI should interpret these as data governance and data quality indicators, not as clinical conclusions.'
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_data_quality_json()
IS 'Builds data quality and governance indicators for AI strategic reporting.';


-- ============================================================
-- 8. Sponsor x health condition intelligence dataset
-- ============================================================
--
-- Purpose:
--   Identify concentration of research activity by sponsor and
--   the most relevant health conditions.
--
-- Important design choice:
--   This function does NOT use every raw condition extracted from
--   hc_freetext. It first builds a controlled set of the top health
--   conditions and only then crosses those conditions with sponsors.
--
-- This avoids sending noisy one-off terms and long free-text fragments
-- to the AI report.
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_sponsor_health_condition_dataset(
    p_limit INTEGER DEFAULT 50
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    WITH raw_conditions AS (
        SELECT
            t.id,
            t.trial_id,
            coalesce(nullif(trim(t.primary_sponsor), ''), 'Unknown') AS sponsor,
            t.date_registration,
            t.date_enrolment,
            rs.code AS recruitment_status_code,
            rs.xml_value AS recruitment_status_label,
            trim(regexp_replace(condition_item, '\s+', ' ', 'g')) AS condition_name
        FROM rebec_cobol.trial t
        LEFT JOIN rebec_cobol.vocab_recruitment_status rs
            ON rs.id = t.recruitment_status_id
        CROSS JOIN LATERAL regexp_split_to_table(
            coalesce(t.hc_freetext, ''),
            '\s*;\s*|\s*\|\s*|\s*,\s*'
        ) AS condition_item
        WHERE t.status IN ('approved', 'published')
          AND coalesce(t.hc_freetext, '') <> ''
    ),

    cleaned AS (
        SELECT
            id,
            trial_id,
            sponsor,
            date_registration,
            date_enrolment,
            recruitment_status_code,
            recruitment_status_label,
            lower(trim(regexp_replace(condition_name, '[\.;:]+$', '', 'g'))) AS condition_key,
            initcap(lower(trim(regexp_replace(condition_name, '[\.;:]+$', '', 'g')))) AS condition_name,
            CASE
                WHEN recruitment_status_code IN ('recruiting', 'not_yet_recruiting')
                 AND date_enrolment IS NOT NULL
                 AND date_enrolment <= (current_date - interval '12 months')::date
                THEN true ELSE false
            END AS possibly_outdated
        FROM raw_conditions
        WHERE condition_name <> ''
          AND length(condition_name) BETWEEN 3 AND 80
          AND lower(trim(condition_name)) NOT IN (
              'unspecified',
              'not informed',
              'not specified',
              'unknown',
              'n/a',
              'na',
              'none',
              'array',
              'other'
          )
          AND lower(trim(condition_name)) !~ '^[0-9\.\-\s]+$'
          AND lower(trim(condition_name)) !~ '^(and|or|with|without|according|after|before|during|all data)'
    ),

    top_conditions AS (
        SELECT
            condition_key,
            min(condition_name) AS condition_name,
            count(DISTINCT id) AS total_trials
        FROM cleaned
        GROUP BY condition_key
        HAVING count(DISTINCT id) >= 20
        ORDER BY count(DISTINCT id) DESC
        LIMIT 30
    ),

    focused AS (
        SELECT c.*
        FROM cleaned c
        JOIN top_conditions tc
            ON tc.condition_key = c.condition_key
    ),

    sponsor_condition AS (
        SELECT
            sponsor,
            condition_key,
            min(condition_name) AS condition_name,
            count(DISTINCT id) AS total_trials,
            count(DISTINCT id) FILTER (
                WHERE possibly_outdated = true
            ) AS possibly_outdated_trials,
            count(DISTINCT id) FILTER (
                WHERE date_registration >= (current_date - interval '12 months')::date
            ) AS last_12_months_trials
        FROM focused
        GROUP BY sponsor, condition_key
        HAVING count(DISTINCT id) >= 3
        ORDER BY count(DISTINCT id) DESC
        LIMIT greatest(coalesce(p_limit, 50), 1)
    ),

    sponsor_top_conditions_grouped AS (
        SELECT
            sponsor,
            condition_key,
            min(condition_name) AS condition_name,
            count(DISTINCT id) AS total_trials,
            count(DISTINCT id) FILTER (
                WHERE possibly_outdated = true
            ) AS possibly_outdated_trials
        FROM focused
        GROUP BY sponsor, condition_key
        HAVING count(DISTINCT id) >= 3
    ),

    sponsor_top_conditions AS (
        SELECT
            sponsor,
            condition_key,
            condition_name,
            total_trials,
            possibly_outdated_trials,
            row_number() OVER (
                PARTITION BY sponsor
                ORDER BY total_trials DESC, condition_name
            ) AS rn
        FROM sponsor_top_conditions_grouped
    ),

    condition_top_sponsors_grouped AS (
        SELECT
            condition_key,
            min(condition_name) AS condition_name,
            sponsor,
            count(DISTINCT id) AS total_trials,
            count(DISTINCT id) FILTER (
                WHERE possibly_outdated = true
            ) AS possibly_outdated_trials
        FROM focused
        GROUP BY condition_key, sponsor
        HAVING count(DISTINCT id) >= 3
    ),

    condition_top_sponsors AS (
        SELECT
            condition_key,
            condition_name,
            sponsor,
            total_trials,
            possibly_outdated_trials,
            row_number() OVER (
                PARTITION BY condition_key
                ORDER BY total_trials DESC, sponsor
            ) AS rn
        FROM condition_top_sponsors_grouped
    ),

    condition_concentration AS (
        SELECT
            f.condition_key,
            min(f.condition_name) AS condition_name,
            count(DISTINCT f.id) AS total_trials,
            count(DISTINCT f.sponsor) AS unique_sponsors,
            round(
                count(DISTINCT f.id)::numeric
                / nullif(count(DISTINCT f.sponsor), 0),
                2
            ) AS avg_trials_per_sponsor
        FROM focused f
        GROUP BY f.condition_key
        ORDER BY count(DISTINCT f.id) DESC
    ),

    sponsor_outdated_burden AS (
        SELECT
            sponsor,
            count(DISTINCT id) AS total_trials_in_top_conditions,
            count(DISTINCT id) FILTER (
                WHERE possibly_outdated = true
            ) AS possibly_outdated_trials,
            round(
                (
                    count(DISTINCT id) FILTER (WHERE possibly_outdated = true)
                )::numeric
                / nullif(count(DISTINCT id), 0)
                * 100,
                2
            ) AS possibly_outdated_percentage
        FROM focused
        GROUP BY sponsor
        HAVING count(DISTINCT id) >= 10
        ORDER BY possibly_outdated_percentage DESC, possibly_outdated_trials DESC
        LIMIT 30
    )

    SELECT jsonb_build_object(
        'description',
            'Sponsor by health condition dataset focused on the top health conditions only. This reduces free-text noise and supports strategic analysis of sponsor footprint, therapeutic concentration and data freshness risks.',

        'filtering_strategy',
            jsonb_build_object(
                'source', 'trial.hc_freetext',
                'minimum_total_trials_for_condition', 20,
                'maximum_number_of_conditions', 30,
                'minimum_trials_for_sponsor_condition_pair', 3,
                'excluded_terms', jsonb_build_array(
                    'unspecified',
                    'not informed',
                    'not specified',
                    'unknown',
                    'n/a',
                    'array',
                    'other',
                    'numeric-only fragments',
                    'long free-text fragments'
                )
            ),

        'top_conditions_used',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(tc) ORDER BY tc.total_trials DESC)
                 FROM top_conditions tc),
                '[]'::jsonb
            ),

        'top_sponsor_condition_combinations',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(sc) ORDER BY sc.total_trials DESC)
                 FROM sponsor_condition sc),
                '[]'::jsonb
            ),

        'sponsor_top_conditions',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(stc) ORDER BY stc.sponsor, stc.rn)
                 FROM sponsor_top_conditions stc
                 WHERE stc.rn <= 5),
                '[]'::jsonb
            ),

        'condition_top_sponsors',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(cts) ORDER BY cts.condition_name, cts.rn)
                 FROM condition_top_sponsors cts
                 WHERE cts.rn <= 5),
                '[]'::jsonb
            ),

        'condition_concentration',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(cc) ORDER BY cc.total_trials DESC)
                 FROM condition_concentration cc),
                '[]'::jsonb
            ),

        'sponsor_outdated_burden',
            coalesce(
                (SELECT jsonb_agg(to_jsonb(sob) ORDER BY sob.possibly_outdated_percentage DESC)
                 FROM sponsor_outdated_burden sob),
                '[]'::jsonb
            )
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_sponsor_health_condition_dataset(INTEGER)
IS 'Builds a focused JSON dataset crossing sponsors and top health conditions for AI strategic reporting.';


-- ============================================================
-- 9. Main AI insight dataset
-- ============================================================

CREATE OR REPLACE FUNCTION rebec_cobol.fn_ai_registry_insight_dataset()
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path TO rebec_cobol, public
AS $$
    SELECT jsonb_build_object(
        'metadata',
            jsonb_build_object(
                'generated_at', now(),
                'database', 'rebec_cobol',
                'schema', 'rebec_cobol',
                'dataset_scope', 'public clinical trials registry data',
                'ai_usage_note', 'This dataset contains aggregated indicators, rankings and selected non-sensitive examples. It should be interpreted by AI without inventing additional numbers.'
            ),

        'executive_dashboard',
            rebec_cobol.fn_ai_registry_dashboard_json(),

        'recruitment_freshness',
            rebec_cobol.fn_ai_recruitment_freshness_json(),

        'top_sponsors',
            rebec_cobol.fn_ai_top_sponsors_json(30),

        'top_health_conditions',
            rebec_cobol.fn_ai_top_health_conditions_json(30),

        'study_profile',
            rebec_cobol.fn_ai_study_profile_json(),

        'temporal_trends',
            rebec_cobol.fn_ai_temporal_trends_json(),

        'data_quality_governance',
            rebec_cobol.fn_ai_data_quality_json(),

        'sponsor_health_condition_intelligence',
            rebec_cobol.fn_ai_sponsor_health_condition_dataset(50)
    );
$$;

COMMENT ON FUNCTION rebec_cobol.fn_ai_registry_insight_dataset()
IS 'Builds a consolidated JSON dataset for AI-generated strategic registry insights.';


-- ============================================================
-- End of AI Reports API
-- ============================================================
