       IDENTIFICATION DIVISION.
       PROGRAM-ID. TEST-LOADCONF.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "db_config.cpy".

       PROCEDURE DIVISION.

       MAIN-PROCEDURE.

           CALL "LOADCONF" USING DB-CONFIG

           DISPLAY "Status : " FUNCTION TRIM(DB-STATUS)
           DISPLAY "Message: " FUNCTION TRIM(DB-MESSAGE)
           DISPLAY "Host   : " FUNCTION TRIM(DB-HOST)
           DISPLAY "Port   : " FUNCTION TRIM(DB-PORT)
           DISPLAY "Name   : " FUNCTION TRIM(DB-NAME)
           DISPLAY "User   : " FUNCTION TRIM(DB-USER)
           DISPLAY "Schema : " FUNCTION TRIM(DB-SCHEMA)

           STOP RUN.
           