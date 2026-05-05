-- Title: Oracle DBMS_METADATA Source Export
-- Description: Extracts clean DDL for a package body without EDITIONABLE keywords.
-- Usage: Run in SQL*Plus or SQL Developer.


--Set your variable
DEFINE pkg_owner = 'CUSTOMER'
DEFINE pkg_name  = 'TELEMETRY_PKG'

DEFINE base_path = 'C:\Temp\&pkg_name..pck'


--Standard "Clean File" Settings
SET LONG 2000000
SET PAGESIZE 0
SET LINESIZE 32767
SET FEEDBACK OFF
SET VERIFY OFF
SET TRIMSPOOL ON
SET TERMOUT OFF
SET ECHO OFF

-- Configure Metadata for clean output
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', TRUE);
END;
/

SPOOL "&base_path"

-- Using version 11.2 to strip 'EDITIONABLE' and modern clutter
SELECT DBMS_METADATA.GET_DDL(object_type => 'PACKAGE'
                            ,name        => UPPER('&pkg_name')
                            ,schema      => UPPER('&pkg_owner')
                            ,version => '11.2')
FROM   DUAL; 

SPOOL OFF
SET TERMOUT ON
PROMPT Export Complete: &base_path
