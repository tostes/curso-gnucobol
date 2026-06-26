       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPORTS-MENU.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REPORT-FILE ASSIGN TO "reports_menu.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD REPORT-FILE.
       01 REPORT-LINE PIC X(5000).

       WORKING-STORAGE SECTION.

       01 WS-COMMAND              PIC X(16000).

       01 WS-OPTION               PIC X(1).
       01 WS-DUMMY                PIC X(1).
       01 WS-EOF                  PIC X VALUE "N".
       01 WS-COUNT                PIC 9(6) VALUE 0.

       01 WS-FIELD-1              PIC X(300).
       01 WS-FIELD-2              PIC X(500).
       01 WS-FIELD-3              PIC X(500).
       01 WS-FIELD-4              PIC X(500).
       01 WS-FIELD-5              PIC X(500).
       01 WS-FIELD-6              PIC X(500).
       01 WS-FIELD-7              PIC X(500).
       01 WS-FIELD-8              PIC X(500).
       01 WS-FIELD-9              PIC X(500).
       01 WS-FIELD-10             PIC X(500).

       01 WS-PAGE-SIZE            PIC 9(4) VALUE 20.
       01 WS-PAGE-NUMBER          PIC 9(4) VALUE 1.
       01 WS-OFFSET               PIC 9(8) VALUE 0.
       01 WS-PAGE-SIZE-TEXT       PIC X(20).
       01 WS-OFFSET-TEXT          PIC X(20).

       01 WS-VIEW-ID              PIC X(20).
       01 WS-VIEW-COMMAND         PIC X(300).

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

           PERFORM UNTIL WS-OPTION = "Q" OR WS-OPTION = "q"
               PERFORM SHOW-MENU
               PERFORM READ-MENU-OPTION
           END-PERFORM

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

       SHOW-MENU.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              ReBEC COBOL - Reports"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "
           DISPLAY " 1 - Registry dashboard"
           DISPLAY " 2 - Trials by internal status"
           DISPLAY " 3 - Trials by recruitment status"
           DISPLAY " 4 - Possibly outdated recruitment trials"
           DISPLAY " 5 - Trials by study type"
           DISPLAY " "
           DISPLAY " Q - Quit"
           DISPLAY " "
           DISPLAY "Option: " WITH NO ADVANCING
           .

       READ-MENU-OPTION.

           ACCEPT WS-OPTION

           EVALUATE WS-OPTION
               WHEN "1"
                   PERFORM REPORT-DASHBOARD

               WHEN "2"
                   PERFORM REPORT-TRIALS-BY-STATUS

               WHEN "3"
                   PERFORM REPORT-TRIALS-BY-RECRUITMENT

               WHEN "4"
                   PERFORM REPORT-POSSIBLY-OUTDATED

               WHEN "5"
                   PERFORM REPORT-TRIALS-BY-STUDY-TYPE

               WHEN "Q"
               WHEN "q"
                   CONTINUE

               WHEN OTHER
                   DISPLAY "Invalid option."
                   DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
                   ACCEPT WS-DUMMY
           END-EVALUATE
           .

       BUILD-BASE-PSQL.

           MOVE SPACES TO WS-COMMAND
           .

       RUN-COMMAND.

           CALL "SYSTEM" USING WS-COMMAND
           .

       WAIT-ENTER.

           DISPLAY " "
           DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
           ACCEPT WS-DUMMY
           .

       REPORT-DASHBOARD.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_report_registry_dashboard();"
             '"'
             " > reports_menu.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING

           PERFORM RUN-COMMAND
           PERFORM SHOW-DASHBOARD
           PERFORM WAIT-ENTER
           .

       SHOW-DASHBOARD.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              Registry Dashboard"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "

           MOVE "N" TO WS-EOF
           OPEN INPUT REPORT-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ REPORT-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       MOVE SPACES TO WS-FIELD-1
                       MOVE SPACES TO WS-FIELD-2
                       MOVE SPACES TO WS-FIELD-3

                       UNSTRING REPORT-LINE
                           DELIMITED BY "|"
                           INTO WS-FIELD-1
                                WS-FIELD-2
                                WS-FIELD-3
                       END-UNSTRING

                       DISPLAY ANSI-YELLOW
                               FUNCTION TRIM(WS-FIELD-2)
                               ANSI-RESET
                               ": "
                               ANSI-GREEN
                               FUNCTION TRIM(WS-FIELD-3)
                               ANSI-RESET
               END-READ
           END-PERFORM

           CLOSE REPORT-FILE
           .

       REPORT-TRIALS-BY-STATUS.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_report_trials_by_status();"
             '"'
             " > reports_menu.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING

           PERFORM RUN-COMMAND
           PERFORM SHOW-SIMPLE-COUNT-REPORT
           PERFORM WAIT-ENTER
           .

       REPORT-TRIALS-BY-RECRUITMENT.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_report_trials_by_recruitment_status();"
             '"'
             " > reports_menu.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING

           PERFORM RUN-COMMAND
           PERFORM SHOW-LABEL-COUNT-REPORT
           PERFORM WAIT-ENTER
           .

       REPORT-TRIALS-BY-STUDY-TYPE.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_report_trials_by_study_type();"
             '"'
             " > reports_menu.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING

           PERFORM RUN-COMMAND
           PERFORM SHOW-LABEL-COUNT-REPORT
           PERFORM WAIT-ENTER
           .

       SHOW-SIMPLE-COUNT-REPORT.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              Trials by Status"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "
           DISPLAY ANSI-BOLD ANSI-YELLOW
                   " STATUS                         TOTAL       PERCENTAGE"
                   ANSI-RESET
           DISPLAY " ------------------------------------------------------------"

           MOVE "N" TO WS-EOF
           OPEN INPUT REPORT-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ REPORT-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       MOVE SPACES TO WS-FIELD-1
                       MOVE SPACES TO WS-FIELD-2
                       MOVE SPACES TO WS-FIELD-3

                       UNSTRING REPORT-LINE
                           DELIMITED BY "|"
                           INTO WS-FIELD-1
                                WS-FIELD-2
                                WS-FIELD-3
                       END-UNSTRING

                       DISPLAY " "
                               FUNCTION TRIM(WS-FIELD-1)
                               "    "
                               ANSI-GREEN
                               FUNCTION TRIM(WS-FIELD-2)
                               ANSI-RESET
                               "    "
                               FUNCTION TRIM(WS-FIELD-3)
                               "%"
               END-READ
           END-PERFORM

           CLOSE REPORT-FILE
           .

       SHOW-LABEL-COUNT-REPORT.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              Report"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "
           DISPLAY ANSI-BOLD ANSI-YELLOW
                   " CODE                         LABEL                         TOTAL     %"
                   ANSI-RESET
           DISPLAY " ------------------------------------------------------------------------------"

           MOVE "N" TO WS-EOF
           OPEN INPUT REPORT-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ REPORT-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       MOVE SPACES TO WS-FIELD-1
                       MOVE SPACES TO WS-FIELD-2
                       MOVE SPACES TO WS-FIELD-3
                       MOVE SPACES TO WS-FIELD-4

                       UNSTRING REPORT-LINE
                           DELIMITED BY "|"
                           INTO WS-FIELD-1
                                WS-FIELD-2
                                WS-FIELD-3
                                WS-FIELD-4
                       END-UNSTRING

                       DISPLAY " "
                               FUNCTION TRIM(WS-FIELD-1)
                               " | "
                               FUNCTION TRIM(WS-FIELD-2)
                               " | "
                               ANSI-GREEN
                               FUNCTION TRIM(WS-FIELD-3)
                               ANSI-RESET
                               " | "
                               FUNCTION TRIM(WS-FIELD-4)
                               "%"
               END-READ
           END-PERFORM

           CLOSE REPORT-FILE
           .

       REPORT-POSSIBLY-OUTDATED.

           MOVE 1 TO WS-PAGE-NUMBER
           MOVE "N" TO WS-OPTION

           PERFORM UNTIL WS-OPTION = "Q" OR WS-OPTION = "q"
               PERFORM CALCULATE-OFFSET
               PERFORM BUILD-POSSIBLY-OUTDATED-COMMAND
               PERFORM RUN-COMMAND
               PERFORM SHOW-POSSIBLY-OUTDATED
               PERFORM READ-POSSIBLY-OUTDATED-OPTION
           END-PERFORM

           MOVE SPACES TO WS-OPTION
           .

       CALCULATE-OFFSET.

           COMPUTE WS-OFFSET =
               (WS-PAGE-NUMBER - 1) * WS-PAGE-SIZE

           MOVE WS-OFFSET TO WS-OFFSET-TEXT
           MOVE WS-PAGE-SIZE TO WS-PAGE-SIZE-TEXT
           .

       BUILD-POSSIBLY-OUTDATED-COMMAND.

           MOVE SPACES TO WS-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_report_possibly_outdated_recruitment_trials("
             FUNCTION TRIM(WS-PAGE-SIZE-TEXT)
             ", "
             FUNCTION TRIM(WS-OFFSET-TEXT)
             ");"
             '"'
             " > reports_menu.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       SHOW-POSSIBLY-OUTDATED.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "                      Possibly Outdated Recruitment Trials"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET

           DISPLAY " "
           DISPLAY "Rule: Recruiting or Not yet recruiting with enrolment date older than 12 months."
           DISPLAY "Page: " WS-PAGE-NUMBER
           DISPLAY " "

           DISPLAY ANSI-BOLD ANSI-YELLOW
                   " ID    RBR            RECRUITMENT STATUS        ENROL DATE   MONTHS   FLAG"
                   ANSI-RESET
           DISPLAY " ----------------------------------------------------------------------------------------------------------------"

           MOVE 0 TO WS-COUNT
           MOVE "N" TO WS-EOF

           OPEN INPUT REPORT-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ REPORT-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       PERFORM PARSE-POSSIBLY-OUTDATED
                       PERFORM DISPLAY-POSSIBLY-OUTDATED
                       ADD 1 TO WS-COUNT
               END-READ
           END-PERFORM

           CLOSE REPORT-FILE

           IF WS-COUNT = 0
               DISPLAY " "
               DISPLAY ANSI-YELLOW
                       " No records found on this page."
                       ANSI-RESET
           END-IF

           DISPLAY " "
           DISPLAY " ----------------------------------------------------------------------------------------------------------------"
           DISPLAY ANSI-BOLD "N" ANSI-RESET " - Next page   "
                   ANSI-BOLD "P" ANSI-RESET " - Previous page   "
                   ANSI-BOLD "V" ANSI-RESET " - View trial   "
                   ANSI-BOLD "Q" ANSI-RESET " - Back"
           DISPLAY " ----------------------------------------------------------------------------------------------------------------"
           .

       PARSE-POSSIBLY-OUTDATED.

           MOVE SPACES TO WS-FIELD-1
           MOVE SPACES TO WS-FIELD-2
           MOVE SPACES TO WS-FIELD-3
           MOVE SPACES TO WS-FIELD-4
           MOVE SPACES TO WS-FIELD-5
           MOVE SPACES TO WS-FIELD-6
           MOVE SPACES TO WS-FIELD-7
           MOVE SPACES TO WS-FIELD-8
           MOVE SPACES TO WS-FIELD-9
           MOVE SPACES TO WS-FIELD-10

           UNSTRING REPORT-LINE
               DELIMITED BY "|"
               INTO WS-FIELD-1
                    WS-FIELD-2
                    WS-FIELD-3
                    WS-FIELD-4
                    WS-FIELD-5
                    WS-FIELD-6
                    WS-FIELD-7
                    WS-FIELD-8
                    WS-FIELD-9
                    WS-FIELD-10
           END-UNSTRING
           .

       DISPLAY-POSSIBLY-OUTDATED.

           DISPLAY " "
                   ANSI-GREEN
                   FUNCTION TRIM(WS-FIELD-1)
                   ANSI-RESET
                   " "
                   ANSI-CYAN
                   FUNCTION TRIM(WS-FIELD-2)
                   ANSI-RESET
                   " "
                   FUNCTION TRIM(WS-FIELD-4)
                   " "
                   FUNCTION TRIM(WS-FIELD-6)
                   " "
                   ANSI-YELLOW
                   FUNCTION TRIM(WS-FIELD-7)
                   ANSI-RESET
                   " "
                   ANSI-RED
                   FUNCTION TRIM(WS-FIELD-8)
                   ANSI-RESET

           DISPLAY "      "
                   FUNCTION TRIM(WS-FIELD-9)

           DISPLAY " ----------------------------------------------------------------------------------------------------------------"
           .

       READ-POSSIBLY-OUTDATED-OPTION.

           DISPLAY "Option: " WITH NO ADVANCING
           ACCEPT WS-OPTION

           EVALUATE WS-OPTION
               WHEN "N"
               WHEN "n"
                   ADD 1 TO WS-PAGE-NUMBER

               WHEN "P"
               WHEN "p"
                   IF WS-PAGE-NUMBER > 1
                       SUBTRACT 1 FROM WS-PAGE-NUMBER
                   END-IF

               WHEN "V"
               WHEN "v"
                   PERFORM ASK-VIEW-ID

               WHEN "Q"
               WHEN "q"
                   CONTINUE

               WHEN OTHER
                   DISPLAY "Invalid option."
                   DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
                   ACCEPT WS-DUMMY
           END-EVALUATE
           .

       ASK-VIEW-ID.

           DISPLAY "Enter database ID to view: " WITH NO ADVANCING
           ACCEPT WS-VIEW-ID

           IF FUNCTION TRIM(WS-VIEW-ID) NOT = SPACES
               MOVE SPACES TO WS-VIEW-COMMAND

               STRING
                   "./bin/trial_view "
                   FUNCTION TRIM(WS-VIEW-ID)
                   DELIMITED BY SIZE
                   INTO WS-VIEW-COMMAND
               END-STRING

               CALL "SYSTEM" USING WS-VIEW-COMMAND
           END-IF
           .

