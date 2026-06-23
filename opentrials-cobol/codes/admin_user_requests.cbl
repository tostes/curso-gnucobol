       IDENTIFICATION DIVISION.
       PROGRAM-ID. ADMIN-USER-REQUESTS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT REQUEST-FILE ASSIGN TO "admin_user_requests.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

           SELECT ACTION-FILE ASSIGN TO "admin_user_action.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

           SELECT LOGIN-FILE ASSIGN TO "admin_login.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.

       FD REQUEST-FILE.
       01 REQUEST-LINE PIC X(4000).

       FD ACTION-FILE.
       01 ACTION-LINE PIC X(2000).

       FD LOGIN-FILE.
       01 LOGIN-LINE PIC X(2000).

       WORKING-STORAGE SECTION.

       01 WS-COMMAND              PIC X(16000).
       01 WS-ACTION-COMMAND       PIC X(16000).
       01 WS-LOGIN-COMMAND        PIC X(16000).

       01 WS-EOF                  PIC X VALUE "N".
       01 WS-COUNT                PIC 9(4) VALUE 0.
       01 WS-OPTION               PIC X(1).
       01 WS-DUMMY                PIC X(1).

       01 WS-REQUEST-ID           PIC X(20).
       01 WS-FULL-NAME            PIC X(200).
       01 WS-EMAIL                PIC X(200).
       01 WS-USERNAME             PIC X(100).
       01 WS-ROLE                 PIC X(30).
       01 WS-REASON               PIC X(500).
       01 WS-CREATED-AT           PIC X(40).

       01 WS-ACTION-REQUEST-ID    PIC X(20).
       01 WS-INITIAL-PASSWORD     PIC X(100).
       01 WS-REVIEW-COMMENT       PIC X(500).

       01 WS-SUCCESS              PIC X(10).
       01 WS-NEW-USER-ID          PIC X(20).
       01 WS-MESSAGE              PIC X(500).

       01 WS-LOGIN-USERNAME       PIC X(100).
       01 WS-LOGIN-PASSWORD       PIC X(100).
       01 WS-LOGIN-SUCCESS        PIC X(10).
       01 WS-LOGIN-USER-ID        PIC X(20).
       01 WS-LOGIN-FULL-NAME      PIC X(200).
       01 WS-LOGIN-ROLE           PIC X(30).
       01 WS-LOGIN-MESSAGE        PIC X(500).

       01 WS-COL-ID               PIC X(6).
       01 WS-COL-USERNAME         PIC X(18).
       01 WS-COL-ROLE             PIC X(12).
       01 WS-COL-NAME             PIC X(30).
       01 WS-COL-EMAIL            PIC X(34).
       01 WS-COL-CREATED          PIC X(20).

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
           PERFORM LOGIN-AS-ADMIN

           PERFORM UNTIL WS-OPTION = "Q" OR WS-OPTION = "q"
               PERFORM BUILD-LIST-COMMAND
               CALL "SYSTEM" USING WS-COMMAND
               PERFORM SHOW-REQUESTS
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

       LOGIN-AS-ADMIN.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              ReBEC COBOL - Admin Area"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "

           DISPLAY "Username: " WITH NO ADVANCING
           ACCEPT WS-LOGIN-USERNAME

           DISPLAY "Password: " WITH NO ADVANCING
           ACCEPT WS-LOGIN-PASSWORD

           PERFORM BUILD-ADMIN-LOGIN-COMMAND
           CALL "SYSTEM" USING WS-LOGIN-COMMAND
           PERFORM READ-ADMIN-LOGIN-RESULT

           IF WS-LOGIN-SUCCESS NOT = "t"
               DISPLAY " "
               DISPLAY ANSI-RED
                       "Access denied. Admin login is required."
                       ANSI-RESET
               DISPLAY "Message: "
                       FUNCTION TRIM(WS-LOGIN-MESSAGE)
               DISPLAY " "
               DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
               ACCEPT WS-DUMMY
               STOP RUN
           END-IF

           IF FUNCTION TRIM(WS-LOGIN-ROLE) NOT = "admin"
               DISPLAY " "
               DISPLAY ANSI-RED
                       "Access denied. User is not admin."
                       ANSI-RESET
               DISPLAY "Role: " FUNCTION TRIM(WS-LOGIN-ROLE)
               DISPLAY " "
               DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
               ACCEPT WS-DUMMY
               STOP RUN
           END-IF
           .

       BUILD-ADMIN-LOGIN-COMMAND.

           MOVE SPACES TO WS-LOGIN-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".fn_app_login('"
             FUNCTION TRIM(WS-LOGIN-USERNAME)
             "', '"
             FUNCTION TRIM(WS-LOGIN-PASSWORD)
             "');"
             '"'
             " > admin_login.tmp"
             DELIMITED BY SIZE
             INTO WS-LOGIN-COMMAND
           END-STRING
           .

       READ-ADMIN-LOGIN-RESULT.

           MOVE SPACES TO WS-LOGIN-SUCCESS
           MOVE SPACES TO WS-LOGIN-USER-ID
           MOVE SPACES TO WS-LOGIN-USERNAME
           MOVE SPACES TO WS-LOGIN-FULL-NAME
           MOVE SPACES TO WS-LOGIN-ROLE
           MOVE SPACES TO WS-LOGIN-MESSAGE

           OPEN INPUT LOGIN-FILE

           READ LOGIN-FILE
               AT END
                   MOVE "f" TO WS-LOGIN-SUCCESS
                   MOVE "No response from database." TO WS-LOGIN-MESSAGE
               NOT AT END
                   UNSTRING LOGIN-LINE
                       DELIMITED BY "|"
                       INTO WS-LOGIN-SUCCESS
                            WS-LOGIN-USER-ID
                            WS-LOGIN-USERNAME
                            WS-LOGIN-FULL-NAME
                            WS-LOGIN-ROLE
                            WS-LOGIN-MESSAGE
                   END-UNSTRING
           END-READ

           CLOSE LOGIN-FILE
           .

       BUILD-LIST-COMMAND.

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
             ".fn_list_pending_user_requests();"
             '"'
             " > admin_user_requests.tmp"
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       SHOW-REQUESTS.

           DISPLAY ANSI-CLEAR
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "                              ReBEC COBOL - Pending User Requests"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "================================================================================================================"
                   ANSI-RESET

           DISPLAY " "
           DISPLAY " Logged admin: "
                   FUNCTION TRIM(WS-LOGIN-USERNAME)
                   " | User ID: "
                   FUNCTION TRIM(WS-LOGIN-USER-ID)
           DISPLAY " "

           DISPLAY ANSI-BOLD ANSI-YELLOW
                   " ID    USERNAME          ROLE        FULL NAME                     EMAIL                              CREATED"
                   ANSI-RESET
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"

           MOVE 0 TO WS-COUNT
           MOVE "N" TO WS-EOF

           OPEN INPUT REQUEST-FILE

           PERFORM UNTIL WS-EOF = "Y"
               READ REQUEST-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       PERFORM PARSE-REQUEST-LINE
                       PERFORM DISPLAY-REQUEST
                       ADD 1 TO WS-COUNT
               END-READ
           END-PERFORM

           CLOSE REQUEST-FILE

           IF WS-COUNT = 0
               DISPLAY " "
               DISPLAY ANSI-YELLOW
                       " No pending user requests."
                       ANSI-RESET
           END-IF

           DISPLAY " "
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"
           DISPLAY ANSI-BOLD "A" ANSI-RESET " - Approve   "
                   ANSI-BOLD "R" ANSI-RESET " - Reject   "
                   ANSI-BOLD "F" ANSI-RESET " - Refresh   "
                   ANSI-BOLD "Q" ANSI-RESET " - Quit"
           DISPLAY
                   " ----------------------------------------------------------------------------------------------------------------"
           .

       PARSE-REQUEST-LINE.

           MOVE SPACES TO WS-REQUEST-ID
           MOVE SPACES TO WS-FULL-NAME
           MOVE SPACES TO WS-EMAIL
           MOVE SPACES TO WS-USERNAME
           MOVE SPACES TO WS-ROLE
           MOVE SPACES TO WS-REASON
           MOVE SPACES TO WS-CREATED-AT

           UNSTRING REQUEST-LINE
               DELIMITED BY "|"
               INTO WS-REQUEST-ID
                    WS-FULL-NAME
                    WS-EMAIL
                    WS-USERNAME
                    WS-ROLE
                    WS-REASON
                    WS-CREATED-AT
           END-UNSTRING
           .

       DISPLAY-REQUEST.

           MOVE SPACES TO WS-COL-ID
           MOVE SPACES TO WS-COL-USERNAME
           MOVE SPACES TO WS-COL-ROLE
           MOVE SPACES TO WS-COL-NAME
           MOVE SPACES TO WS-COL-EMAIL
           MOVE SPACES TO WS-COL-CREATED

           MOVE FUNCTION TRIM(WS-REQUEST-ID) TO WS-COL-ID
           MOVE FUNCTION TRIM(WS-USERNAME) TO WS-COL-USERNAME
           MOVE FUNCTION TRIM(WS-ROLE) TO WS-COL-ROLE
           MOVE FUNCTION TRIM(WS-FULL-NAME) TO WS-COL-NAME
           MOVE FUNCTION TRIM(WS-EMAIL) TO WS-COL-EMAIL
           MOVE FUNCTION TRIM(WS-CREATED-AT) TO WS-COL-CREATED

           DISPLAY
               " "
               ANSI-GREEN WS-COL-ID ANSI-RESET
               " "
               ANSI-CYAN WS-COL-USERNAME ANSI-RESET
               " "
               ANSI-YELLOW WS-COL-ROLE ANSI-RESET
               " "
               WS-COL-NAME
               " "
               WS-COL-EMAIL
               " "
               WS-COL-CREATED

           IF FUNCTION TRIM(WS-REASON) NOT = SPACES
               DISPLAY "       Reason: " FUNCTION TRIM(WS-REASON)
           END-IF

           DISPLAY
               " ----------------------------------------------------------------------------------------------------------------"
           .

       READ-OPTION.

           DISPLAY "Option: " WITH NO ADVANCING
           ACCEPT WS-OPTION

           EVALUATE WS-OPTION
               WHEN "A"
               WHEN "a"
                   PERFORM APPROVE-REQUEST

               WHEN "R"
               WHEN "r"
                   PERFORM REJECT-REQUEST

               WHEN "F"
               WHEN "f"
                   CONTINUE

               WHEN "Q"
               WHEN "q"
                   CONTINUE

               WHEN OTHER
                   DISPLAY "Invalid option."
                   DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
                   ACCEPT WS-DUMMY
           END-EVALUATE
           .

       APPROVE-REQUEST.

           DISPLAY "Request ID to approve: " WITH NO ADVANCING
           ACCEPT WS-ACTION-REQUEST-ID

           IF FUNCTION TRIM(WS-ACTION-REQUEST-ID) = SPACES
               DISPLAY "No request ID provided."
               DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
               ACCEPT WS-DUMMY
           ELSE
               DISPLAY "Initial password for new user: " WITH NO ADVANCING
               ACCEPT WS-INITIAL-PASSWORD

               PERFORM BUILD-APPROVE-COMMAND
               CALL "SYSTEM" USING WS-ACTION-COMMAND
               PERFORM READ-ACTION-RESULT
               PERFORM SHOW-ACTION-RESULT
           END-IF
           .

       BUILD-APPROVE-COMMAND.

           MOVE SPACES TO WS-ACTION-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".sp_approve_user_request("
             FUNCTION TRIM(WS-ACTION-REQUEST-ID)
             ", "
             FUNCTION TRIM(WS-LOGIN-USER-ID)
             ", '"
             FUNCTION TRIM(WS-INITIAL-PASSWORD)
             "');"
             '"'
             " > admin_user_action.tmp"
             DELIMITED BY SIZE
             INTO WS-ACTION-COMMAND
           END-STRING
           .

       REJECT-REQUEST.

           DISPLAY "Request ID to reject: " WITH NO ADVANCING
           ACCEPT WS-ACTION-REQUEST-ID

           IF FUNCTION TRIM(WS-ACTION-REQUEST-ID) = SPACES
               DISPLAY "No request ID provided."
               DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
               ACCEPT WS-DUMMY
           ELSE
               DISPLAY "Review comment: " WITH NO ADVANCING
               ACCEPT WS-REVIEW-COMMENT

               PERFORM BUILD-REJECT-COMMAND
               CALL "SYSTEM" USING WS-ACTION-COMMAND
               PERFORM READ-ACTION-RESULT
               PERFORM SHOW-ACTION-RESULT
           END-IF
           .

       BUILD-REJECT-COMMAND.

           MOVE SPACES TO WS-ACTION-COMMAND

           STRING
             "psql "
             "-h " FUNCTION TRIM(DB-HOST) " "
             "-p " FUNCTION TRIM(DB-PORT) " "
             "-U " FUNCTION TRIM(DB-USER) " "
             "-d " FUNCTION TRIM(DB-NAME) " "
             "-At -F '|' -c "
             '"SELECT * FROM '
             FUNCTION TRIM(DB-SCHEMA)
             ".sp_reject_user_request("
             FUNCTION TRIM(WS-ACTION-REQUEST-ID)
             ", "
             FUNCTION TRIM(WS-LOGIN-USER-ID)
             ", '"
             FUNCTION TRIM(WS-REVIEW-COMMENT)
             "');"
             '"'
             " > admin_user_action.tmp"
             DELIMITED BY SIZE
             INTO WS-ACTION-COMMAND
           END-STRING
           .

       READ-ACTION-RESULT.

           MOVE SPACES TO WS-SUCCESS
           MOVE SPACES TO WS-NEW-USER-ID
           MOVE SPACES TO WS-MESSAGE

           OPEN INPUT ACTION-FILE

           READ ACTION-FILE
               AT END
                   MOVE "f" TO WS-SUCCESS
                   MOVE "No response from database." TO WS-MESSAGE
               NOT AT END
                   UNSTRING ACTION-LINE
                       DELIMITED BY "|"
                       INTO WS-SUCCESS
                            WS-NEW-USER-ID
                            WS-MESSAGE
                   END-UNSTRING
           END-READ

           CLOSE ACTION-FILE
           .

       SHOW-ACTION-RESULT.

           DISPLAY " "
           DISPLAY ANSI-BOLD ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY ANSI-BOLD
                   "              Action Result"
                   ANSI-RESET
           DISPLAY ANSI-CYAN
                   "============================================================"
                   ANSI-RESET
           DISPLAY " "

           IF WS-SUCCESS = "t"
               DISPLAY ANSI-GREEN
                       "Action completed successfully."
                       ANSI-RESET
               DISPLAY " "
               IF FUNCTION TRIM(WS-NEW-USER-ID) NOT = SPACES
                   DISPLAY "New user ID: "
                           FUNCTION TRIM(WS-NEW-USER-ID)
               END-IF
               DISPLAY "Message    : " FUNCTION TRIM(WS-MESSAGE)
           ELSE
               DISPLAY ANSI-RED
                       "Action failed."
                       ANSI-RESET
               DISPLAY " "
               DISPLAY "Message    : " FUNCTION TRIM(WS-MESSAGE)
           END-IF

           DISPLAY " "
           DISPLAY "Press ENTER to continue..." WITH NO ADVANCING
           ACCEPT WS-DUMMY
           .
