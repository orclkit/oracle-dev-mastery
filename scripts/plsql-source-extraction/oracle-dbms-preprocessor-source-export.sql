-- Title: Oracle DBMS_PREPROCESSOR Source Export
-- Description: Extracts post-processed PL/SQL code (after $IF/$THEN evaluation).
-- Usage: Best for debugging conditional compilation.


--Set your variable
DEFINE pkg_owner = 'package-owner'
DEFINE pkg_name  = 'package-name'

DEFINE base_path = 'C:\Temp\&pkg_name..pck'


--Standard "Clean File" Settings
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT TRUNCATED
SET LONG 2000000
SET PAGESIZE 0
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET TERMOUT OFF
SET VERIFY OFF

SPOOL "&base_path"

PROMPT CREATE OR REPLACE 
BEGIN
    DBMS_PREPROCESSOR.PRINT_POST_PROCESSED_SOURCE(object_type => 'PACKAGE'
                                                 ,schema_name => UPPER('&pkg_owner')
                                                 ,object_name => UPPER('&pkg_name')
                                                 );
END;
/
PROMPT /

PROMPT CREATE OR REPLACE 
BEGIN
    DBMS_PREPROCESSOR.PRINT_POST_PROCESSED_SOURCE(object_type => 'PACKAGE BODY'
                                                 ,schema_name => UPPER('&pkg_owner')
                                                 ,object_name => UPPER('&pkg_name')
                                                 );
END;
/
PROMPT /

SPOOL OFF
SET TERMOUT ON
PROMPT Export Complete: &base_path
