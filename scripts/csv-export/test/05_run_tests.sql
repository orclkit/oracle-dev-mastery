-- +-----------------------------------------------------------------------------+
-- | NAME: 05_run_tests.sql                                                      |
-- | DESCRIPTION: Execution suite for validating CSV Export package features     |
-- | COMPATIBILITY: Oracle 19c, 21c, 23c                                         |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                          |
-- | USAGE: Runs standard and customized export scenarios for QA verification    |
-- | Author: @orclkit                                                            |
-- +-----------------------------------------------------------------------------+


SET SERVEROUTPUT ON;
DEFINE dir_name = 'FILE_LOAD';

PROMPT Running Test Export 1: Standard CSV with Header...
BEGIN
    csv_export_pkg.export_to_csv(
        p_query         => 'SELECT * FROM CSV_STRESS_TEST',
        p_dir           => '&&dir_name',
        p_filename_base => 'STRESS_TEST_AUTO',
        p_delimiter     => ','
    );
END;
/

PROMPT Running Test Export 2: Pipe Delimited (.txt) without Header...
BEGIN
    csv_export_pkg.export_to_csv(
        p_query          => 'SELECT id, test_case, data_text FROM CSV_STRESS_TEST',
        p_dir            => '&&dir_name',
        p_filename_base  => 'MINIMAL_DATA',
        p_filename_ext   => '.txt',
        p_delimiter      => '|',
        p_include_header => 'N'
    );
END;
/

PROMPT Verification: List files in RDS Directory (Requires RDS privileges)
SELECT filename, mtime 
FROM table(rdsadmin.rds_file_util.listdir('&&dir_name'))
WHERE filename LIKE 'STRESS_TEST%' OR filename LIKE 'MINIMAL_DATA%'
ORDER BY mtime DESC;
