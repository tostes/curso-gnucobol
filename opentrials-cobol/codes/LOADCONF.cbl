       IDENTIFICATION DIVISION.
       PROGRAM-ID. LOADCONF.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CONF-FILE ASSIGN TO "db.conf"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS CONF-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD CONF-FILE.
       01 CONF-LINE              PIC X(300).

       WORKING-STORAGE SECTION.
       01 CONF-FILE-STATUS       PIC XX.
       01 WS-EOF                 PIC X VALUE "N".

       01 WS-KEY                 PIC X(100).
       01 WS-VALUE               PIC X(200).

       LINKAGE SECTION.
       COPY "db_config.cpy".

       PROCEDURE DIVISION USING DB-CONFIG.

       MAIN-PROCEDURE.

           PERFORM INIT-CONFIG

           OPEN INPUT CONF-FILE

           IF CONF-FILE-STATUS NOT = "00"
               MOVE "ERROR" TO DB-STATUS
               MOVE "Could not open db.conf" TO DB-MESSAGE
               GOBACK
           END-IF

           PERFORM UNTIL WS-EOF = "Y"
               READ CONF-FILE
                   AT END
                       MOVE "Y" TO WS-EOF
                   NOT AT END
                       PERFORM PROCESS-LINE
               END-READ
           END-PERFORM

           CLOSE CONF-FILE

           PERFORM VALIDATE-CONFIG

           GOBACK.

       INIT-CONFIG.

           MOVE SPACES TO DB-HOST
           MOVE SPACES TO DB-PORT
           MOVE SPACES TO DB-NAME
           MOVE SPACES TO DB-USER
           MOVE SPACES TO DB-SCHEMA
           MOVE "OK" TO DB-STATUS
           MOVE "Configuration loaded" TO DB-MESSAGE
           .

       PROCESS-LINE.

           MOVE SPACES TO WS-KEY
           MOVE SPACES TO WS-VALUE

           IF FUNCTION TRIM(CONF-LINE) = SPACES
               EXIT PARAGRAPH
           END-IF

           IF CONF-LINE(1:1) = "#"
               EXIT PARAGRAPH
           END-IF

           UNSTRING CONF-LINE
               DELIMITED BY "="
               INTO WS-KEY
                    WS-VALUE
           END-UNSTRING

           EVALUATE FUNCTION TRIM(WS-KEY)

               WHEN "DB_HOST"
                   MOVE FUNCTION TRIM(WS-VALUE) TO DB-HOST

               WHEN "DB_PORT"
                   MOVE FUNCTION TRIM(WS-VALUE) TO DB-PORT

               WHEN "DB_NAME"
                   MOVE FUNCTION TRIM(WS-VALUE) TO DB-NAME

               WHEN "DB_USER"
                   MOVE FUNCTION TRIM(WS-VALUE) TO DB-USER

               WHEN "DB_SCHEMA"
                   MOVE FUNCTION TRIM(WS-VALUE) TO DB-SCHEMA

               WHEN OTHER
                   CONTINUE

           END-EVALUATE
           .

       VALIDATE-CONFIG.

           IF FUNCTION TRIM(DB-HOST) = SPACES
               MOVE "ERROR" TO DB-STATUS
               MOVE "Missing DB_HOST in db.conf" TO DB-MESSAGE
               EXIT PARAGRAPH
           END-IF

           IF FUNCTION TRIM(DB-PORT) = SPACES
               MOVE "ERROR" TO DB-STATUS
               MOVE "Missing DB_PORT in db.conf" TO DB-MESSAGE
               EXIT PARAGRAPH
           END-IF

           IF FUNCTION TRIM(DB-NAME) = SPACES
               MOVE "ERROR" TO DB-STATUS
               MOVE "Missing DB_NAME in db.conf" TO DB-MESSAGE
               EXIT PARAGRAPH
           END-IF

           IF FUNCTION TRIM(DB-USER) = SPACES
               MOVE "ERROR" TO DB-STATUS
               MOVE "Missing DB_USER in db.conf" TO DB-MESSAGE
               EXIT PARAGRAPH
           END-IF

           IF FUNCTION TRIM(DB-SCHEMA) = SPACES
               MOVE "ERROR" TO DB-STATUS
               MOVE "Missing DB_SCHEMA in db.conf" TO DB-MESSAGE
               EXIT PARAGRAPH
           END-IF
           .
           