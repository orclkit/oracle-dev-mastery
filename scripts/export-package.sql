-- 1. Set your variable
DEFINE pkg_owner = 'package-owner'
DEFINE pkg_name  = 'package-name'

DEFINE base_path = 'C:\Temp\&pkg_name..pck'

-- 2. Start Spooling
SPOOL "&base_path"
--"C:\Temp\&pkg_name..pck"

-- 3. Standard "Clean File" Settings
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET LINESIZE 1000
SET TRIMSPOOL ON
SET VERIFY OFF

-- 4. CRITICAL: Stop the script commands from being written to the file
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
    ) where rownum <= 10
    ;

SPOOL OFF
SET TERMOUT ON


PROMPT File saved as: &base_path
