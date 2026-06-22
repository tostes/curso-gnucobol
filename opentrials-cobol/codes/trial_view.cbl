       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRIAL-VIEW.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRIAL-FILE ASSIGN TO "trial_view.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD TRIAL-FILE.
       01 TRIAL-LINE PIC X(8000).

       WORKING-STORAGE SECTION.
       01 WS-COMMAND        PIC X(14000).
       01 WS-WHERE          PIC X(1000).

       01 WS-SEARCH-TYPE    PIC X(1).
       01 WS-SEARCH-VALUE   PIC X(80).

       01 WS-ID             PIC X(20).
       01 WS-TRIAL-ID       PIC X(40).
       01 WS-UTRN           PIC X(80).
       01 WS-STATUS         PIC X(40).
       01 WS-URL            PIC X(500).

       01 WS-PUBLIC-CONTACT-NAME   PIC X(300).
       01 WS-PUBLIC-CONTACT-PHONE  PIC X(100).
       01 WS-PUBLIC-CONTACT-EMAIL  PIC X(255).

       01 WS-PUBLIC-TITLE   PIC X(700).
       01 WS-SCI-TITLE      PIC X(1000).
       01 WS-SPONSOR        PIC X(500).
       01 WS-REG-DATE       PIC X(30).
       01 WS-ENROL-DATE     PIC X(30).
       01 WS-RECRUITMENT    PIC X(120).
       01 WS-STUDY-TYPE     PIC X(120).
       01 WS-STUDY-DESIGN   PIC X(500).
       01 WS-PHASE          PIC X(80).
       01 WS-TARGET-SIZE    PIC X(40).
       01 WS-HC-FREETEXT    PIC X(1000).

       COPY "db_config.cpy".

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.

           PERFORM LOAD-CONFIG

           DISPLAY "==============================================="
           DISPLAY "        REBEC COBOL - VIEW TRIAL"
           DISPLAY "==============================================="
           DISPLAY " "

           DISPLAY "Search by:"
           DISPLAY "  1 - Database ID"
           DISPLAY "  2 - Trial ID / RBR"
           DISPLAY " "
           DISPLAY "Choose option: " WITH NO ADVANCING
           ACCEPT WS-SEARCH-TYPE

           IF WS-SEARCH-TYPE NOT = "1" AND WS-SEARCH-TYPE NOT = "2"
               DISPLAY " "
               DISPLAY "Invalid option."
               STOP RUN
           END-IF

           DISPLAY " "

           IF WS-SEARCH-TYPE = "1"
               DISPLAY "Enter database ID: " WITH NO ADVANCING
           ELSE
               DISPLAY "Enter Trial ID / RBR: " WITH NO ADVANCING
           END-IF

           ACCEPT WS-SEARCH-VALUE

           PERFORM BUILD-WHERE
           PERFORM BUILD-COMMAND

           CALL "SYSTEM" USING WS-COMMAND

           OPEN INPUT TRIAL-FILE

           READ TRIAL-FILE
               AT END
                   DISPLAY " "
                   DISPLAY "No trial found."
                   CLOSE TRIAL-FILE
                   STOP RUN
               NOT AT END
                   PERFORM PARSE-LINE
                   PERFORM DISPLAY-TRIAL
           END-READ

           CLOSE TRIAL-FILE

           DISPLAY " "
           DISPLAY "End."
           DISPLAY " "

           STOP RUN.

       LOAD-CONFIG.

           CALL "LOADCONF" USING DB-CONFIG

           IF DB-STATUS NOT = "OK"
               DISPLAY " "
               DISPLAY "Configuration error."
               DISPLAY "Message: " FUNCTION TRIM(DB-MESSAGE)
               DISPLAY " "
               STOP RUN
           END-IF
           .

       BUILD-WHERE.

           MOVE SPACES TO WS-WHERE

           IF WS-SEARCH-TYPE = "1"
               STRING
                   "WHERE id = "
                   FUNCTION TRIM(WS-SEARCH-VALUE)
                   DELIMITED BY SIZE
                   INTO WS-WHERE
               END-STRING
           ELSE
               STRING
                   "WHERE upper(trial_id) = upper('"
                   FUNCTION TRIM(WS-SEARCH-VALUE)
                   "')"
                   DELIMITED BY SIZE
                   INTO WS-WHERE
               END-STRING
           END-IF
           .

       BUILD-COMMAND.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "

             '"SELECT '

             'id, '

             'replace(replace(coalesce(trial_id, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(utrn, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(status, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(url, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(public_contact_name, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(public_contact_phone, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(public_contact_email, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(public_title, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(scientific_title, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(primary_sponsor, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'coalesce(date_registration::text, ''''), '

             'coalesce(date_enrolment::text, ''''), '

             'replace(replace(coalesce(recruitment_status, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(study_type, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(study_design, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'replace(replace(coalesce(phase, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '

             'coalesce(target_size::text, ''''), '

             'replace(replace(coalesce(hc_freetext, ''''), '
             'chr(10), '' ''), ''|'', '' '') '

             'FROM '
             FUNCTION TRIM(DB-SCHEMA)
             '.vw_trial_ictrp_main '
             FUNCTION TRIM(WS-WHERE)
             ';" > trial_view.tmp'

             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       PARSE-LINE.

           MOVE SPACES TO WS-ID
           MOVE SPACES TO WS-TRIAL-ID
           MOVE SPACES TO WS-UTRN
           MOVE SPACES TO WS-STATUS
           MOVE SPACES TO WS-URL

           MOVE SPACES TO WS-PUBLIC-CONTACT-NAME
           MOVE SPACES TO WS-PUBLIC-CONTACT-PHONE
           MOVE SPACES TO WS-PUBLIC-CONTACT-EMAIL

           MOVE SPACES TO WS-PUBLIC-TITLE
           MOVE SPACES TO WS-SCI-TITLE
           MOVE SPACES TO WS-SPONSOR
           MOVE SPACES TO WS-REG-DATE
           MOVE SPACES TO WS-ENROL-DATE
           MOVE SPACES TO WS-RECRUITMENT
           MOVE SPACES TO WS-STUDY-TYPE
           MOVE SPACES TO WS-STUDY-DESIGN
           MOVE SPACES TO WS-PHASE
           MOVE SPACES TO WS-TARGET-SIZE
           MOVE SPACES TO WS-HC-FREETEXT

           UNSTRING TRIAL-LINE
               DELIMITED BY "|"
               INTO WS-ID
                    WS-TRIAL-ID
                    WS-UTRN
                    WS-STATUS
                    WS-URL
                    WS-PUBLIC-CONTACT-NAME
                    WS-PUBLIC-CONTACT-PHONE
                    WS-PUBLIC-CONTACT-EMAIL
                    WS-PUBLIC-TITLE
                    WS-SCI-TITLE
                    WS-SPONSOR
                    WS-REG-DATE
                    WS-ENROL-DATE
                    WS-RECRUITMENT
                    WS-STUDY-TYPE
                    WS-STUDY-DESIGN
                    WS-PHASE
                    WS-TARGET-SIZE
                    WS-HC-FREETEXT
           END-UNSTRING
           .

       DISPLAY-TRIAL.

           DISPLAY " "
           DISPLAY "-----------------------------------------------"
           DISPLAY "TRIAL BASIC INFORMATION"
           DISPLAY "-----------------------------------------------"

           DISPLAY "Database ID       : " FUNCTION TRIM(WS-ID)
           DISPLAY "Trial ID / RBR    : " FUNCTION TRIM(WS-TRIAL-ID)
           DISPLAY "UTRN              : " FUNCTION TRIM(WS-UTRN)
           DISPLAY "Status            : " FUNCTION TRIM(WS-STATUS)

           DISPLAY " "
           DISPLAY "URL:"
           DISPLAY FUNCTION TRIM(WS-URL)

           DISPLAY " "
           DISPLAY "Public contact:"
           DISPLAY "Name : " FUNCTION TRIM(WS-PUBLIC-CONTACT-NAME)
           DISPLAY "Phone: " FUNCTION TRIM(WS-PUBLIC-CONTACT-PHONE)
           DISPLAY "Email: " FUNCTION TRIM(WS-PUBLIC-CONTACT-EMAIL)

           DISPLAY " "
           DISPLAY "Registration date : " FUNCTION TRIM(WS-REG-DATE)
           DISPLAY "Enrolment date    : " FUNCTION TRIM(WS-ENROL-DATE)
           DISPLAY "Target size       : " FUNCTION TRIM(WS-TARGET-SIZE)

           DISPLAY " "
           DISPLAY "Recruitment status: " FUNCTION TRIM(WS-RECRUITMENT)
           DISPLAY "Study type        : " FUNCTION TRIM(WS-STUDY-TYPE)
           DISPLAY "Study design      : " FUNCTION TRIM(WS-STUDY-DESIGN)
           DISPLAY "Phase             : " FUNCTION TRIM(WS-PHASE)

           DISPLAY " "
           DISPLAY "Primary sponsor:"
           DISPLAY FUNCTION TRIM(WS-SPONSOR)

           DISPLAY " "
           DISPLAY "Public title:"
           DISPLAY FUNCTION TRIM(WS-PUBLIC-TITLE)

           DISPLAY " "
           DISPLAY "Scientific title:"
           DISPLAY FUNCTION TRIM(WS-SCI-TITLE)

           DISPLAY " "
           DISPLAY "Health conditions:"
           DISPLAY FUNCTION TRIM(WS-HC-FREETEXT)

           DISPLAY "-----------------------------------------------"
           .
           