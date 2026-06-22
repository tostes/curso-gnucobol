-- ============================================================
-- ReBEC COBOL - Simplified PostgreSQL Schema for ICTRP XML
-- Version: 0.1
-- Language: English-only data entry
-- Purpose: visualization, insertion, review/approval and XML export
-- ============================================================

BEGIN;

-- Optional: keep everything inside a dedicated schema
CREATE SCHEMA IF NOT EXISTS rebec_cobol;
SET search_path TO rebec_cobol;

-- ============================================================
-- 1. Domain helpers
-- ============================================================

-- Current workflow status of a trial
CREATE TABLE IF NOT EXISTS vocab_trial_status (
    code VARCHAR(30) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_trial_status (code, label, sort_order) VALUES
('draft', 'Draft', 10),
('submitted', 'Submitted', 20),
('under_review', 'Under review', 30),
('returned', 'Returned to registrant', 40),
('approved', 'Approved', 50),
('rejected', 'Rejected', 60),
('published', 'Published', 70)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_contact_type (
    code VARCHAR(30) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_contact_type (code, label, sort_order) VALUES
('public', 'Public contact', 10),
('scientific', 'Scientific contact', 20)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_gender (
    code VARCHAR(20) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(10) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_gender (code, label, xml_value, sort_order) VALUES
('all', 'All', '-', 10),
('male', 'Male', 'M', 20),
('female', 'Female', 'F', 30)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_age_unit (
    code VARCHAR(10) PRIMARY KEY,
    label VARCHAR(50) NOT NULL,
    xml_suffix VARCHAR(10) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_age_unit (code, label, xml_suffix, sort_order) VALUES
('Y', 'Years', 'Y', 10),
('M', 'Months', 'M', 20),
('W', 'Weeks', 'W', 30),
('D', 'Days', 'D', 40),
('H', 'Hours', 'H', 50),
('MIN', 'Minutes', 'Min', 60)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 2. Main ICTRP vocabularies
-- ============================================================

CREATE TABLE IF NOT EXISTS vocab_type_enrolment (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_type_enrolment (code, label, xml_value, sort_order) VALUES
('anticipated', 'Anticipated', 'anticipated', 10),
('actual', 'Actual', 'actual', 20)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_recruitment_status (
    id SERIAL PRIMARY KEY,
    code VARCHAR(80) UNIQUE NOT NULL,
    label VARCHAR(150) NOT NULL,
    xml_value VARCHAR(150) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_recruitment_status (code, label, xml_value, sort_order) VALUES
('not_yet_recruiting', 'Not yet recruiting', 'Not yet recruiting', 10),
('recruiting', 'Recruiting', 'Recruiting', 20),
('enrolling_by_invitation', 'Enrolling by invitation', 'Enrolling by invitation', 30),
('active_not_recruiting', 'Active, not recruiting', 'Active, not recruiting', 40),
('recruitment_completed', 'Recruitment completed', 'Recruitment completed', 50),
('suspended', 'Suspended', 'Suspended', 60),
('terminated', 'Terminated', 'Terminated', 70),
('withdrawn', 'Withdrawn', 'Withdrawn', 80),
('unknown', 'Unknown', 'Unknown', 90)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_study_type (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_study_type (code, label, xml_value, sort_order) VALUES
('intervention', 'Intervention', 'Intervention', 10),
('observational', 'Observational', 'Observational', 20),
('expanded_access', 'Expanded access', 'Expanded access', 30)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_phase (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_phase (code, label, xml_value, sort_order) VALUES
('na', 'N/A', 'N/A', 10),
('phase_0', 'Phase 0', 'Phase 0', 20),
('phase_1', 'Phase 1', 'Phase 1', 30),
('phase_1_2', 'Phase 1/Phase 2', 'Phase 1/Phase 2', 40),
('phase_2', 'Phase 2', 'Phase 2', 50),
('phase_2_3', 'Phase 2/Phase 3', 'Phase 2/Phase 3', 60),
('phase_3', 'Phase 3', 'Phase 3', 70),
('phase_4', 'Phase 4', 'Phase 4', 80),
('not_applicable', 'Not applicable', 'N/A', 90)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 3. Study design vocabularies
-- ============================================================

CREATE TABLE IF NOT EXISTS vocab_expanded_access (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_expanded_access (code, label, xml_value, sort_order) VALUES
('yes', 'Yes', 'expanded access', 10),
('no', 'No', 'n/a', 20),
('unknown', 'Unknown', 'unknown', 30)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_study_focus (
    id SERIAL PRIMARY KEY,
    code VARCHAR(80) UNIQUE NOT NULL,
    label VARCHAR(150) NOT NULL,
    xml_value VARCHAR(150) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_study_focus (code, label, xml_value, sort_order) VALUES
('treatment', 'Treatment', 'treatment', 10),
('prevention', 'Prevention', 'prevention', 20),
('diagnostic', 'Diagnostic', 'diagnostic', 30),
('screening', 'Screening', 'screening', 40),
('supportive_care', 'Supportive care', 'supportive care', 50),
('health_services_research', 'Health services research', 'health services research', 60),
('basic_science', 'Basic science', 'basic science', 70),
('other', 'Other', 'other', 80),
('not_applicable', 'Not applicable', 'n/a', 90)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_intervention_design (
    id SERIAL PRIMARY KEY,
    code VARCHAR(80) UNIQUE NOT NULL,
    label VARCHAR(150) NOT NULL,
    xml_value VARCHAR(150) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_intervention_design (code, label, xml_value, sort_order) VALUES
('single_group', 'Single group', 'single group', 10),
('parallel', 'Parallel', 'parallel', 20),
('crossover', 'Crossover', 'crossover', 30),
('factorial', 'Factorial', 'factorial', 40),
('sequential', 'Sequential', 'sequential', 50),
('not_applicable', 'Not applicable', 'n/a', 60)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_masking_type (
    id SERIAL PRIMARY KEY,
    code VARCHAR(80) UNIQUE NOT NULL,
    label VARCHAR(150) NOT NULL,
    xml_value VARCHAR(150) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_masking_type (code, label, xml_value, sort_order) VALUES
('open_label', 'Open label', 'open label', 10),
('single_blind', 'Single blind', 'single-blind', 20),
('double_blind', 'Double blind', 'double-blind', 30),
('triple_blind', 'Triple blind', 'triple-blind', 40),
('quadruple_blind', 'Quadruple blind', 'quadruple-blind', 50),
('not_applicable', 'Not applicable', 'n/a', 60)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_allocation_type (
    id SERIAL PRIMARY KEY,
    code VARCHAR(80) UNIQUE NOT NULL,
    label VARCHAR(150) NOT NULL,
    xml_value VARCHAR(150) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_allocation_type (code, label, xml_value, sort_order) VALUES
('randomized', 'Randomized', 'randomized-controlled', 10),
('non_randomized', 'Non-randomized', 'non-randomized', 20),
('not_applicable', 'Not applicable', 'n/a', 30)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 4. Other vocabularies
-- ============================================================

CREATE TABLE IF NOT EXISTS vocab_ethics_status (
    code VARCHAR(50) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    xml_value VARCHAR(100) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_ethics_status (code, label, xml_value, sort_order) VALUES
('approved', 'Approved', 'Approved', 10),
('pending', 'Pending', 'Pending', 20),
('not_required', 'Not required', 'Not required', 30),
('rejected', 'Rejected', 'Rejected', 40),
('unknown', 'Unknown', 'Unknown', 50)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_ipd_plan (
    code VARCHAR(20) PRIMARY KEY,
    label VARCHAR(50) NOT NULL,
    xml_value VARCHAR(50) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_ipd_plan (code, label, xml_value, sort_order) VALUES
('yes', 'Yes', 'Yes', 10),
('no', 'No', 'No', 20),
('undecided', 'Undecided', 'Undecided', 30)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_sponsor_type (
    code VARCHAR(30) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    xml_tag VARCHAR(50) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_sponsor_type (code, label, xml_tag, sort_order) VALUES
('secondary_sponsor', 'Secondary sponsor', 'secondary_sponsor', 10),
('source_support', 'Source of monetary or material support', 'source_support', 20)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS vocab_outcome_type (
    code VARCHAR(20) PRIMARY KEY,
    label VARCHAR(100) NOT NULL,
    xml_tag VARCHAR(50) NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO vocab_outcome_type (code, label, xml_tag, sort_order) VALUES
('primary', 'Primary outcome', 'primary_outcome', 10),
('secondary', 'Secondary outcome', 'secondary_outcome', 20)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 5. Main trial tables
-- ============================================================

CREATE TABLE IF NOT EXISTS trial (
    id SERIAL PRIMARY KEY,

    trial_id VARCHAR(30) UNIQUE,
    utrn VARCHAR(50),
    reg_name VARCHAR(50) NOT NULL DEFAULT 'REBEC',

    status VARCHAR(30) NOT NULL DEFAULT 'draft'
        REFERENCES vocab_trial_status(code),

    date_registration DATE,
    date_enrolment DATE,

    primary_sponsor TEXT NOT NULL,

    public_title TEXT NOT NULL,
    acronym VARCHAR(100),

    scientific_title TEXT NOT NULL,
    scientific_acronym VARCHAR(100),

    type_enrolment_id INTEGER REFERENCES vocab_type_enrolment(id),
    target_size INTEGER CHECK (target_size IS NULL OR target_size >= 0),

    recruitment_status_id INTEGER NOT NULL REFERENCES vocab_recruitment_status(id),
    study_type_id INTEGER NOT NULL REFERENCES vocab_study_type(id),
    phase_id INTEGER REFERENCES vocab_phase(id),

    hc_freetext TEXT,
    i_freetext TEXT,

    url TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now(),
    submitted_at TIMESTAMP,
    approved_at TIMESTAMP,
    published_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trial_status ON trial(status);
CREATE INDEX IF NOT EXISTS idx_trial_trial_id ON trial(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_public_title ON trial USING gin(to_tsvector('english', public_title));
CREATE INDEX IF NOT EXISTS idx_trial_scientific_title ON trial USING gin(to_tsvector('english', scientific_title));

CREATE TABLE IF NOT EXISTS trial_study_design (
    trial_id INTEGER PRIMARY KEY REFERENCES trial(id) ON DELETE CASCADE,

    expanded_access_id INTEGER REFERENCES vocab_expanded_access(id),
    study_focus_id INTEGER REFERENCES vocab_study_focus(id),
    intervention_design_id INTEGER REFERENCES vocab_intervention_design(id),
    number_of_arms INTEGER CHECK (number_of_arms IS NULL OR number_of_arms >= 0),
    masking_type_id INTEGER REFERENCES vocab_masking_type(id),
    allocation_type_id INTEGER REFERENCES vocab_allocation_type(id),

    generated_study_design TEXT,
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trial_contact (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    contact_type VARCHAR(30) NOT NULL REFERENCES vocab_contact_type(code),

    firstname VARCHAR(150) NOT NULL,
    middlename VARCHAR(150),
    lastname VARCHAR(150),

    address TEXT,
    city VARCHAR(150),
    country_code CHAR(2),
    zip VARCHAR(30),
    telephone VARCHAR(100),
    email VARCHAR(255),
    affiliation TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_contact_trial_id ON trial_contact(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_contact_type ON trial_contact(contact_type);

CREATE TABLE IF NOT EXISTS trial_country (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,
    country_code CHAR(2) NOT NULL,
    UNIQUE (trial_id, country_code)
);

CREATE INDEX IF NOT EXISTS idx_trial_country_trial_id ON trial_country(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_country_code ON trial_country(country_code);

CREATE TABLE IF NOT EXISTS trial_criteria (
    trial_id INTEGER PRIMARY KEY REFERENCES trial(id) ON DELETE CASCADE,

    inclusion_criteria TEXT NOT NULL,
    exclusion_criteria TEXT NOT NULL,

    age_min_value INTEGER CHECK (age_min_value IS NULL OR age_min_value >= 0),
    age_min_unit VARCHAR(10) REFERENCES vocab_age_unit(code),

    age_max_value INTEGER CHECK (age_max_value IS NULL OR age_max_value >= 0),
    age_max_unit VARCHAR(10) REFERENCES vocab_age_unit(code),

    gender VARCHAR(20) NOT NULL DEFAULT 'all' REFERENCES vocab_gender(code),

    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trial_health_condition_code (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,
    code VARCHAR(100) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trial_hc_code_trial_id ON trial_health_condition_code(trial_id);

CREATE TABLE IF NOT EXISTS trial_health_condition_keyword (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,
    keyword TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trial_hc_keyword_trial_id ON trial_health_condition_keyword(trial_id);

CREATE TABLE IF NOT EXISTS trial_intervention_code (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,
    code VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_trial_intervention_code_trial_id ON trial_intervention_code(trial_id);

CREATE TABLE IF NOT EXISTS trial_intervention_keyword (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,
    keyword TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_trial_intervention_keyword_trial_id ON trial_intervention_keyword(trial_id);

CREATE TABLE IF NOT EXISTS trial_outcome (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    outcome_type VARCHAR(20) NOT NULL REFERENCES vocab_outcome_type(code),
    description TEXT NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_outcome_trial_id ON trial_outcome(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_outcome_type ON trial_outcome(outcome_type);

CREATE TABLE IF NOT EXISTS trial_sponsor (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    sponsor_type VARCHAR(30) NOT NULL REFERENCES vocab_sponsor_type(code),
    sponsor_name TEXT NOT NULL,

    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_sponsor_trial_id ON trial_sponsor(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_sponsor_type ON trial_sponsor(sponsor_type);

CREATE TABLE IF NOT EXISTS trial_secondary_id (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    sec_id VARCHAR(150) NOT NULL,
    issuing_authority TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_secondary_id_trial_id ON trial_secondary_id(trial_id);

CREATE TABLE IF NOT EXISTS trial_ethics_review (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    status VARCHAR(50) NOT NULL REFERENCES vocab_ethics_status(code),
    approval_date DATE,

    contact_name TEXT,
    contact_address TEXT,
    contact_phone VARCHAR(100),
    contact_email VARCHAR(255),

    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_ethics_review_trial_id ON trial_ethics_review(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_ethics_review_status ON trial_ethics_review(status);

CREATE TABLE IF NOT EXISTS trial_results (
    trial_id INTEGER PRIMARY KEY REFERENCES trial(id) ON DELETE CASCADE,

    actual_enrolment INTEGER CHECK (actual_enrolment IS NULL OR actual_enrolment >= 0),
    date_completed DATE,
    url_link TEXT,
    summary TEXT,
    date_posted DATE,
    date_first_publication DATE,

    baseline_char TEXT,
    participant_flow TEXT,
    adverse_events TEXT,
    outcome_measures TEXT,

    url_protocol TEXT,

    ipd_plan VARCHAR(20) REFERENCES vocab_ipd_plan(code),
    ipd_description TEXT,

    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trial_review (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id) ON DELETE CASCADE,

    review_status VARCHAR(30) NOT NULL REFERENCES vocab_trial_status(code),
    reviewer_name VARCHAR(150),
    reviewer_comment TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trial_review_trial_id ON trial_review(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_review_status ON trial_review(review_status);

CREATE TABLE IF NOT EXISTS trial_public_snapshot (
    id SERIAL PRIMARY KEY,
    trial_id INTEGER NOT NULL REFERENCES trial(id),

    public_trial_id VARCHAR(30) NOT NULL,
    xml_content TEXT NOT NULL,

    generated_at TIMESTAMP NOT NULL DEFAULT now(),
    is_current BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_trial_public_snapshot_trial_id ON trial_public_snapshot(trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_public_snapshot_public_id ON trial_public_snapshot(public_trial_id);
CREATE INDEX IF NOT EXISTS idx_trial_public_snapshot_current ON trial_public_snapshot(is_current);

-- ============================================================
-- 6. Utility functions
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_trial_updated_at ON trial;
CREATE TRIGGER trg_trial_updated_at
BEFORE UPDATE ON trial
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_trial_study_design_updated_at ON trial_study_design;
CREATE TRIGGER trg_trial_study_design_updated_at
BEFORE UPDATE ON trial_study_design
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_trial_criteria_updated_at ON trial_criteria;
CREATE TRIGGER trg_trial_criteria_updated_at
BEFORE UPDATE ON trial_criteria
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_trial_results_updated_at ON trial_results;
CREATE TRIGGER trg_trial_results_updated_at
BEFORE UPDATE ON trial_results
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION generate_study_design(p_trial_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_text TEXT;
BEGIN
    SELECT concat_ws(', ',
        NULLIF(ea.xml_value, ''),
        NULLIF(sf.xml_value, ''),
        NULLIF(idg.xml_value, ''),
        CASE
            WHEN d.number_of_arms IS NOT NULL AND d.number_of_arms > 0
            THEN d.number_of_arms::TEXT || ' arms'
            ELSE NULL
        END,
        NULLIF(mt.xml_value, ''),
        NULLIF(at.xml_value, '')
    )
    INTO v_text
    FROM trial_study_design d
    LEFT JOIN vocab_expanded_access ea ON ea.id = d.expanded_access_id
    LEFT JOIN vocab_study_focus sf ON sf.id = d.study_focus_id
    LEFT JOIN vocab_intervention_design idg ON idg.id = d.intervention_design_id
    LEFT JOIN vocab_masking_type mt ON mt.id = d.masking_type_id
    LEFT JOIN vocab_allocation_type at ON at.id = d.allocation_type_id
    WHERE d.trial_id = p_trial_id;

    UPDATE trial_study_design
    SET generated_study_design = v_text
    WHERE trial_id = p_trial_id;

    RETURN v_text;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_study_design_compact(p_trial_id INTEGER)
RETURNS TEXT AS $$
DECLARE
    v_text TEXT;
BEGIN
    -- Compact style, closer to the current XML example:
    -- n/a, randomized-controlled, single-blind
    SELECT concat_ws(', ',
        NULLIF(ea.xml_value, ''),
        NULLIF(at.xml_value, ''),
        NULLIF(mt.xml_value, '')
    )
    INTO v_text
    FROM trial_study_design d
    LEFT JOIN vocab_expanded_access ea ON ea.id = d.expanded_access_id
    LEFT JOIN vocab_masking_type mt ON mt.id = d.masking_type_id
    LEFT JOIN vocab_allocation_type at ON at.id = d.allocation_type_id
    WHERE d.trial_id = p_trial_id;

    UPDATE trial_study_design
    SET generated_study_design = v_text
    WHERE trial_id = p_trial_id;

    RETURN v_text;
END;
$$ LANGUAGE plpgsql;

-- Optional trigger: automatically refresh generated study design
CREATE OR REPLACE FUNCTION refresh_study_design_after_save()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM generate_study_design_compact(NEW.trial_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_refresh_study_design_after_insert ON trial_study_design;
CREATE TRIGGER trg_refresh_study_design_after_insert
AFTER INSERT ON trial_study_design
FOR EACH ROW
EXECUTE FUNCTION refresh_study_design_after_save();

DROP TRIGGER IF EXISTS trg_refresh_study_design_after_update ON trial_study_design;
CREATE TRIGGER trg_refresh_study_design_after_update
AFTER UPDATE OF expanded_access_id, study_focus_id, intervention_design_id, number_of_arms, masking_type_id, allocation_type_id
ON trial_study_design
FOR EACH ROW
EXECUTE FUNCTION refresh_study_design_after_save();

-- ============================================================
-- 7. Views to make COBOL SELECTs simpler
-- ============================================================

CREATE OR REPLACE VIEW vw_trial_ictrp_main AS
SELECT
    t.id,
    t.trial_id,
    t.utrn,
    t.reg_name,
    t.status,
    t.date_registration,
    t.primary_sponsor,
    t.public_title,
    t.acronym,
    t.scientific_title,
    t.scientific_acronym,
    t.date_enrolment,
    te.xml_value AS type_enrolment,
    t.target_size,
    rs.xml_value AS recruitment_status,
    t.url,
    st.xml_value AS study_type,
    sd.generated_study_design AS study_design,
    ph.xml_value AS phase,
    t.hc_freetext,
    t.i_freetext,
    tr.actual_enrolment AS results_actual_enrolment,
    tr.date_completed AS results_date_completed,
    tr.url_link AS results_url_link,
    tr.summary AS results_summary,
    tr.date_posted AS results_date_posted,
    tr.date_first_publication AS results_date_first_publication,
    tr.baseline_char AS results_baseline_char,
    tr.participant_flow AS results_participant_flow,
    tr.adverse_events AS results_adverse_events,
    tr.outcome_measures AS results_outcome_measures,
    tr.url_protocol AS results_url_protocol,
    ipd.xml_value AS results_ipd_plan,
    tr.ipd_description AS results_ipd_description
FROM trial t
LEFT JOIN vocab_type_enrolment te ON te.id = t.type_enrolment_id
LEFT JOIN vocab_recruitment_status rs ON rs.id = t.recruitment_status_id
LEFT JOIN vocab_study_type st ON st.id = t.study_type_id
LEFT JOIN vocab_phase ph ON ph.id = t.phase_id
LEFT JOIN trial_study_design sd ON sd.trial_id = t.id
LEFT JOIN trial_results tr ON tr.trial_id = t.id
LEFT JOIN vocab_ipd_plan ipd ON ipd.code = tr.ipd_plan;

CREATE OR REPLACE VIEW vw_trial_criteria_xml AS
SELECT
    c.trial_id,
    c.inclusion_criteria,
    CASE
        WHEN c.age_min_value IS NULL THEN NULL
        WHEN c.age_min_unit IS NULL THEN c.age_min_value::TEXT
        ELSE c.age_min_value::TEXT || au_min.xml_suffix
    END AS agemin,
    CASE
        WHEN c.age_max_value IS NULL THEN NULL
        WHEN c.age_max_value = 0 THEN '0'
        WHEN c.age_max_unit IS NULL THEN c.age_max_value::TEXT
        ELSE c.age_max_value::TEXT || au_max.xml_suffix
    END AS agemax,
    g.xml_value AS gender,
    c.exclusion_criteria
FROM trial_criteria c
LEFT JOIN vocab_age_unit au_min ON au_min.code = c.age_min_unit
LEFT JOIN vocab_age_unit au_max ON au_max.code = c.age_max_unit
LEFT JOIN vocab_gender g ON g.code = c.gender;

COMMIT;

-- ============================================================
-- Suggested usage:
-- psql -U postgres -d rebec_cobol -f rebec_cobol_schema.sql
-- or:
-- psql -U postgres -d your_database_name -f rebec_cobol_schema.sql
-- ============================================================
