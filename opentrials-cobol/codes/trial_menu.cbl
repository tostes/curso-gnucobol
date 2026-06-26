       IDENTIFICATION DIVISION.
       PROGRAM-ID. TRIAL-MENU.

       DATA DIVISION.
       WORKING-STORAGE SECTION.

       01 WS-OPTION        PIC X(1).
       01 WS-DUMMY         PIC X(1).
       01 WS-COMMAND       PIC X(300).
       01 WS-EXIT-FLAG     PIC X VALUE "N".

       01 ESC              PIC X VALUE X"1B".
       01 C-RESET          PIC X(10).
       01 C-BOLD           PIC X(10).
       01 C-RED            PIC X(10).
       01 C-GREEN          PIC X(10).
       01 C-YELLOW         PIC X(10).
       01 C-BLUE           PIC X(10).
       01 C-CYAN           PIC X(10).
       01 C-WHITE          PIC X(10).

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.

           PERFORM INIT-COLORS

           PERFORM UNTIL WS-EXIT-FLAG = "Y"
               PERFORM CLEAR-SCREEN
               PERFORM SHOW-MENU
               PERFORM READ-OPTION
               PERFORM PROCESS-OPTION
           END-PERFORM

           PERFORM CLEAR-SCREEN
           DISPLAY C-GREEN "REBEC COBOL closed." C-RESET
           DISPLAY " "

           STOP RUN.

       INIT-COLORS.

           STRING ESC "[0m"  DELIMITED BY SIZE INTO C-RESET
           STRING ESC "[1m"  DELIMITED BY SIZE INTO C-BOLD
           STRING ESC "[31m" DELIMITED BY SIZE INTO C-RED
           STRING ESC "[32m" DELIMITED BY SIZE INTO C-GREEN
           STRING ESC "[33m" DELIMITED BY SIZE INTO C-YELLOW
           STRING ESC "[34m" DELIMITED BY SIZE INTO C-BLUE
           STRING ESC "[36m" DELIMITED BY SIZE INTO C-CYAN
           STRING ESC "[37m" DELIMITED BY SIZE INTO C-WHITE
           .

       CLEAR-SCREEN.

           MOVE "clear" TO WS-COMMAND
           CALL "SYSTEM" USING WS-COMMAND
           .

       SHOW-MENU.

           DISPLAY C-CYAN
           DISPLAY "=============================================================="
           DISPLAY "||                                                          ||"
           DISPLAY "||              REBEC COBOL DATABASE SYSTEM                 ||"
           DISPLAY "||                                                          ||"
           DISPLAY "=============================================================="
           DISPLAY C-RESET

           DISPLAY C-YELLOW
           DISPLAY "  Brazilian Clinical Trials Registry - COBOL Study Version"
           DISPLAY C-RESET

           DISPLAY " "
           DISPLAY C-GREEN "  Database: " C-RESET "PostgreSQL / rebec_cobol"
           DISPLAY C-GREEN "  Module  : " C-RESET "Clinical Trial Registry"
           DISPLAY C-GREEN "  Mode    : " C-RESET "Terminal Application"
           DISPLAY " "

           DISPLAY C-CYAN
           DISPLAY "--------------------------------------------------------------"
           DISPLAY C-RESET

           DISPLAY C-BOLD "  MAIN MENU" C-RESET
           DISPLAY " "

           DISPLAY C-GREEN  "  1" C-RESET " - List trials"
           DISPLAY C-GREEN  "  2" C-RESET " - View trial by database ID or RBR"
           DISPLAY C-YELLOW "  3" C-RESET " - Insert new trial              [coming soon]"
           DISPLAY C-YELLOW "  4" C-RESET " - Review / approve trial       [coming soon]"
           DISPLAY C-YELLOW "  r/R" C-RESET " - Reports"
           DISPLAY C-RED    "  0" C-RESET " - Exit"

           DISPLAY " "
           DISPLAY C-CYAN
           DISPLAY "--------------------------------------------------------------"
           DISPLAY C-RESET
           DISPLAY " "
           .

       READ-OPTION.

           DISPLAY "Choose option: " WITH NO ADVANCING
           ACCEPT WS-OPTION
           .

       PROCESS-OPTION.

           EVALUATE WS-OPTION

               WHEN "1"
                   PERFORM RUN-TRIAL-LIST

               WHEN "2"
                   PERFORM RUN-TRIAL-VIEW

               WHEN "3"
                   PERFORM COMING-SOON

               WHEN "4"
                   PERFORM COMING-SOON

               WHEN "5"
                   PERFORM COMING-SOON

               WHEN "0"
                       MOVE "Y" TO WS-EXIT-FLAG

               WHEN "R"
               WHEN "r"
                   PERFORM OPEN-REPORTS-MENU

               WHEN OTHER
                   DISPLAY " "
                   DISPLAY C-RED "Invalid option." C-RESET
                   PERFORM PRESS-ENTER

           END-EVALUATE
           .

       RUN-TRIAL-LIST.

           PERFORM CLEAR-SCREEN
           MOVE "./bin/trial_list" TO WS-COMMAND
           CALL "SYSTEM" USING WS-COMMAND
           PERFORM PRESS-ENTER
           .

       RUN-TRIAL-VIEW.

           PERFORM CLEAR-SCREEN
           MOVE "./bin/trial_view" TO WS-COMMAND
           CALL "SYSTEM" USING WS-COMMAND
           PERFORM PRESS-ENTER
           .

       OPEN-REPORTS-MENU.

           CALL "SYSTEM" USING "./bin/reports_menu"
           .

       COMING-SOON.

           DISPLAY " "
           DISPLAY C-YELLOW "This module is not implemented yet." C-RESET
           DISPLAY " "
           PERFORM PRESS-ENTER
           .

       PRESS-ENTER.

           DISPLAY " "
           DISPLAY "Press ENTER to return to main menu..." WITH NO ADVANCING
           ACCEPT WS-DUMMY
           .
           
