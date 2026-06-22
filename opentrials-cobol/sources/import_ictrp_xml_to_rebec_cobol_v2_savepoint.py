#!/usr/bin/env python3
"""
Import ICTRP/ReBEC XML into the simplified ReBEC COBOL PostgreSQL schema.

Expected XML structure:

<root>
  <trials>
    <trial>
      <main>...</main>
      <contacts>...</contacts>
      <countries>...</countries>
      <criteria>...</criteria>
      ...
    </trial>
    <trial>...</trial>
  </trials>
</root>

Example usage:

python3 import_ictrp_xml_to_rebec_cobol.py \
  --xml trials.xml \
  --dsn "host=localhost port=5432 dbname=rebec_cobol user=postgres password=postgres"

Or using environment variables:

export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=rebec_cobol
export PGUSER=postgres
export PGPASSWORD='your_password'
python3 import_ictrp_xml_to_rebec_cobol.py --xml trials.xml
"""

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("ERROR: psycopg2 is not installed.", file=sys.stderr)
    print("Install it with: pip install psycopg2-binary", file=sys.stderr)
    sys.exit(1)


DEFAULT_SCHEMA = "rebec_cobol"


def clean(value):
    """Normalize XML text content."""
    if value is None:
        return None
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    value = value.strip()
    return value if value != "" else None


def text(parent, path):
    if parent is None:
        return None
    node = parent.find(path)
    if node is None:
        return None
    return clean(node.text)


def all_text(parent, path):
    if parent is None:
        return []
    values = []
    for node in parent.findall(path):
        value = clean(node.text)
        if value:
            values.append(value)
    return values


def parse_date(value):
    """Parse common ICTRP date formats and return yyyy-mm-dd or None."""
    value = clean(value)
    if not value:
        return None

    formats = ["%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%Y/%m/%d"]
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt).date()
        except ValueError:
            pass

    # Sometimes XMLs contain partial/invalid dates. Keep import running.
    return None


def parse_int(value):
    value = clean(value)
    if not value:
        return None
    match = re.search(r"\d+", value)
    if not match:
        return None
    return int(match.group(0))


def normalize_code(value):
    value = clean(value) or "unknown"
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value).strip("_")
    return value[:70] or "unknown"


def parse_age(value):
    """
    Parse ICTRP age values like 18Y, 6M, 2W, 30D, 0.
    Returns: (value, unit_code)
    """
    value = clean(value)
    if not value:
        return None, None

    if value == "0":
        return 0, None

    match = re.match(r"^(\d+)\s*([A-Za-z]+)?$", value)
    if not match:
        return parse_int(value), None

    number = int(match.group(1))
    unit = (match.group(2) or "").upper()

    unit_map = {
        "Y": "Y", "YEAR": "Y", "YEARS": "Y",
        "M": "M", "MONTH": "M", "MONTHS": "M",
        "W": "W", "WEEK": "W", "WEEKS": "W",
        "D": "D", "DAY": "D", "DAYS": "D",
        "H": "H", "HOUR": "H", "HOURS": "H",
        "MIN": "MIN", "MINS": "MIN", "MINUTE": "MIN", "MINUTES": "MIN",
    }
    return number, unit_map.get(unit)


def gender_code(value):
    value = (clean(value) or "-").lower()
    if value in ["-", "all", "both", "both genders", "male and female", "m/f"]:
        return "all"
    if value in ["m", "male", "masculino"]:
        return "male"
    if value in ["f", "female", "feminino"]:
        return "female"
    return "all"


def ipd_code(value):
    value = (clean(value) or "").lower()
    if value in ["yes", "y", "sim"]:
        return "yes"
    if value in ["no", "n", "nao", "não"]:
        return "no"
    if value in ["undecided", "unknown", "not sure"]:
        return "undecided"
    return None


def ethics_status_code(value):
    value = (clean(value) or "unknown").lower()
    if "approved" in value or value == "aprovado":
        return "approved"
    if "pending" in value or "under review" in value:
        return "pending"
    if "not required" in value or "not applicable" in value:
        return "not_required"
    if "reject" in value:
        return "rejected"
    return "unknown"


def build_dsn(args):
    if args.dsn:
        return args.dsn

    parts = []
    env_map = {
        "host": "PGHOST",
        "port": "PGPORT",
        "dbname": "PGDATABASE",
        "user": "PGUSER",
        "password": "PGPASSWORD",
    }
    for key, env in env_map.items():
        value = os.environ.get(env)
        if value:
            parts.append(f"{key}={value}")

    if not parts:
        # Let libpq use its defaults: current Linux user and local socket.
        return ""
    return " ".join(parts)


def get_vocab_id(cur, schema, table, value, default_code=None, create_missing=True):
    """
    Find id in vocab tables by xml_value, label, or code. If not found, optionally insert it.
    Assumes vocabulary table has: id, code, label, xml_value, sort_order, is_active.
    """
    value = clean(value)
    if not value:
        value = default_code or "unknown"

    cur.execute(
        f"""
        SELECT id
        FROM {schema}.{table}
        WHERE lower(xml_value) = lower(%s)
           OR lower(label) = lower(%s)
           OR lower(code) = lower(%s)
        LIMIT 1
        """,
        (value, value, value),
    )
    row = cur.fetchone()
    if row:
        return row[0]

    if not create_missing:
        return None

    code = normalize_code(value)
    cur.execute(
        f"""
        INSERT INTO {schema}.{table} (code, label, xml_value, sort_order, is_active)
        VALUES (%s, %s, %s, 999, true)
        ON CONFLICT (code) DO UPDATE
        SET label = EXCLUDED.label,
            xml_value = EXCLUDED.xml_value
        RETURNING id
        """,
        (code, value, value),
    )
    return cur.fetchone()[0]


def get_code_vocab(cur, schema, table, value, fallback_code="unknown"):
    """Find code in code-based vocabulary tables."""
    value = clean(value)
    if not value:
        return fallback_code

    cur.execute(
        f"""
        SELECT code
        FROM {schema}.{table}
        WHERE lower(code) = lower(%s)
           OR lower(label) = lower(%s)
           OR lower(xml_value) = lower(%s)
        LIMIT 1
        """,
        (value, value, value),
    )
    row = cur.fetchone()
    return row[0] if row else fallback_code


def parse_study_design_tokens(study_design):
    """Infer structured design fields from the concatenated ICTRP study_design string."""
    raw = clean(study_design) or ""
    tokens = [t.strip().lower() for t in raw.split(",") if t.strip()]
    joined = " | ".join(tokens)

    expanded_access = None
    allocation = None
    masking = None
    focus = None
    intervention_design = None
    arms = None

    if "expanded access" in joined:
        expanded_access = "expanded access"
    elif "n/a" in tokens or "not applicable" in joined:
        expanded_access = "n/a"
    elif "unknown" in joined:
        expanded_access = "unknown"

    if "randomized-controlled" in joined or "randomized" in joined:
        allocation = "randomized-controlled"
    elif "non-randomized" in joined or "non randomized" in joined:
        allocation = "non-randomized"
    elif "n/a" in tokens or "not applicable" in joined:
        allocation = "n/a"

    if "quadruple-blind" in joined or "quadruple blind" in joined:
        masking = "quadruple-blind"
    elif "triple-blind" in joined or "triple blind" in joined:
        masking = "triple-blind"
    elif "double-blind" in joined or "double blind" in joined:
        masking = "double-blind"
    elif "single-blind" in joined or "single blind" in joined:
        masking = "single-blind"
    elif "open label" in joined or "open-label" in joined:
        masking = "open label"
    elif "n/a" in tokens or "not applicable" in joined:
        masking = "n/a"

    for possible in [
        "treatment", "prevention", "diagnostic", "screening", "supportive care",
        "health services research", "basic science", "other"
    ]:
        if possible in joined:
            focus = possible
            break

    for possible in ["single group", "parallel", "crossover", "factorial", "sequential"]:
        if possible in joined:
            intervention_design = possible
            break

    arms_match = re.search(r"(\d+)\s*arms?", joined)
    if arms_match:
        arms = int(arms_match.group(1))

    return {
        "expanded_access": expanded_access,
        "allocation": allocation,
        "masking": masking,
        "focus": focus,
        "intervention_design": intervention_design,
        "arms": arms,
        "raw": raw,
    }


def delete_trial_children(cur, schema, trial_db_id):
    tables = [
        "trial_study_design",
        "trial_contact",
        "trial_country",
        "trial_criteria",
        "trial_health_condition_code",
        "trial_health_condition_keyword",
        "trial_intervention_code",
        "trial_intervention_keyword",
        "trial_outcome",
        "trial_sponsor",
        "trial_secondary_id",
        "trial_ethics_review",
        "trial_results",
    ]
    for table in tables:
        cur.execute(f"DELETE FROM {schema}.{table} WHERE trial_id = %s", (trial_db_id,))


def import_one_trial(cur, schema, trial_elem, trial_status="published", save_snapshot=True):
    main = trial_elem.find("main")
    criteria = trial_elem.find("criteria")

    trial_id = text(main, "trial_id")
    if not trial_id:
        raise ValueError("Trial without <main><trial_id>; import skipped")

    type_enrolment_id = get_vocab_id(cur, schema, "vocab_type_enrolment", text(main, "type_enrolment"), create_missing=True)
    recruitment_status_id = get_vocab_id(cur, schema, "vocab_recruitment_status", text(main, "recruitment_status") or "Unknown", create_missing=True)
    study_type_id = get_vocab_id(cur, schema, "vocab_study_type", text(main, "study_type") or "Observational", create_missing=True)
    phase_id = get_vocab_id(cur, schema, "vocab_phase", text(main, "phase") or "N/A", create_missing=True)

    primary_sponsor = text(main, "primary_sponsor") or "Unknown"
    public_title = text(main, "public_title") or "Untitled trial"
    scientific_title = text(main, "scientific_title") or public_title

    cur.execute(
        f"""
        INSERT INTO {schema}.trial (
            trial_id, utrn, reg_name, status,
            date_registration, date_enrolment,
            primary_sponsor, public_title, acronym,
            scientific_title, scientific_acronym,
            type_enrolment_id, target_size,
            recruitment_status_id, study_type_id, phase_id,
            hc_freetext, i_freetext, url,
            approved_at, published_at
        )
        VALUES (
            %(trial_id)s, %(utrn)s, %(reg_name)s, %(status)s,
            %(date_registration)s, %(date_enrolment)s,
            %(primary_sponsor)s, %(public_title)s, %(acronym)s,
            %(scientific_title)s, %(scientific_acronym)s,
            %(type_enrolment_id)s, %(target_size)s,
            %(recruitment_status_id)s, %(study_type_id)s, %(phase_id)s,
            %(hc_freetext)s, %(i_freetext)s, %(url)s,
            CASE WHEN %(status)s IN ('approved', 'published') THEN now() ELSE NULL END,
            CASE WHEN %(status)s = 'published' THEN now() ELSE NULL END
        )
        ON CONFLICT (trial_id) DO UPDATE SET
            utrn = EXCLUDED.utrn,
            reg_name = EXCLUDED.reg_name,
            status = EXCLUDED.status,
            date_registration = EXCLUDED.date_registration,
            date_enrolment = EXCLUDED.date_enrolment,
            primary_sponsor = EXCLUDED.primary_sponsor,
            public_title = EXCLUDED.public_title,
            acronym = EXCLUDED.acronym,
            scientific_title = EXCLUDED.scientific_title,
            scientific_acronym = EXCLUDED.scientific_acronym,
            type_enrolment_id = EXCLUDED.type_enrolment_id,
            target_size = EXCLUDED.target_size,
            recruitment_status_id = EXCLUDED.recruitment_status_id,
            study_type_id = EXCLUDED.study_type_id,
            phase_id = EXCLUDED.phase_id,
            hc_freetext = EXCLUDED.hc_freetext,
            i_freetext = EXCLUDED.i_freetext,
            url = EXCLUDED.url,
            approved_at = COALESCE({schema}.trial.approved_at, EXCLUDED.approved_at),
            published_at = COALESCE({schema}.trial.published_at, EXCLUDED.published_at)
        RETURNING id
        """,
        {
            "trial_id": trial_id,
            "utrn": text(main, "utrn"),
            "reg_name": text(main, "reg_name") or "REBEC",
            "status": trial_status,
            "date_registration": parse_date(text(main, "date_registration")),
            "date_enrolment": parse_date(text(main, "date_enrolment")),
            "primary_sponsor": primary_sponsor,
            "public_title": public_title,
            "acronym": text(main, "acronym"),
            "scientific_title": scientific_title,
            "scientific_acronym": text(main, "scientific_acronym"),
            "type_enrolment_id": type_enrolment_id,
            "target_size": parse_int(text(main, "target_size")),
            "recruitment_status_id": recruitment_status_id,
            "study_type_id": study_type_id,
            "phase_id": phase_id,
            "hc_freetext": text(main, "hc_freetext"),
            "i_freetext": text(main, "i_freetext"),
            "url": text(main, "url"),
        },
    )
    trial_db_id = cur.fetchone()[0]

    # Reimport children idempotently.
    delete_trial_children(cur, schema, trial_db_id)

    # Study design
    design = parse_study_design_tokens(text(main, "study_design"))
    expanded_access_id = get_vocab_id(cur, schema, "vocab_expanded_access", design["expanded_access"], create_missing=False)
    study_focus_id = get_vocab_id(cur, schema, "vocab_study_focus", design["focus"], create_missing=False)
    intervention_design_id = get_vocab_id(cur, schema, "vocab_intervention_design", design["intervention_design"], create_missing=False)
    masking_type_id = get_vocab_id(cur, schema, "vocab_masking_type", design["masking"], create_missing=False)
    allocation_type_id = get_vocab_id(cur, schema, "vocab_allocation_type", design["allocation"], create_missing=False)

    cur.execute(
        f"""
        INSERT INTO {schema}.trial_study_design (
            trial_id, expanded_access_id, study_focus_id, intervention_design_id,
            number_of_arms, masking_type_id, allocation_type_id, generated_study_design
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            trial_db_id, expanded_access_id, study_focus_id, intervention_design_id,
            design["arms"], masking_type_id, allocation_type_id, design["raw"]
        ),
    )
    # The schema trigger regenerates this field after INSERT. Restore the original XML value.
    if design["raw"]:
        cur.execute(
            f"UPDATE {schema}.trial_study_design SET generated_study_design = %s WHERE trial_id = %s",
            (design["raw"], trial_db_id),
        )

    # Contacts
    contact_rows = []
    for c in trial_elem.findall("contacts/contact"):
        contact_type = (text(c, "type") or "public").lower()
        if contact_type not in ["public", "scientific"]:
            contact_type = "public"
        firstname = text(c, "firstname") or text(c, "name") or "Unknown"
        contact_rows.append((
            trial_db_id, contact_type, firstname, text(c, "middlename"), text(c, "lastname"),
            text(c, "address"), text(c, "city"), text(c, "country1"), text(c, "zip"),
            text(c, "telephone"), text(c, "email"), text(c, "affiliation")
        ))
    if contact_rows:
        execute_values(
            cur,
            f"""
            INSERT INTO {schema}.trial_contact (
                trial_id, contact_type, firstname, middlename, lastname,
                address, city, country_code, zip, telephone, email, affiliation
            ) VALUES %s
            """,
            contact_rows,
        )

    # Countries
    countries = all_text(trial_elem, "countries/country2")
    if countries:
        execute_values(
            cur,
            f"INSERT INTO {schema}.trial_country (trial_id, country_code) VALUES %s ON CONFLICT DO NOTHING",
            [(trial_db_id, country[:2].upper()) for country in countries if country],
        )

    # Criteria
    age_min_value, age_min_unit = parse_age(text(criteria, "agemin"))
    age_max_value, age_max_unit = parse_age(text(criteria, "agemax"))
    if criteria is not None:
        cur.execute(
            f"""
            INSERT INTO {schema}.trial_criteria (
                trial_id, inclusion_criteria, exclusion_criteria,
                age_min_value, age_min_unit, age_max_value, age_max_unit, gender
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                trial_db_id,
                text(criteria, "inclusion_criteria") or "Not informed",
                text(criteria, "exclusion_criteria") or "Not informed",
                age_min_value, age_min_unit,
                age_max_value, age_max_unit,
                gender_code(text(criteria, "gender")),
            ),
        )

    # Health condition codes and keywords
    hc_codes = all_text(trial_elem, "health_condition_code/hc_code")
    if hc_codes:
        execute_values(cur, f"INSERT INTO {schema}.trial_health_condition_code (trial_id, code) VALUES %s", [(trial_db_id, v) for v in hc_codes])

    hc_keywords = all_text(trial_elem, "health_condition_keyword/hc_keyword")
    if hc_keywords:
        execute_values(cur, f"INSERT INTO {schema}.trial_health_condition_keyword (trial_id, keyword) VALUES %s", [(trial_db_id, v) for v in hc_keywords])

    # Intervention codes and keywords
    i_codes = all_text(trial_elem, "intervention_code/i_code")
    if i_codes:
        execute_values(cur, f"INSERT INTO {schema}.trial_intervention_code (trial_id, code) VALUES %s", [(trial_db_id, v) for v in i_codes])

    i_keywords = all_text(trial_elem, "intervention_keyword/i_keyword")
    if i_keywords:
        execute_values(cur, f"INSERT INTO {schema}.trial_intervention_keyword (trial_id, keyword) VALUES %s", [(trial_db_id, v) for v in i_keywords])

    # Outcomes
    primary_outcomes = all_text(trial_elem, "primary_outcome/prim_outcome")
    secondary_outcomes = all_text(trial_elem, "secondary_outcome/sec_outcome")
    outcome_rows = []
    for i, value in enumerate(primary_outcomes, start=1):
        outcome_rows.append((trial_db_id, "primary", value, i))
    for i, value in enumerate(secondary_outcomes, start=1):
        outcome_rows.append((trial_db_id, "secondary", value, i))
    if outcome_rows:
        execute_values(cur, f"INSERT INTO {schema}.trial_outcome (trial_id, outcome_type, description, sort_order) VALUES %s", outcome_rows)

    # Sponsors and support sources
    sponsor_rows = []
    for i, value in enumerate(all_text(trial_elem, "secondary_sponsor/sponsor_name"), start=1):
        sponsor_rows.append((trial_db_id, "secondary_sponsor", value, i))
    for i, value in enumerate(all_text(trial_elem, "source_support/source_name"), start=1):
        sponsor_rows.append((trial_db_id, "source_support", value, i))
    if sponsor_rows:
        execute_values(cur, f"INSERT INTO {schema}.trial_sponsor (trial_id, sponsor_type, sponsor_name, sort_order) VALUES %s", sponsor_rows)

    # Secondary IDs
    sec_rows = []
    for sid in trial_elem.findall("secondary_ids/secondary_id"):
        sec_id = text(sid, "sec_id")
        if sec_id:
            sec_rows.append((trial_db_id, sec_id, text(sid, "issuing_authority")))
    if sec_rows:
        execute_values(cur, f"INSERT INTO {schema}.trial_secondary_id (trial_id, sec_id, issuing_authority) VALUES %s", sec_rows)

    # Ethics reviews
    ethics_rows = []
    for er in trial_elem.findall("ethics_reviews/ethics_review"):
        ethics_rows.append((
            trial_db_id,
            ethics_status_code(text(er, "status")),
            parse_date(text(er, "approval_date")),
            text(er, "contact_name"),
            text(er, "contact_address"),
            text(er, "contact_phone"),
            text(er, "contact_email"),
        ))
    if ethics_rows:
        execute_values(
            cur,
            f"""
            INSERT INTO {schema}.trial_ethics_review (
                trial_id, status, approval_date, contact_name,
                contact_address, contact_phone, contact_email
            ) VALUES %s
            """,
            ethics_rows,
        )

    # Results / IPD
    cur.execute(
        f"""
        INSERT INTO {schema}.trial_results (
            trial_id, actual_enrolment, date_completed, url_link, summary,
            date_posted, date_first_publication, baseline_char, participant_flow,
            adverse_events, outcome_measures, url_protocol, ipd_plan, ipd_description
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            trial_db_id,
            parse_int(text(main, "results_actual_enrolment")),
            parse_date(text(main, "results_date_completed")),
            text(main, "results_url_link"),
            text(main, "results_summary"),
            parse_date(text(main, "results_date_posted")),
            parse_date(text(main, "results_date_first_publication")),
            text(main, "results_baseline_char"),
            text(main, "results_participant_flow"),
            text(main, "results_adverse_events"),
            text(main, "results_outcome_measures"),
            text(main, "results_url_protocol"),
            ipd_code(text(main, "results_IPD_plan")),
            text(main, "results_IPD_description"),
        ),
    )

    # Import review history marker
    cur.execute(
        f"""
        INSERT INTO {schema}.trial_review (trial_id, review_status, reviewer_name, reviewer_comment)
        VALUES (%s, %s, %s, %s)
        """,
        (trial_db_id, trial_status, "XML importer", "Imported from ICTRP XML"),
    )

    # Public snapshot with original XML for this trial
    if save_snapshot and trial_status == "published":
        xml_content = ET.tostring(trial_elem, encoding="unicode")
        cur.execute(f"UPDATE {schema}.trial_public_snapshot SET is_current = false WHERE trial_id = %s", (trial_db_id,))
        cur.execute(
            f"""
            INSERT INTO {schema}.trial_public_snapshot (trial_id, public_trial_id, xml_content, is_current)
            VALUES (%s, %s, %s, true)
            """,
            (trial_db_id, trial_id, xml_content),
        )

    return trial_id, trial_db_id


def main():
    parser = argparse.ArgumentParser(description="Import ICTRP XML into ReBEC COBOL PostgreSQL schema.")
    parser.add_argument("--xml", required=True, help="Path to XML file containing several <trial> nodes.")
    parser.add_argument("--dsn", help="PostgreSQL DSN. If omitted, PG* environment variables/libpq defaults are used.")
    parser.add_argument("--schema", default=DEFAULT_SCHEMA, help="Target PostgreSQL schema. Default: rebec_cobol")
    parser.add_argument("--limit", type=int, help="Import only the first N trials, useful for testing.")
    parser.add_argument("--dry-run", action="store_true", help="Parse XML and test DB operations, then rollback.")
    parser.add_argument("--trial-status", default="published", choices=["draft", "submitted", "under_review", "returned", "approved", "rejected", "published"], help="Status assigned to imported trials.")
    parser.add_argument("--no-snapshot", action="store_true", help="Do not save original XML in trial_public_snapshot.")
    args = parser.parse_args()

    if not os.path.exists(args.xml):
        print(f"ERROR: XML file not found: {args.xml}", file=sys.stderr)
        sys.exit(1)

    tree = ET.parse(args.xml)
    root = tree.getroot()
    trials = root.findall(".//trial")
    if args.limit:
        trials = trials[:args.limit]

    print(f"Found {len(trials)} trial(s) in XML.")

    dsn = build_dsn(args)
    conn = psycopg2.connect(dsn)
    conn.autocommit = False

    imported = 0
    failed = 0

    try:
        with conn.cursor() as cur:
            cur.execute(f"SET search_path TO {args.schema}")

            failed_items = []

            for idx, trial_elem in enumerate(trials, start=1):
                savepoint_name = f"sp_trial_{idx}"
                cur.execute(f"SAVEPOINT {savepoint_name}")
                try:
                    trial_id, trial_db_id = import_one_trial(
                        cur,
                        args.schema,
                        trial_elem,
                        trial_status=args.trial_status,
                        save_snapshot=not args.no_snapshot,
                    )
                    cur.execute(f"RELEASE SAVEPOINT {savepoint_name}")
                    imported += 1

                    if imported % 100 == 0:
                        print(f"Imported {imported} trials...")
                    else:
                        print(f"[{idx}/{len(trials)}] Imported {trial_id} as database id {trial_db_id}")

                except Exception as exc:
                    failed += 1
                    # Roll back only the current trial, preserving all previously imported trials.
                    cur.execute(f"ROLLBACK TO SAVEPOINT {savepoint_name}")
                    cur.execute(f"RELEASE SAVEPOINT {savepoint_name}")

                    # Try to identify the failed trial without touching the aborted work.
                    main = trial_elem.find("main")
                    failed_trial_id = text(main, "trial_id") or "UNKNOWN_TRIAL_ID"
                    failed_items.append((idx, failed_trial_id, str(exc)))
                    print(f"[{idx}/{len(trials)}] ERROR importing {failed_trial_id}: {exc}", file=sys.stderr)

            if args.dry_run:
                conn.rollback()
                print(f"DRY RUN finished. Imported test count: {imported}. All changes rolled back.")
            else:
                conn.commit()
                print(f"Import finished. Imported: {imported}. Failed: {failed}.")

            if failed_items:
                log_path = f"import_failed_trials_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
                with open(log_path, "w", encoding="utf-8") as fh:
                    for idx, trial_id, error in failed_items:
                        fh.write(f"{idx}	{trial_id}	{error}\n")
                print(f"Failed trial log written to: {log_path}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
