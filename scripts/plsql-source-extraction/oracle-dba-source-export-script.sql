-- Title: Oracle DBA_SOURCE Manual Export
-- Description: Manually reconstructs package source using data dictionary views.
-- Usage: High-control method for custom automation.

-- Set your variable
DEFINE pkg_owner = 'CUSTOMER'
DEFINE pkg_name  = 'TELEMETRY_PKG'

DEFINE base_path = 'C:\Temp\&pkg_name..pck'

-- Start Spooling
SPOOL "&base_path"


-- Standard "Clean File" Settings
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
SET VERIFY OFF

-- CRITICAL: Stop the script commands from being written to the file
SET ECHO OFF
SET TERMOUT OFF


SELECT text
FROM   (SELECT Decode(line, 1, 'CREATE OR REPLACE ') || text text, TYPE, line
        FROM   DBA_SOURCE src
        WHERE  src.owner = UPPER('&pkg_owner')
               AND src.name = UPPER('&pkg_name')
               AND src.TYPE = 'PACKAGE'
        UNION
        SELECT '/' text, TYPE, line + 1
        FROM   DBA_SOURCE src
        WHERE  src.owner = UPPER('&pkg_owner')
               AND src.name = UPPER('&pkg_name')
               AND src.TYPE = 'PACKAGE'
               AND Upper(text) LIKE '%END%;%'
        UNION
        SELECT Decode(line, 1, 'CREATE OR REPLACE ') || text text, TYPE, line
        FROM   DBA_SOURCE src
        WHERE  src.owner = UPPER('&pkg_owner')
               AND src.name = UPPER('&pkg_name')
               AND src.TYPE = 'PACKAGE BODY'
        UNION
        SELECT '/' text, TYPE, line + 1
        FROM   DBA_SOURCE src
        WHERE  src.owner = UPPER('&pkg_owner')
               AND src.name = UPPER('&pkg_name')
               AND src.TYPE = 'PACKAGE BODY'
               AND line = (SELECT MAX(line)
                           FROM DBA_SOURCE bdy
                           WHERE src.name = bdy.name
                                 AND src.type = bdy.type)
        ORDER BY TYPE, line
    );

SPOOL OFF
SET TERMOUT ON


PROMPT File saved as: &base_path
