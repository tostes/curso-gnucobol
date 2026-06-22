       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRIAL-LIST.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRIAL-FILE ASSIGN TO "trial_list.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD TRIAL-FILE.
       01 TRIAL-LINE PIC X(600).

       WORKING-STORAGE SECTION.
       01 WS-COMMAND        PIC X(10000).
       01 WS-EOF            PIC X VALUE "N".
       01 WS-OPTION         PIC X(1).
       01 WS-DUMMY          PIC X(1).

       01 WS-PAGE           PIC 9(6) VALUE 1.
       01 WS-PAGE-SIZE      PIC 9(3) VALUE 20.
       01 WS-OFFSET         PIC 9(9) VALUE 0.
       01 WS-ROWS           PIC 9(3) VALUE 0.
       01 WS-LAST-EMPTY     PIC X VALUE "N".

       01 WS-ID             PIC X(20).
       01 WS-TRIAL-ID       PIC X(40).
       01 WS-STATUS         PIC X(30).
       01 WS-TITLE          PIC X(350).

       COPY "db_config.cpy".

       01 ESC               PIC X VALUE X"1B".
       01 C-RESET           PIC X(10).
       01 C-BOLD            PIC X(10).
       01 C-RED             PIC X(10).
       01 C-GREEN           PIC X(10).
       01 C-YELLOW          PIC X(10).
       01 C-CYAN            PIC X(10).
       01 C-WHITE           PIC X(10).

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.

           PERFORM INIT-COLORS
           PERFORM LOAD-CONFIG

           PERFORM UNTIL WS-OPTION = "Q" OR WS-OPTION = "q"
               PERFORM CALCULATE-OFFSET
               PERFORM BUILD-COMMAND
               CALL "SYSTEM" USING WS-COMMAND
               PERFORM SHOW-PAGE
               PERFORM READ-OPTION
               PERFORM PROCESS-OPTION
           END-PERFORM

           PERFORM CLEAR-SCREEN
           DISPLAY C-GREEN "Returning to main menu..." C-RESET
           DISPLAY " "

           STOP RUN.

       LOAD-CONFIG.

           CALL "LOADCONF" USING DB-CONFIG

           IF DB-STATUS NOT = "OK"
               DISPLAY " "
               DISPLAY C-RED "Configuration error." C-RESET
               DISPLAY "Message: " FUNCTION TRIM(DB-MESSAGE)
               DISPLAY " "
               STOP RUN
           END-IF
           .

       INIT-COLORS.

           STRING ESC "[0m"  DELIMITED BY SIZE INTO C-RESET
           STRING ESC "[1m"  DELIMITED BY SIZE INTO C-BOLD
           STRING ESC "[31m" DELIMITED BY SIZE INTO C-RED
           STRING ESC "[32m" DELIMITED BY SIZE INTO C-GREEN
           STRING ESC "[33m" DELIMITED BY SIZE INTO C-YELLOW
           STRING ESC "[36m" DELIMITED BY SIZE INTO C-CYAN
           STRING ESC "[37m" DELIMITED BY SIZE INTO C-WHITE
           .

       CLEAR-SCREEN.

           MOVE "clear" TO WS-COMMAND
           CALL "SYSTEM" USING WS-COMMAND
           .

       CALCULATE-OFFSET.

           COMPUTE WS-OFFSET = (WS-PAGE - 1) * WS-PAGE-SIZE
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
             'replace(replace(coalesce(status, ''''), '
             'chr(10), '' ''), ''|'', '' ''), '
             'replace(replace(left(coalesce(public_title, ''''), 80), '
             'chr(10), '' ''), ''|'', '' '') '
             'FROM '
             FUNCTION TRIM(DB-SCHEMA)
             '.trial '
             'ORDER BY id '
             'LIMIT 20 OFFSET '
             WS-OFFSET
             ';" > trial_list.tmp'
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       SHOW-PAGE.

           MOVE "N" TO WS-EOF
           MOVE 0 TO WS-ROWS
           MOVE "N" TO WS-LAST-EMPTY

           PERFORM CLEAR-SCREEN

           DISPLAY C-CYAN
           DISPLAY "=============================================================="
           DISPLAY "||              REBEC COBOL - TRIAL LIST                    ||"
           DISPLAY "=============================================================="
           DISPLAY C-RESET

           DISPLAY C-YELLOW "Page: " C-RESET WS-PAGE
           DISPLAY " "

           DISPLAY C-BOLD
           DISPLAY "ID        TRIAL ID             STATUS        TITLE"
           DISPLAY C-RESET
           DISPLAY "--------------------------------------------------------------"

           OPEN INPUT TRIAL-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ TRIAL-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       ADD 1 TO WS-ROWS
                       PERFORM PARSE-AND-DISPLAY
               END-READ
           END-PERFORM

           CLOSE TRIAL-FILE

           IF WS-ROWS = 0
               MOVE "Y" TO WS-LAST-EMPTY
               DISPLAY " "
               DISPLAY C-RED "No records found on this page." C-RESET
               DISPLAY " "
           END-IF

           DISPLAY "--------------------------------------------------------------"
           DISPLAY " "

           DISPLAY C-GREEN  "N" C-RESET " - Next page    "
                   C-GREEN  "P" C-RESET " - Previous page    "
                   C-YELLOW "V" C-RESET " - View trial    "
                   C-RED    "Q" C-RESET " - Quit"

           DISPLAY " "
           .

       PARSE-AND-DISPLAY.

           MOVE SPACES TO WS-ID
           MOVE SPACES TO WS-TRIAL-ID
           MOVE SPACES TO WS-STATUS
           MOVE SPACES TO WS-TITLE

           UNSTRING TRIAL-LINE
               DELIMITED BY "|"
               INTO WS-ID
                    WS-TRIAL-ID
                    WS-STATUS
                    WS-TITLE
           END-UNSTRING

           DISPLAY
               WS-ID(1:8) "  "
               WS-TRIAL-ID(1:18) "  "
               WS-STATUS(1:12) "  "
               WS-TITLE(1:80)
           .

       READ-OPTION.

           DISPLAY "Choose option: " WITH NO ADVANCING
           ACCEPT WS-OPTION
           .

       PROCESS-OPTION.

           EVALUATE WS-OPTION

               WHEN "N"
               WHEN "n"
                   ADD 1 TO WS-PAGE

               WHEN "P"
               WHEN "p"
                   IF WS-PAGE > 1
                       SUBTRACT 1 FROM WS-PAGE
                   ELSE
                       DISPLAY " "
                       DISPLAY C-YELLOW
                               "You are already on the first page."
                               C-RESET
                       PERFORM PRESS-ENTER
                   END-IF

               WHEN "V"
               WHEN "v"
                   PERFORM RUN-TRIAL-VIEW

               WHEN "Q"
               WHEN "q"
                   CONTINUE

               WHEN OTHER
                   DISPLAY " "
                   DISPLAY C-RED "Invalid option." C-RESET
                   PERFORM PRESS-ENTER

           END-EVALUATE
           .

       RUN-TRIAL-VIEW.

           PERFORM CLEAR-SCREEN
           MOVE "./bin/trial_view" TO WS-COMMAND
           CALL "SYSTEM" USING WS-COMMAND
           PERFORM PRESS-ENTER
           .

       PRESS-ENTER.

           DISPLAY " "
           DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
           ACCEPT WS-DUMMY
           .
           