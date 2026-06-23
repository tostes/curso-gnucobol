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
       01 TRIAL-LINE PIC X(12000).

       WORKING-STORAGE SECTION.

       01 WS-COMMAND              PIC X(16000).
       01 WS-CMDLINE              PIC X(200).

       01 WS-LOOKUP-TYPE          PIC X(1).
       01 WS-SEARCH-VALUE         PIC X(200).
       01 WS-EOF                  PIC X VALUE "N".
       01 WS-FOUND                PIC X VALUE "N".
       01 WS-DUMMY                PIC X(1).

       01 WS-ID                   PIC X(20).
       01 WS-TRIAL-ID             PIC X(80).
       01 WS-UTRN                 PIC X(80).
       01 WS-STATUS               PIC X(40).
       01 WS-URL                  PIC X(300).
       01 WS-CONTACT-NAME         PIC X(200).
       01 WS-CONTACT-PHONE        PIC X(100).
       01 WS-CONTACT-EMAIL        PIC X(200).
       01 WS-REG-DATE             PIC X(40).
       01 WS-ENROL-DATE           PIC X(40).
       01 WS-TARGET-SIZE          PIC X(40).
       01 WS-RECRUITMENT-STATUS   PIC X(100).
       01 WS-STUDY-TYPE           PIC X(100).
       01 WS-STUDY-DESIGN         PIC X(300).
       01 WS-PHASE                PIC X(100).
       01 WS-PRIMARY-SPONSOR      PIC X(300).
       01 WS-PUBLIC-TITLE         PIC X(500).
       01 WS-SCIENTIFIC-TITLE     PIC X(800).
       01 WS-HEALTH-CONDITIONS    PIC X(500).

       01 ESC                     PIC X VALUE X"1B".
       01 ANSI-CLEAR              PIC X(10).
       01 ANSI-RESET              PIC X(10).
       01 ANSI-BOLD               PIC X(10).
       01 ANSI-GREEN              PIC X(10).
       01 ANSI-CYAN               PIC X(10).
       01 ANSI-YELLOW             PIC X(10).
       01 ANSI-RED                PIC X(10).

       COPY "db_config.cpy".

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.

           PERFORM INIT-ANSI
           PERFORM LOAD-CONFIG
           PERFORM READ-INPUT
           PERFORM BUILD-COMMAND

           CALL "SYSTEM" USING WS-COMMAND

           PERFORM READ-RESULT
           PERFORM SHOW-RESULT

           DISPLAY " "
           DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
           ACCEPT WS-DUMMY

           STOP RUN.

       INIT-ANSI.

           STRING ESC "[2J" ESC "[H"
               DELIMITED BY SIZE INTO ANSI-CLEAR
           END-STRING

           STRING ESC "[0m"
               DELIMITED BY SIZE INTO ANSI-RESET
           END-STRING

           STRING ESC "[1m"
               DELIMITED BY SIZE INTO ANSI-BOLD
           END-STRING

           STRING ESC "[32m"
               DELIMITED BY SIZE INTO ANSI-GREEN
           END-STRING

           STRING ESC "[36m"
               DELIMITED BY SIZE INTO ANSI-CYAN
           END-STRING

           STRING ESC "[33m"
               DELIMITED BY SIZE INTO ANSI-YELLOW
           END-STRING

           STRING ESC "[31m"
               DELIMITED BY SIZE INTO ANSI-RED
           END-STRING
           .

       LOAD-CONFIG.

           CALL "LOADCONF" USING DB-CONFIG

           IF DB-STATUS NOT = "OK"
               DISPLAY " "
               DISPLAY ANSI-RED "Configuration error." ANSI-RESET
               DISPLAY "Message: " FUNCTION TRIM(DB-MESSAGE)
               DISPLAY " "
               STOP RUN
           END-IF
           .

       READ-INPUT.

           MOVE SPACES TO WS-CMDLINE
           MOVE SPACES TO WS-SEARCH-VALUE
           MOVE SPACES TO WS-LOOKUP-TYPE

           ACCEPT WS-CMDLINE FROM COMMAND-LINE

           IF FUNCTION TRIM(WS-CMDLINE) NOT = SPACES
               MOVE FUNCTION TRIM(WS-CMDLINE) TO WS-SEARCH-VALUE
           ELSE
               DISPLAY ANSI-CLEAR
               DISPLAY ANSI-BOLD ANSI-CYAN
                       "============================================================"
                       ANSI-RESET
               DISPLAY ANSI-BOLD
                       "              ReBEC COBOL - Trial View"
                       ANSI-RESET
               DISPLAY ANSI-CYAN
                       "============================================================"
                       ANSI-RESET
               DISPLAY " "
               DISPLAY "Search by:"
               DISPLAY "  1 - Internal database ID"
               DISPLAY "  2 - RBR/trial_id"
               DISPLAY " "
               DISPLAY "Option: " WITH NO ADVANCING
               ACCEPT WS-LOOKUP-TYPE

               IF WS-LOOKUP-TYPE = "1"
                   DISPLAY "Enter internal database ID: " WITH NO ADVANCING
                   ACCEPT WS-SEARCH-VALUE
               ELSE
                   DISPLAY "Enter RBR/trial_id: " WITH NO ADVANCING
                   ACCEPT WS-SEARCH-VALUE
               END-IF
           END-IF

           IF FUNCTION TRIM(WS-SEARCH-VALUE) = SPACES
               DISPLAY " "
               DISPLAY ANSI-RED "No search value provided." ANSI-RESET
               DISPLAY " "
               STOP RUN
           END-IF

           IF WS-LOOKUP-TYPE = SPACES
               IF WS-SEARCH-VALUE(1:4) = "RBR-"
                   MOVE "2" TO WS-LOOKUP-TYPE
               ELSE
                   MOVE "1" TO WS-LOOKUP-TYPE
               END-IF
           END-IF
           .

       BUILD-COMMAND.

           MOVE SPACES TO WS-COMMAND

           IF WS-LOOKUP-TYPE = "1"
               STRING
                 "psql "
                 "-h " FUNCTION TRIM(DB-HOST) " "
                 "-p " FUNCTION TRIM(DB-PORT) " "
                 "-U " FUNCTION TRIM(DB-USER) " "
                 "-d " FUNCTION TRIM(DB-NAME) " "
                 "-At -F '|' -c "
                 '"SELECT * FROM '
                 FUNCTION TRIM(DB-SCHEMA)
                 ".fn_public_trial_view_by_id("
                 FUNCTION TRIM(WS-SEARCH-VALUE)
                 ');" > trial_view.tmp'
                 DELIMITED BY SIZE
                 INTO WS-COMMAND
               END-STRING
           ELSE
               STRING
                 "psql "
                 "-h " FUNCTION TRIM(DB-HOST) " "
                 "-p " FUNCTION TRIM(DB-PORT) " "
                 "-U " FUNCTION TRIM(DB-USER) " "
                 "-d " FUNCTION TRIM(DB-NAME) " "
                 "-At -F '|' -c "
                 '"SELECT * FROM '
                 FUNCTION TRIM(DB-SCHEMA)
                 ".fn_public_trial_view_by_rbr('"
                 FUNCTION TRIM(WS-SEARCH-VALUE)
                 "');" '"'
                 " > trial_view.tmp"
                 DELIMITED BY SIZE
                 INTO WS-COMMAND
               END-STRING
           END-IF
           .

       READ-RESULT.

           MOVE "N" TO WS-FOUND
           MOVE "N" TO WS-EOF

           OPEN INPUT TRIAL-FILE

           READ TRIAL-FILE
               AT END
                   MOVE "N" TO WS-FOUND
               NOT AT END
                   MOVE "Y" TO WS-FOUND
                   PERFORM PARSE-LINE
           END-READ

           CLOSE TRIAL-FILE
           .

       PARSE-LINE.

           MOVE SPACES TO WS-ID
           MOVE SPACES TO WS-TRIAL-ID
           MOVE SPACES TO WS-UTRN
           MOVE SPACES TO WS-STATUS
           MOVE SPACES TO WS-URL
           MOVE SPACES TO WS-CONTACT-NAME
           MOVE SPACES TO WS-CONTACT-PHONE
           MOVE SPACES TO WS-CONTACT-EMAIL
           MOVE SPACES TO WS-REG-DATE
           MOVE SPACES TO WS-ENROL-DATE
           MOVE SPACES TO WS-TARGET-SIZE
           MOVE SPACES TO WS-RECRUITMENT-STATUS
           MOVE SPACES TO WS-STUDY-TYPE
           MOVE SPACES TO WS-STUDY-DESIGN
           MOVE SPACES TO WS-PHASE
           MOVE SPACES TO WS-PRIMARY-SPONSOR
           MOVE SPACES TO WS-PUBLIC-TITLE
           MOVE SPACES TO WS-SCIENTIFIC-TITLE
           MOVE SPACES TO WS-HEALTH-CONDITIONS

           UNSTRING TRIAL-LINE
               DELIMITED BY "|"
               INTO WS-ID
                    WS-TRIAL-ID
                    WS-UTRN
                    WS-STATUS
                    WS-URL
                    WS-CONTACT-NAME
                    WS-CONTACT-PHONE
                    WS-CONTACT-EMAIL
                    WS-REG-DATE
                    WS-ENROL-DATE
                    WS-TARGET-SIZE
                    WS-RECRUITMENT-STATUS
                    WS-STUDY-TYPE
                    WS-STUDY-DESIGN
                    WS-PHASE
                    WS-PRIMARY-SPONSOR
                    WS-PUBLIC-TITLE
                    WS-SCIENTIFIC-TITLE
                    WS-HEALTH-CONDITIONS
           END-UNSTRING
           .

       SHOW-RESULT.

           DISPLAY ANSI-CLEAR

           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              ReBEC COBOL - Trial Details"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "

           IF WS-FOUND NOT = "Y"
               DISPLAY ANSI-RED
                       "Trial not found or not public."
                       ANSI-RESET
               DISPLAY " "
           ELSE
               DISPLAY ANSI-BOLD "Identification" ANSI-RESET
               DISPLAY "  Internal ID      : " FUNCTION TRIM(WS-ID)
               DISPLAY "  RBR / Trial ID   : " FUNCTION TRIM(WS-TRIAL-ID)
               DISPLAY "  UTRN             : " FUNCTION TRIM(WS-UTRN)
               DISPLAY "  Status           : " FUNCTION TRIM(WS-STATUS)
               DISPLAY "  URL              : " FUNCTION TRIM(WS-URL)
               DISPLAY " "

               DISPLAY ANSI-BOLD "Titles" ANSI-RESET
               DISPLAY "  Public title     : "
               DISPLAY "    " FUNCTION TRIM(WS-PUBLIC-TITLE)
               DISPLAY "  Scientific title : "
               DISPLAY "    " FUNCTION TRIM(WS-SCIENTIFIC-TITLE)
               DISPLAY " "

               DISPLAY ANSI-BOLD "Trial information" ANSI-RESET
               DISPLAY "  Registration date: " FUNCTION TRIM(WS-REG-DATE)
               DISPLAY "  Enrolment date   : " FUNCTION TRIM(WS-ENROL-DATE)
               DISPLAY "  Target size      : " FUNCTION TRIM(WS-TARGET-SIZE)
               DISPLAY "  Recruitment      : "
                       FUNCTION TRIM(WS-RECRUITMENT-STATUS)
               DISPLAY "  Study type       : " FUNCTION TRIM(WS-STUDY-TYPE)
               DISPLAY "  Study design     : " FUNCTION TRIM(WS-STUDY-DESIGN)
               DISPLAY "  Phase            : " FUNCTION TRIM(WS-PHASE)
               DISPLAY " "

               DISPLAY ANSI-BOLD "Sponsor" ANSI-RESET
               DISPLAY "  Primary sponsor  : "
               DISPLAY "    " FUNCTION TRIM(WS-PRIMARY-SPONSOR)
               DISPLAY " "

               DISPLAY ANSI-BOLD "Public contact" ANSI-RESET
               DISPLAY "  Name             : " FUNCTION TRIM(WS-CONTACT-NAME)
               DISPLAY "  Phone            : " FUNCTION TRIM(WS-CONTACT-PHONE)
               DISPLAY "  Email            : " FUNCTION TRIM(WS-CONTACT-EMAIL)
               DISPLAY " "

               DISPLAY ANSI-BOLD "Health conditions" ANSI-RESET
               DISPLAY "  " FUNCTION TRIM(WS-HEALTH-CONDITIONS)
               DISPLAY " "
           END-IF
           .
