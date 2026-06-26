*> ============================================================
*> ReBEC COBOL - AI Reports Menu
*> ============================================================
*>
*> Purpose:
*>   Terminal COBOL interface for AI-generated strategic reports.
*>
*> Architecture:
*>   COBOL calls FastAPI through curl.
*>   FastAPI checks cache.
*>   OpenAI is called only by FastAPI when needed.
*>
*> Requirements:
*>   - FastAPI running at http://127.0.0.1:8000
*>   - curl installed
*>   - jq optional but recommended
*>
*> Compile:
*>   cd codes
*>   mkdir -p bin
*>   cobc -x -free -o bin/ai_reports_menu ai_reports_menu.cbl
*>
*> Run:
*>   export COB_LIBRARY_PATH=$(pwd)/bin
*>   ./bin/ai_reports_menu
*>
*> ============================================================

IDENTIFICATION DIVISION.
PROGRAM-ID. AI-REPORTS-MENU.

ENVIRONMENT DIVISION.

DATA DIVISION.

WORKING-STORAGE SECTION.

01 WS-OPTION              PIC X VALUE SPACE.
01 WS-ENTER               PIC X VALUE SPACE.
01 WS-SYS-STATUS          PIC S9(9) COMP-5 VALUE 0.

01 WS-API-BASE            PIC X(80)
    VALUE "http://127.0.0.1:8000".

01 WS-CMD                 PIC X(3000) VALUE SPACES.

01 WS-RESPONSE-FILE       PIC X(160)
    VALUE "/tmp/rebec_ai_response.json".

01 WS-CACHE-FILE          PIC X(160)
    VALUE "/tmp/rebec_ai_cache_status.json".

01 WS-HEALTH-FILE         PIC X(160)
    VALUE "/tmp/rebec_ai_health.json".

01 WS-MD-PATH             PIC X(160)
    VALUE "../api/reports/strategic_insights_latest.md".

01 WS-HTML-PATH           PIC X(160)
    VALUE "../api/reports/strategic_insights_latest.html".

01 WS-JSON-PATH           PIC X(160)
    VALUE "../api/reports/strategic_insights_latest.json".

PROCEDURE DIVISION.

MAIN-PROCEDURE.
    PERFORM UNTIL WS-OPTION = "Q" OR WS-OPTION = "q"
        PERFORM SHOW-MENU
        ACCEPT WS-OPTION

        EVALUATE WS-OPTION
            WHEN "1"
                PERFORM CHECK-API-HEALTH
            WHEN "2"
                PERFORM CHECK-CACHE-STATUS
            WHEN "3"
                PERFORM GENERATE-OR-REUSE-REPORT
            WHEN "4"
                PERFORM VIEW-LATEST-MARKDOWN
            WHEN "5"
                PERFORM OPEN-LATEST-HTML
            WHEN "6"
                PERFORM CLEAR-LATEST-CACHE
            WHEN "7"
                PERFORM FORCE-NEW-REPORT
            WHEN "Q"
                CONTINUE
            WHEN "q"
                CONTINUE
            WHEN OTHER
                DISPLAY "Invalid option."
                PERFORM WAIT-ENTER
        END-EVALUATE
    END-PERFORM

    DISPLAY "Leaving AI Reports Menu."
    STOP RUN
    .


SHOW-MENU.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY "        ReBEC COBOL - AI Strategic Reports"
    DISPLAY "============================================================"
    DISPLAY " "
    DISPLAY " 1 - Check API health"
    DISPLAY " 2 - Check report cache status"
    DISPLAY " 3 - Generate/reuse AI strategic report"
    DISPLAY " 4 - View latest Markdown report"
    DISPLAY " 5 - Open latest HTML report"
    DISPLAY " 6 - Clear latest report cache"
    DISPLAY " 7 - Force new AI report generation"
    DISPLAY " "
    DISPLAY " Q - Quit"
    DISPLAY " "
    DISPLAY "------------------------------------------------------------"
    DISPLAY " API: " WS-API-BASE
    DISPLAY "------------------------------------------------------------"
    DISPLAY " Option: " WITH NO ADVANCING
    .


CLEAR-SCREEN.
    MOVE SPACES TO WS-CMD
    STRING
        "clear" DELIMITED BY SIZE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
    .


WAIT-ENTER.
    DISPLAY " "
    DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
    ACCEPT WS-ENTER
    .


CHECK-API-HEALTH.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Checking FastAPI health"
    DISPLAY "============================================================"
    DISPLAY " "

    MOVE SPACES TO WS-CMD

    STRING
        "curl -s " DELIMITED BY SIZE
        WS-API-BASE DELIMITED BY SPACE
        "/health > " DELIMITED BY SIZE
        WS-HEALTH-FILE DELIMITED BY SPACE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

    IF WS-SYS-STATUS NOT = 0
        DISPLAY "Error calling API health endpoint."
        DISPLAY "Is uvicorn running?"
    ELSE
        MOVE SPACES TO WS-CMD

        STRING
            "if command -v jq >/dev/null 2>&1; then " DELIMITED BY SIZE
            "jq . " DELIMITED BY SIZE
            WS-HEALTH-FILE DELIMITED BY SPACE
            "; else cat " DELIMITED BY SIZE
            WS-HEALTH-FILE DELIMITED BY SPACE
            "; fi" DELIMITED BY SIZE
            INTO WS-CMD
        END-STRING

        CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
    END-IF

    PERFORM WAIT-ENTER
    .


CHECK-CACHE-STATUS.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Checking AI report cache status"
    DISPLAY "============================================================"
    DISPLAY " "

    MOVE SPACES TO WS-CMD

    STRING
        "curl -s " DELIMITED BY SIZE
        WS-API-BASE DELIMITED BY SPACE
        "/ai/cache/status > " DELIMITED BY SIZE
        WS-CACHE-FILE DELIMITED BY SPACE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

    IF WS-SYS-STATUS NOT = 0
        DISPLAY "Error calling cache status endpoint."
        DISPLAY "Is uvicorn running?"
    ELSE
        MOVE SPACES TO WS-CMD

        STRING
            "if command -v jq >/dev/null 2>&1; then " DELIMITED BY SIZE
            "jq . " DELIMITED BY SIZE
            WS-CACHE-FILE DELIMITED BY SPACE
            "; else cat " DELIMITED BY SIZE
            WS-CACHE-FILE DELIMITED BY SPACE
            "; fi" DELIMITED BY SIZE
            INTO WS-CMD
        END-STRING

        CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
    END-IF

    PERFORM WAIT-ENTER
    .


GENERATE-OR-REUSE-REPORT.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Generate/reuse AI Strategic Registry Insights Report"
    DISPLAY "============================================================"
    DISPLAY " "
    DISPLAY "The API will use the cached report if it is less than 24h old."
    DISPLAY "OpenAI will be called only if cache is missing or expired."
    DISPLAY " "

    MOVE SPACES TO WS-CMD

    STRING
        "curl -s -X POST " DELIMITED BY SIZE
        WS-API-BASE DELIMITED BY SPACE
        "/ai/reports/strategic-insights/generate > " DELIMITED BY SIZE
        WS-RESPONSE-FILE DELIMITED BY SPACE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

    IF WS-SYS-STATUS NOT = 0
        DISPLAY "Error calling generate endpoint."
        DISPLAY "Is uvicorn running?"
    ELSE
        DISPLAY "API response:"
        DISPLAY " "

        MOVE SPACES TO WS-CMD

        STRING
            "if command -v jq >/dev/null 2>&1; then " DELIMITED BY SIZE
            "jq '{status, generated, cache_used, message, model, " DELIMITED BY SIZE
            "summary, files}' " DELIMITED BY SIZE
            WS-RESPONSE-FILE DELIMITED BY SPACE
            "; else cat " DELIMITED BY SIZE
            WS-RESPONSE-FILE DELIMITED BY SPACE
            "; fi" DELIMITED BY SIZE
            INTO WS-CMD
        END-STRING

        CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
    END-IF

    PERFORM WAIT-ENTER
    .


VIEW-LATEST-MARKDOWN.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " View latest Markdown report"
    DISPLAY "============================================================"
    DISPLAY " "

    MOVE SPACES TO WS-CMD

    STRING
        "if [ -f " DELIMITED BY SIZE
        WS-MD-PATH DELIMITED BY SPACE
        " ]; then less " DELIMITED BY SIZE
        WS-MD-PATH DELIMITED BY SPACE
        "; else echo 'Latest Markdown report not found: " DELIMITED BY SIZE
        WS-MD-PATH DELIMITED BY SPACE
        "'; fi" DELIMITED BY SIZE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

    PERFORM WAIT-ENTER
    .


OPEN-LATEST-HTML.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Open latest HTML report"
    DISPLAY "============================================================"
    DISPLAY " "

    MOVE SPACES TO WS-CMD

    STRING
        "if [ -f " DELIMITED BY SIZE
        WS-HTML-PATH DELIMITED BY SPACE
        " ]; then xdg-open " DELIMITED BY SIZE
        WS-HTML-PATH DELIMITED BY SPACE
        " >/dev/null 2>&1 & echo 'Opening HTML report: " DELIMITED BY SIZE
        WS-HTML-PATH DELIMITED BY SPACE
        "'; else echo 'Latest HTML report not found: " DELIMITED BY SIZE
        WS-HTML-PATH DELIMITED BY SPACE
        "'; fi" DELIMITED BY SIZE
        INTO WS-CMD
    END-STRING

    CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

    PERFORM WAIT-ENTER
    .


CLEAR-LATEST-CACHE.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Clear latest AI report cache"
    DISPLAY "============================================================"
    DISPLAY " "
    DISPLAY "This removes only:"
    DISPLAY "  strategic_insights_latest.md"
    DISPLAY "  strategic_insights_latest.html"
    DISPLAY "  strategic_insights_latest.json"
    DISPLAY " "
    DISPLAY "Historical timestamped reports are preserved."
    DISPLAY " "
    DISPLAY "Continue? Type Y to confirm: " WITH NO ADVANCING

    ACCEPT WS-OPTION

    IF WS-OPTION = "Y" OR WS-OPTION = "y"
        MOVE SPACES TO WS-CMD

        STRING
            "curl -s -X DELETE " DELIMITED BY SIZE
            WS-API-BASE DELIMITED BY SPACE
            "/ai/reports/strategic-insights/cache > " DELIMITED BY SIZE
            WS-RESPONSE-FILE DELIMITED BY SPACE
            INTO WS-CMD
        END-STRING

        CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

        IF WS-SYS-STATUS NOT = 0
            DISPLAY "Error calling cache clear endpoint."
        ELSE
            MOVE SPACES TO WS-CMD

            STRING
                "if command -v jq >/dev/null 2>&1; then " DELIMITED BY SIZE
                "jq . " DELIMITED BY SIZE
                WS-RESPONSE-FILE DELIMITED BY SPACE
                "; else cat " DELIMITED BY SIZE
                WS-RESPONSE-FILE DELIMITED BY SPACE
                "; fi" DELIMITED BY SIZE
                INTO WS-CMD
            END-STRING

            CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
        END-IF
    ELSE
        DISPLAY "Operation cancelled."
    END-IF

    MOVE SPACE TO WS-OPTION
    PERFORM WAIT-ENTER
    .


FORCE-NEW-REPORT.
    PERFORM CLEAR-SCREEN

    DISPLAY "============================================================"
    DISPLAY " Force new AI report generation"
    DISPLAY "============================================================"
    DISPLAY " "
    DISPLAY "WARNING:"
    DISPLAY "This option ignores the 24h cache and calls OpenAI again."
    DISPLAY "Use only when the database changed or you want a new version."
    DISPLAY " "
    DISPLAY "Continue? Type Y to confirm: " WITH NO ADVANCING

    ACCEPT WS-OPTION

    IF WS-OPTION = "Y" OR WS-OPTION = "y"
        DISPLAY " "
        DISPLAY "Calling API with force=true..."
        DISPLAY " "

        MOVE SPACES TO WS-CMD

        STRING
            "curl -s -X POST '" DELIMITED BY SIZE
            WS-API-BASE DELIMITED BY SPACE
            "/ai/reports/strategic-insights/generate?force=true&cleanup=true" DELIMITED BY SIZE
            "' > " DELIMITED BY SIZE
            WS-RESPONSE-FILE DELIMITED BY SPACE
            INTO WS-CMD
        END-STRING

        CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS

        IF WS-SYS-STATUS NOT = 0
            DISPLAY "Error calling forced generate endpoint."
        ELSE
            MOVE SPACES TO WS-CMD

            STRING
                "if command -v jq >/dev/null 2>&1; then " DELIMITED BY SIZE
                "jq '{status, generated, cache_used, message, model, " DELIMITED BY SIZE
                "summary, files, cleanup}' " DELIMITED BY SIZE
                WS-RESPONSE-FILE DELIMITED BY SPACE
                "; else cat " DELIMITED BY SIZE
                WS-RESPONSE-FILE DELIMITED BY SPACE
                "; fi" DELIMITED BY SIZE
                INTO WS-CMD
            END-STRING

            CALL "SYSTEM" USING WS-CMD RETURNING WS-SYS-STATUS
        END-IF
    ELSE
        DISPLAY "Operation cancelled."
    END-IF

    MOVE SPACE TO WS-OPTION
    PERFORM WAIT-ENTER
    .
