       IDENTIFICATION DIVISION.
       PROGRAM-ID. REQUEST-USER.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REQUEST-FILE ASSIGN TO "request_user.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD REQUEST-FILE.
       01 REQUEST-LINE PIC X(2000).

       WORKING-STORAGE SECTION.

       01 WS-COMMAND              PIC X(12000).

       01 WS-FULL-NAME            PIC X(200).
       01 WS-EMAIL                PIC X(200).
       01 WS-USERNAME             PIC X(100).
       01 WS-ROLE-OPTION          PIC X(1).
       01 WS-REQUESTED-ROLE       PIC X(30).
       01 WS-REASON               PIC X(500).

       01 WS-SUCCESS              PIC X(10).
       01 WS-REQUEST-ID           PIC X(20).
       01 WS-MESSAGE              PIC X(500).

       01 WS-DUMMY                PIC X(1).
       01 WS-EOF                  PIC X VALUE "N".

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
           PERFORM SHOW-FORM
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

       SHOW-FORM.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              ReBEC COBOL - Request User Access"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET

           DISPLAY " "
           DISPLAY "This screen creates a pending account request."
           DISPLAY "An administrator must approve it later."
           DISPLAY " "

           DISPLAY "Full name: " WITH NO ADVANCING
           ACCEPT WS-FULL-NAME

           DISPLAY "Email: " WITH NO ADVANCING
           ACCEPT WS-EMAIL

           DISPLAY "Requested username: " WITH NO ADVANCING
           ACCEPT WS-USERNAME

           DISPLAY " "
           DISPLAY "Requested role:"
           DISPLAY "  1 - Registrant"
           DISPLAY "  2 - Reviewer"
           DISPLAY " "
           DISPLAY "Option: " WITH NO ADVANCING
           ACCEPT WS-ROLE-OPTION

           IF WS-ROLE-OPTION = "2"
               MOVE "reviewer" TO WS-REQUESTED-ROLE
           ELSE
               MOVE "registrant" TO WS-REQUESTED-ROLE
           END-IF

           DISPLAY " "
           DISPLAY "Reason for access request:"
           ACCEPT WS-REASON
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
             ".fn_request_user_access('"
             FUNCTION TRIM(WS-FULL-NAME)
             "', '"
             FUNCTION TRIM(WS-EMAIL)
             "', '"
             FUNCTION TRIM(WS-USERNAME)
             "', '"
             FUNCTION TRIM(WS-REQUESTED-ROLE)
             "', '"
             FUNCTION TRIM(WS-REASON)
             "');" '"'
             " > request_user.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       READ-RESULT.

           MOVE SPACES TO WS-SUCCESS
           MOVE SPACES TO WS-REQUEST-ID
           MOVE SPACES TO WS-MESSAGE

           OPEN INPUT REQUEST-FILE

           READ REQUEST-FILE
               AT END
                   MOVE "f" TO WS-SUCCESS
                   MOVE "No response from database." TO WS-MESSAGE
               NOT AT END
                   UNSTRING REQUEST-LINE
                       DELIMITED BY "|"
                       INTO WS-SUCCESS
                            WS-REQUEST-ID
                            WS-MESSAGE
                   END-UNSTRING
           END-READ

           CLOSE REQUEST-FILE
           .

       SHOW-RESULT.

           DISPLAY " "
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              Request Result"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "

           IF WS-SUCCESS = "t"
               DISPLAY ANSI-GREEN
                       "Request created successfully."
                       ANSI-RESET
               DISPLAY " "
               DISPLAY "Request ID: " FUNCTION TRIM(WS-REQUEST-ID)
               DISPLAY "Message   : " FUNCTION TRIM(WS-MESSAGE)
           ELSE
               DISPLAY ANSI-RED
                       "Request was not created."
                       ANSI-RESET
               DISPLAY " "
               DISPLAY "Message   : " FUNCTION TRIM(WS-MESSAGE)
           END-IF
           .
