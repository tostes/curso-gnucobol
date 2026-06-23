       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOGIN.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LOGIN-FILE ASSIGN TO "login_result.tmp"
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD LOGIN-FILE.
       01 LOGIN-LINE PIC X(1000).

       WORKING-STORAGE SECTION.
       01 WS-COMMAND        PIC X(12000).

       01 WS-USERNAME-IN    PIC X(80).
       01 WS-PASSWORD-IN    PIC X(80).

       01 WS-LOGIN-SUCCESS  PIC X(5).
       01 WS-USER-ID        PIC X(20).
       01 WS-USERNAME       PIC X(80).
       01 WS-FULL-NAME      PIC X(200).
       01 WS-ROLE           PIC X(30).
       01 WS-MESSAGE        PIC X(200).

       COPY "db_config.cpy".

       LINKAGE SECTION.
       COPY "session.cpy".
       01 LS-REQUIRED-ROLE  PIC X(30).

       PROCEDURE DIVISION USING APP-SESSION LS-REQUIRED-ROLE.

       MAIN-PROCEDURE.

           PERFORM LOAD-CONFIG

           IF SESSION-LOGGED-IN = "Y"
               PERFORM CHECK-ROLE
               GOBACK
           END-IF

           PERFORM ASK-CREDENTIALS
           PERFORM CLEAN-INPUTS
           PERFORM BUILD-COMMAND
           CALL "SYSTEM" USING WS-COMMAND

           OPEN INPUT LOGIN-FILE

           READ LOGIN-FILE
               AT END
                   MOVE "ERROR" TO SESSION-STATUS
                   MOVE "Login failed: empty database response"
                       TO SESSION-MESSAGE
                   CLOSE LOGIN-FILE
                   GOBACK
               NOT AT END
                   PERFORM PARSE-LOGIN-LINE
           END-READ

           CLOSE LOGIN-FILE

           IF WS-LOGIN-SUCCESS = "t"
               MOVE "Y" TO SESSION-LOGGED-IN
               MOVE WS-USER-ID TO SESSION-USER-ID
               MOVE WS-USERNAME TO SESSION-USERNAME
               MOVE WS-FULL-NAME TO SESSION-FULL-NAME
               MOVE WS-ROLE TO SESSION-ROLE
               MOVE "OK" TO SESSION-STATUS
               MOVE "Login successful" TO SESSION-MESSAGE
               PERFORM CHECK-ROLE
           ELSE
               MOVE "N" TO SESSION-LOGGED-IN
               MOVE "ERROR" TO SESSION-STATUS
               MOVE FUNCTION TRIM(WS-MESSAGE) TO SESSION-MESSAGE
           END-IF

           GOBACK.

       LOAD-CONFIG.

           CALL "LOADCONF" USING DB-CONFIG

           IF DB-STATUS NOT = "OK"
               MOVE "ERROR" TO SESSION-STATUS
               MOVE DB-MESSAGE TO SESSION-MESSAGE
               GOBACK
           END-IF
           .

       ASK-CREDENTIALS.

           DISPLAY " "
           DISPLAY "==============================================="
           DISPLAY "              REBEC COBOL LOGIN"
           DISPLAY "==============================================="
           DISPLAY " "

           DISPLAY "Username: " WITH NO ADVANCING
           ACCEPT WS-USERNAME-IN

           DISPLAY "Password: " WITH NO ADVANCING
           ACCEPT WS-PASSWORD-IN

           DISPLAY " "
           .

       CLEAN-INPUTS.

           INSPECT WS-USERNAME-IN REPLACING ALL "'" BY " "
           INSPECT WS-PASSWORD-IN REPLACING ALL "'" BY " "
           INSPECT WS-USERNAME-IN REPLACING ALL "|" BY " "
           INSPECT WS-PASSWORD-IN REPLACING ALL "|" BY " "
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
             'login_success, '
             'coalesce(user_id::text, ''''), '
             'coalesce(username, ''''), '
             'replace(coalesce(full_name, ''''), ''|'', '' ''), '
             'coalesce(role_code, ''''), '
             'replace(coalesce(message, ''''), ''|'', '' '') '
             'FROM '
             FUNCTION TRIM(DB-SCHEMA)
             '.fn_app_login('''
             FUNCTION TRIM(WS-USERNAME-IN)
             ''', '''
             FUNCTION TRIM(WS-PASSWORD-IN)
             ''');" > login_result.tmp'
             DELIMITED BY SIZE
             INTO WS-COMMAND
           END-STRING
           .

       PARSE-LOGIN-LINE.

           MOVE SPACES TO WS-LOGIN-SUCCESS
           MOVE SPACES TO WS-USER-ID
           MOVE SPACES TO WS-USERNAME
           MOVE SPACES TO WS-FULL-NAME
           MOVE SPACES TO WS-ROLE
           MOVE SPACES TO WS-MESSAGE

           UNSTRING LOGIN-LINE
               DELIMITED BY "|"
               INTO WS-LOGIN-SUCCESS
                    WS-USER-ID
                    WS-USERNAME
                    WS-FULL-NAME
                    WS-ROLE
                    WS-MESSAGE
           END-UNSTRING
           .

       CHECK-ROLE.

           IF FUNCTION TRIM(LS-REQUIRED-ROLE) = SPACES
               MOVE "OK" TO SESSION-STATUS
               GOBACK
           END-IF

           IF FUNCTION TRIM(SESSION-ROLE) =
              FUNCTION TRIM(LS-REQUIRED-ROLE)
               MOVE "OK" TO SESSION-STATUS
               GOBACK
           END-IF

           IF FUNCTION TRIM(SESSION-ROLE) = "admin"
               MOVE "OK" TO SESSION-STATUS
               GOBACK
           END-IF

           MOVE "DENIED" TO SESSION-STATUS
           STRING
              "Access denied. Required role: "
              FUNCTION TRIM(LS-REQUIRED-ROLE)
              DELIMITED BY SIZE
              INTO SESSION-MESSAGE
           END-STRING
           .

