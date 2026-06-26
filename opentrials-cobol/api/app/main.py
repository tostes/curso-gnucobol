#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ReBEC COBOL AI API
------------------

FastAPI layer for generating AI strategic reports from the
ReBEC COBOL PostgreSQL analytical dataset.

Architecture:
    PostgreSQL calculates aggregated JSON datasets.
    FastAPI orchestrates database access and report generation.
    OpenAI interprets consolidated indicators.
    COBOL can consume this API through curl/SYSTEM calls.

Important cache rule:
    The OpenAI API is called only when:
      1. there is no previous report in api/reports; or
      2. the latest report is older than CACHE_MAX_AGE_HOURS.

    This prevents generating multiple AI reports for the same
    unchanged database snapshot and reduces token usage.
"""

import os
import json
import datetime
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import markdown
import psycopg
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Query
from fastapi.responses import HTMLResponse, PlainTextResponse
from openai import OpenAI


# ============================================================
# Environment
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[1]   # api/
REPORTS_DIR = BASE_DIR / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(BASE_DIR / ".env")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1-mini")

REBEC_DB_HOST = os.getenv("REBEC_DB_HOST", "localhost")
REBEC_DB_PORT = int(os.getenv("REBEC_DB_PORT", "5432"))
REBEC_DB_NAME = os.getenv("REBEC_DB_NAME", "rebec_cobol")
REBEC_DB_USER = os.getenv("REBEC_DB_USER", "diego")
REBEC_DB_PASSWORD = os.getenv("REBEC_DB_PASSWORD", "")

# Local API protection token.
# This is NOT the OpenAI token.
# If empty, local API token validation is disabled.
REBEC_API_TOKEN = os.getenv("REBEC_API_TOKEN", "")

# Cache duration.
# Default: 24 hours.
CACHE_MAX_AGE_HOURS = int(os.getenv("CACHE_MAX_AGE_HOURS", "24"))


# ============================================================
# Paths
# ============================================================

LATEST_MD_PATH = REPORTS_DIR / "strategic_insights_latest.md"
LATEST_HTML_PATH = REPORTS_DIR / "strategic_insights_latest.html"
LATEST_JSON_PATH = REPORTS_DIR / "strategic_insights_latest.json"


# ============================================================
# FastAPI app
# ============================================================

app = FastAPI(
    title="ReBEC COBOL AI API",
    description="AI-generated strategic reports for ReBEC COBOL registry data.",
    version="0.2.0",
)


# ============================================================
# Security helpers
# ============================================================

def check_token(x_api_token: Optional[str]) -> None:
    """
    Simple local API token protection.

    If REBEC_API_TOKEN is empty, token validation is disabled.
    This is useful during local development.

    This token is only for protecting this local FastAPI service.
    It is not the OpenAI API key.
    """
    if not REBEC_API_TOKEN:
        return

    if x_api_token != REBEC_API_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid or missing API token.")


# ============================================================
# Cache helpers
# ============================================================

def utc_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def parse_iso_datetime(value: str) -> Optional[datetime.datetime]:
    """
    Parses ISO datetime strings saved in metadata.

    Accepts:
      2026-06-26T15:04:21
      2026-06-26T15:04:21-03:00
    """
    if not value:
        return None

    try:
        parsed = datetime.datetime.fromisoformat(value)

        if parsed.tzinfo is None:
            # Treat naive local timestamps as local time.
            # This is acceptable for cache age in the same machine.
            parsed = parsed.astimezone()

        return parsed.astimezone(datetime.timezone.utc)

    except Exception:
        return None


def file_modified_at_utc(path: Path) -> Optional[datetime.datetime]:
    if not path.exists():
        return None

    timestamp = path.stat().st_mtime
    return datetime.datetime.fromtimestamp(timestamp, tz=datetime.timezone.utc)


def read_latest_metadata() -> Optional[Dict[str, Any]]:
    """
    Reads strategic_insights_latest.json if available.
    """
    if not LATEST_JSON_PATH.exists():
        return None

    try:
        return json.loads(LATEST_JSON_PATH.read_text(encoding="utf-8"))
    except Exception:
        return None


def latest_report_exists() -> bool:
    """
    A valid cached report requires all latest files.
    """
    return (
        LATEST_MD_PATH.exists()
        and LATEST_HTML_PATH.exists()
        and LATEST_JSON_PATH.exists()
    )


def get_latest_report_generated_at() -> Optional[datetime.datetime]:
    """
    Determines the latest report generation time.

    Preferred:
      latest JSON metadata field: generated_at

    Fallback:
      latest Markdown file modification time
    """
    metadata = read_latest_metadata()

    if metadata:
        generated_at = parse_iso_datetime(str(metadata.get("generated_at", "")))
        if generated_at:
            return generated_at

    return file_modified_at_utc(LATEST_MD_PATH)


def get_cache_status() -> Dict[str, Any]:
    """
    Returns cache status without touching OpenAI.
    """
    exists = latest_report_exists()
    generated_at = get_latest_report_generated_at() if exists else None
    now = utc_now()

    if not exists or generated_at is None:
        return {
            "exists": False,
            "valid": False,
            "reason": "No complete latest report found.",
            "generated_at": None,
            "age_seconds": None,
            "age_hours": None,
            "max_age_hours": CACHE_MAX_AGE_HOURS,
            "files": {
                "latest_markdown": str(LATEST_MD_PATH),
                "latest_html": str(LATEST_HTML_PATH),
                "latest_json": str(LATEST_JSON_PATH),
            },
        }

    age_seconds = max(0, int((now - generated_at).total_seconds()))
    age_hours = round(age_seconds / 3600, 2)
    valid = age_seconds < (CACHE_MAX_AGE_HOURS * 3600)

    return {
        "exists": True,
        "valid": valid,
        "reason": (
            "Cached report is still valid."
            if valid
            else "Cached report is older than cache limit."
        ),
        "generated_at": generated_at.isoformat(),
        "age_seconds": age_seconds,
        "age_hours": age_hours,
        "max_age_hours": CACHE_MAX_AGE_HOURS,
        "files": {
            "latest_markdown": str(LATEST_MD_PATH),
            "latest_html": str(LATEST_HTML_PATH),
            "latest_json": str(LATEST_JSON_PATH),
        },
    }


def read_cached_report_response() -> Dict[str, Any]:
    """
    Builds the response when the latest report is reused.
    """
    metadata = read_latest_metadata() or {}
    cache = get_cache_status()

    return {
        "status": "success",
        "generated": False,
        "cache_used": True,
        "message": "Using cached AI Strategic Registry Insights Report. OpenAI was not called.",
        "model": metadata.get("model", OPENAI_MODEL),
        "cache": cache,
        "files": metadata.get(
            "files",
            {
                "latest_markdown": str(LATEST_MD_PATH),
                "latest_html": str(LATEST_HTML_PATH),
                "latest_json": str(LATEST_JSON_PATH),
            },
        ),
        "metadata": metadata,
    }


# ============================================================
# Database helpers
# ============================================================

def get_db_connection():
    """
    Creates a PostgreSQL connection.

    If REBEC_DB_PASSWORD is empty, psycopg will rely on local
    authentication or ~/.pgpass.
    """
    conninfo = {
        "host": REBEC_DB_HOST,
        "port": REBEC_DB_PORT,
        "dbname": REBEC_DB_NAME,
        "user": REBEC_DB_USER,
    }

    if REBEC_DB_PASSWORD:
        conninfo["password"] = REBEC_DB_PASSWORD

    return psycopg.connect(**conninfo)


def fetch_ai_dataset() -> Dict[str, Any]:
    """
    Fetches the consolidated JSON dataset generated by PostgreSQL.
    """
    sql = "SELECT rebec_cobol.fn_ai_registry_insight_dataset();"

    with get_db_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            row = cur.fetchone()

    if not row or row[0] is None:
        raise RuntimeError("PostgreSQL returned an empty AI insight dataset.")

    dataset = row[0]

    if isinstance(dataset, str):
        dataset = json.loads(dataset)

    return dataset


# ============================================================
# Prompt and OpenAI helpers
# ============================================================

def build_prompt(dataset: Dict[str, Any]) -> str:
    """
    Builds the AI prompt.

    The model must interpret only the provided consolidated indicators.
    It must not invent counts, organizations or findings.
    """
    dataset_json = json.dumps(dataset, ensure_ascii=False, indent=2)

    return f"""
You are a senior clinical trials analyst with strong experience in:
- public health governance,
- scientific registry management,
- clinical research policy,
- data quality analysis,
- strategic intelligence for clinical trials registries.

You are analyzing a consolidated JSON dataset from a public clinical trials registry.
The dataset was calculated locally in PostgreSQL and contains aggregated indicators,
rankings, trend data, governance flags and selected non-sensitive examples.

Very important rules:
1. Use only the numbers, sponsors, conditions and indicators present in the JSON.
2. Do not invent counts, institutions, sponsors, diseases or geographic findings.
3. When a field has limitations, explicitly state the limitation.
4. Treat "possibly outdated recruitment" as a data freshness/governance flag,
   not as proof of scientific or ethical misconduct.
5. Treat "health conditions" as a mixed free-text field that may include diseases,
   population descriptors, outcomes or functional measures.
6. Do not expose personal contact data. The dataset should not contain it, but
   if any personal contact detail appears, ignore it.
7. Produce a strategic report for registry managers, public health decision-makers
   and scientific governance stakeholders.

Write the report in English.

Required structure:

# AI Strategic Registry Insights Report

## 1. Executive Summary
Summarize the main findings in 3 to 5 paragraphs.

## 2. Registry Activity and Growth
Analyze total volume, annual trends and recent monthly activity.

## 3. Study Portfolio Profile
Analyze study type and clinical phase distribution. Highlight data limitations.

## 4. Recruitment Status and Data Freshness
Analyze recruitment status distribution and the "possibly outdated recruitment" flag.
Prioritize governance interpretation.

## 5. Therapeutic / Health Descriptor Portfolio
Analyze the most frequent health condition descriptors.
Mention that the source is a free-text field.

## 6. Sponsor and Institutional Footprint
Analyze top sponsors, sponsor concentration and institutional activity.
Do not call this "funding amount"; call it sponsor footprint or research activity.

## 7. Sponsor × Health Condition Intelligence
Analyze sponsor-condition concentration and examples of specialization.

## 8. Data Quality and Governance Risks
Analyze missing fields, date issues, phase limitations and recruitment freshness.

## 9. Strategic Opportunities
List 5 to 8 actionable opportunities for registry governance and scientific monitoring.

## 10. Recommended Monthly Indicators
List indicators that should be monitored monthly.

## 11. Caveats
Explicitly state analytical limitations.

Dataset JSON:
{dataset_json}
""".strip()


def call_openai_for_report(prompt: str) -> str:
    """
    Calls OpenAI Responses API and returns the report text.

    This function must only be called after cache validation confirms
    that a new report is required.
    """
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY is not configured.")

    client = OpenAI(api_key=OPENAI_API_KEY)

    response = client.responses.create(
        model=OPENAI_MODEL,
        input=prompt,
        temperature=0.2,
    )

    report_text = getattr(response, "output_text", None)

    if not report_text:
        raise RuntimeError("OpenAI returned an empty report.")

    return report_text


# ============================================================
# Report saving helpers
# ============================================================

def save_report_files(dataset: Dict[str, Any], report_markdown: str) -> Dict[str, Any]:
    """
    Saves report as Markdown, HTML and JSON metadata.

    Writes both timestamped files and latest_* files.
    """
    now = datetime.datetime.now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")

    md_path = REPORTS_DIR / f"strategic_insights_{timestamp}.md"
    html_path = REPORTS_DIR / f"strategic_insights_{timestamp}.html"
    json_path = REPORTS_DIR / f"strategic_insights_{timestamp}.json"

    html_body = markdown.markdown(
        report_markdown,
        extensions=["tables", "fenced_code"]
    )

    html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ReBEC AI Strategic Registry Insights Report</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {{
      font-family: Arial, sans-serif;
      line-height: 1.6;
      margin: 40px auto;
      max-width: 1100px;
      color: #222;
      background: #f8f9fa;
    }}
    main {{
      background: #fff;
      padding: 32px;
      border-radius: 12px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
    }}
    h1, h2, h3 {{
      color: #0d47a1;
    }}
    code {{
      background: #f1f3f5;
      padding: 2px 4px;
      border-radius: 4px;
    }}
    .meta {{
      color: #666;
      font-size: 0.9rem;
      border-bottom: 1px solid #ddd;
      padding-bottom: 12px;
      margin-bottom: 24px;
    }}
  </style>
</head>
<body>
<main>
  <div class="meta">
    Generated automatically on {now.isoformat(timespec="seconds")}<br>
    Source: PostgreSQL function rebec_cobol.fn_ai_registry_insight_dataset()
  </div>
  {html_body}
</main>
</body>
</html>
"""

    metadata = {
        "generated_at": now.isoformat(timespec="seconds"),
        "model": OPENAI_MODEL,
        "source_function": "rebec_cobol.fn_ai_registry_insight_dataset()",
        "cache_max_age_hours": CACHE_MAX_AGE_HOURS,
        "dataset_metadata": dataset.get("metadata", {}),
        "files": {
            "markdown": str(md_path),
            "html": str(html_path),
            "json": str(json_path),
            "latest_markdown": str(LATEST_MD_PATH),
            "latest_html": str(LATEST_HTML_PATH),
            "latest_json": str(LATEST_JSON_PATH),
        },
    }

    md_path.write_text(report_markdown, encoding="utf-8")
    html_path.write_text(html_doc, encoding="utf-8")
    json_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    LATEST_MD_PATH.write_text(report_markdown, encoding="utf-8")
    LATEST_HTML_PATH.write_text(html_doc, encoding="utf-8")
    LATEST_JSON_PATH.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")

    return metadata


def cleanup_old_timestamped_reports(keep_latest: int = 5) -> Dict[str, Any]:
    """
    Optional housekeeping.

    Keeps the most recent timestamped report sets and removes older ones.
    Does not remove latest_* files.

    A report set means:
      strategic_insights_YYYYMMDD_HHMMSS.md/html/json
    """
    timestamped_json = sorted(
        [
            p for p in REPORTS_DIR.glob("strategic_insights_*.json")
            if p.name != "strategic_insights_latest.json"
        ],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )

    removed = []

    for json_file in timestamped_json[keep_latest:]:
        stem = json_file.stem

        for suffix in [".json", ".md", ".html"]:
            candidate = REPORTS_DIR / f"{stem}{suffix}"
            if candidate.exists():
                try:
                    candidate.unlink()
                    removed.append(str(candidate))
                except Exception:
                    pass

    return {
        "keep_latest": keep_latest,
        "removed_count": len(removed),
        "removed_files": removed,
    }


# ============================================================
# Routes
# ============================================================

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "ReBEC COBOL AI API",
        "version": "0.2.0",
        "cache_max_age_hours": CACHE_MAX_AGE_HOURS,
    }


@app.get("/ai/cache/status")
def cache_status(
    x_api_token: Optional[str] = Header(default=None),
):
    """
    Shows whether a report exists and whether it is still valid.
    Does not call PostgreSQL.
    Does not call OpenAI.
    """
    check_token(x_api_token)
    return get_cache_status()


@app.get("/ai/dataset")
def get_dataset(
    x_api_token: Optional[str] = Header(default=None),
):
    """
    Returns the PostgreSQL consolidated dataset.

    This endpoint does not call OpenAI.
    Useful for debugging.
    """
    check_token(x_api_token)

    try:
        dataset = fetch_ai_dataset()
        return dataset
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/ai/reports/strategic-insights/generate")
def generate_strategic_insights(
    force: bool = Query(
        default=False,
        description="If true, ignore cache and force a new OpenAI report generation."
    ),
    cleanup: bool = Query(
        default=False,
        description="If true, remove older timestamped reports after generation."
    ),
    x_api_token: Optional[str] = Header(default=None),
):
    """
    Generates the AI Strategic Registry Insights Report.

    Cache behavior:
      - If a valid report exists and force=false:
            return cached report
            do not fetch dataset
            do not call OpenAI
      - If no report exists, cache is expired, or force=true:
            fetch dataset
            call OpenAI
            save new report
    """
    check_token(x_api_token)

    try:
        cache = get_cache_status()

        if cache["valid"] and not force:
            return read_cached_report_response()

        # Only after this point can OpenAI be used.
        dataset = fetch_ai_dataset()
        prompt = build_prompt(dataset)
        report_markdown = call_openai_for_report(prompt)
        metadata = save_report_files(dataset, report_markdown)

        cleanup_result = None
        if cleanup:
            cleanup_result = cleanup_old_timestamped_reports(keep_latest=5)

        dashboard = dataset.get("executive_dashboard", {})
        recruitment = dataset.get("recruitment_freshness", {})

        return {
            "status": "success",
            "generated": True,
            "cache_used": False,
            "message": "AI Strategic Registry Insights Report generated successfully. OpenAI was called.",
            "model": OPENAI_MODEL,
            "cache_before_generation": cache,
            "summary": {
                "total_trials": dashboard.get("total_trials"),
                "public_trials": dashboard.get("public_trials"),
                "registered_this_year": dashboard.get("registered_this_year"),
                "possibly_outdated_total": recruitment.get("possibly_outdated_total"),
            },
            "files": metadata.get("files", {}),
            "metadata": metadata,
            "cleanup": cleanup_result,
        }

    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get(
    "/ai/reports/strategic-insights/latest",
    response_class=PlainTextResponse,
)
def latest_report(
    format: str = Query(
        default="md",
        description="Use 'md' for Markdown, 'html' for HTML, or 'json' for metadata."
    ),
    x_api_token: Optional[str] = Header(default=None),
):
    """
    Returns the latest report.

    Does not call PostgreSQL.
    Does not call OpenAI.
    """
    check_token(x_api_token)

    fmt = format.lower().strip()

    if fmt == "html":
        if not LATEST_HTML_PATH.exists():
            raise HTTPException(status_code=404, detail="No latest HTML report found.")
        return HTMLResponse(LATEST_HTML_PATH.read_text(encoding="utf-8"))

    if fmt == "json":
        if not LATEST_JSON_PATH.exists():
            raise HTTPException(status_code=404, detail="No latest JSON metadata found.")
        return PlainTextResponse(
            LATEST_JSON_PATH.read_text(encoding="utf-8"),
            media_type="application/json",
        )

    if not LATEST_MD_PATH.exists():
        raise HTTPException(status_code=404, detail="No latest Markdown report found.")

    return LATEST_MD_PATH.read_text(encoding="utf-8")


@app.delete("/ai/reports/strategic-insights/cache")
def clear_report_cache(
    x_api_token: Optional[str] = Header(default=None),
):
    """
    Removes latest report files only.

    This is useful for testing cache behavior.
    It does not remove timestamped historical reports.
    """
    check_token(x_api_token)

    removed = []

    for path in [LATEST_MD_PATH, LATEST_HTML_PATH, LATEST_JSON_PATH]:
        if path.exists():
            path.unlink()
            removed.append(str(path))

    return {
        "status": "success",
        "message": "Latest report cache cleared.",
        "removed_files": removed,
    }
