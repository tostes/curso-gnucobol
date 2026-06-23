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
       01 TRIAL-LINE PIC X(5000).

       WORKING-STORAGE SECTION.

       01 WS-COMMAND              PIC X(12000).

       01 WS-PAGE-SIZE            PIC 9(4) VALUE 20.
       01 WS-PAGE-NUMBER          PIC 9(4) VALUE 1.
       01 WS-OFFSET               PIC 9(8) VALUE 0.
       01 WS-OFFSET-TEXT          PIC X(20).
       01 WS-PAGE-SIZE-TEXT       PIC X(20).

       01 WS-EOF                  PIC X VALUE "N".
       01 WS-COUNT                PIC 9(4) VALUE 0.
       01 WS-OPTION               PIC X(1).
       01 WS-DUMMY                PIC X(1).

       01 WS-ID                   PIC X(20).
       01 WS-TRIAL-ID             PIC X(80).
       01 WS-STATUS               PIC X(40).
       01 WS-REG-DATE             PIC X(40).
       01 WS-PUBLIC-TITLE         PIC X(250).
       01 WS-RECRUITMENT-STATUS   PIC X(80).
       01 WS-STUDY-TYPE           PIC X(80).

       01 WS-COL-ID               PIC X(6).
       01 WS-COL-RBR              PIC X(14).
       01 WS-COL-DATE             PIC X(12).
       01 WS-COL-STATUS           PIC X(12).
       01 WS-COL-TITLE            PIC X(74).
       01 WS-COL-RECRUITMENT      PIC X(34).
       01 WS-COL-TYPE             PIC X(18).

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
               PERFORM CALCULATE-OFFSET
               PERFORM BUILD-COMMAND
               CALL "SYSTEM" USING WS-COMMAND
               PERFORM SHOW-PAGE
               PERFORM READ-OPTION
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

       CALCULATE-OFFSET.

           COMPUTE WS-OFFSET =
               (WS-PAGE-NUMBER - 1) * WS-PAGE-SIZE

           MOVE WS-OFFSET TO WS-OFFSET-TEXT
           MOVE WS-PAGE-SIZE TO WS-PAGE-SIZE-TEXT
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
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             '.fn_public_trial_list('
             FUNCTION TRIM(WS-PAGE-SIZE-TEXT)
             ', '
             FUNCTION TRIM(WS-OFFSET-TEXT)
             ');" > trial_list.tmp'
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       SHOW-PAGE.

           DISPLAY ANSI-CLEAR

           DISPLAY ANSI-BOLD ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "                                      ReBEC COBOL - Public Trials"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET

           DISPLAY " "
           DISPLAY " Page: " WS-PAGE-NUMBER
           DISPLAY " "

           DISPLAY ANSI-BOLD ANSI-YELLOW
                   " ID    RBR            DATE         STATUS       TYPE               RECRUITMENT                        TITLE"
                   ANSI-RESET
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"


           MOVE 0 TO WS-COUNT
           MOVE "N" TO WS-EOF

           OPEN INPUT TRIAL-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ TRIAL-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       PERFORM PARSE-LINE
                       PERFORM DISPLAY-TRIAL
                       ADD 1 TO WS-COUNT
               END-READ
           END-PERFORM

           CLOSE TRIAL-FILE

           IF WS-COUNT = 0
               DISPLAY " "
               DISPLAY ANSI-YELLOW
                       " No public trials found on this page."
                       ANSI-RESET
           END-IF

           DISPLAY " "
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"
           DISPLAY ANSI-BOLD
                   " N"
                   ANSI-RESET
                   " - Next page   "
                   ANSI-BOLD
                   "P"
                   ANSI-RESET
                   " - Previous page   "
                   ANSI-BOLD
                   "V"
                   ANSI-RESET
                   " - View trial   "
                   ANSI-BOLD
                   "Q"
                   ANSI-RESET
                   " - Quit"
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"
           .

       PARSE-LINE.

           MOVE SPACES TO WS-ID
           MOVE SPACES TO WS-TRIAL-ID
           MOVE SPACES TO WS-STATUS
           MOVE SPACES TO WS-REG-DATE
           MOVE SPACES TO WS-PUBLIC-TITLE
           MOVE SPACES TO WS-RECRUITMENT-STATUS
           MOVE SPACES TO WS-STUDY-TYPE

           UNSTRING TRIAL-LINE
               DELIMITED BY "|"
               INTO WS-ID
                    WS-TRIAL-ID
                    WS-STATUS
                    WS-REG-DATE
                    WS-PUBLIC-TITLE
                    WS-RECRUITMENT-STATUS
                    WS-STUDY-TYPE
           END-UNSTRING
           .

       DISPLAY-TRIAL.

           MOVE SPACES TO WS-COL-ID
           MOVE SPACES TO WS-COL-RBR
           MOVE SPACES TO WS-COL-DATE
           MOVE SPACES TO WS-COL-STATUS
           MOVE SPACES TO WS-COL-TITLE
           MOVE SPACES TO WS-COL-RECRUITMENT
           MOVE SPACES TO WS-COL-TYPE

           MOVE FUNCTION TRIM(WS-ID) TO WS-COL-ID
           MOVE FUNCTION TRIM(WS-TRIAL-ID) TO WS-COL-RBR
           MOVE FUNCTION TRIM(WS-REG-DATE) TO WS-COL-DATE
           MOVE FUNCTION TRIM(WS-STATUS) TO WS-COL-STATUS
           MOVE FUNCTION TRIM(WS-PUBLIC-TITLE) TO WS-COL-TITLE
           MOVE FUNCTION TRIM(WS-RECRUITMENT-STATUS)
               TO WS-COL-RECRUITMENT
           MOVE FUNCTION TRIM(WS-STUDY-TYPE) TO WS-COL-TYPE

           DISPLAY
               ANSI-GREEN WS-COL-ID ANSI-RESET
               " "
               ANSI-CYAN WS-COL-RBR ANSI-RESET
               " "
               WS-COL-DATE
               " "
               ANSI-YELLOW WS-COL-STATUS ANSI-RESET
               " "
               WS-COL-TYPE
               " "
               WS-COL-RECRUITMENT
               " "
               WS-COL-TITLE
           .


       READ-OPTION.

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
               MOVE "./bin/trial_view" TO WS-VIEW-COMMAND
               CALL "SYSTEM" USING WS-VIEW-COMMAND
           END-IF
           .
