-- +-----------------------------------------------------------------------------+
-- | NAME: 04_test_setup.sql                                                     |
-- | DESCRIPTION: Stress-test data generation for CSV Export Utility validation  |
-- | COMPATIBILITY: Oracle 19c, 21c, 23c                                         |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                          |
-- | USAGE: Populates CLOBs, Special Chars, and Timestamps for unit testing      |
-- | Author: @orclkit                                                            |
-- +-----------------------------------------------------------------------------+

PROMPT Setting up stress-test table: CSV_STRESS_TEST...

BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE CSV_STRESS_TEST';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE CSV_STRESS_TEST (
    id             NUMBER PRIMARY KEY,
    test_case      VARCHAR2(50),
    data_text      VARCHAR2(200),
    data_clob      CLOB,
    event_date     DATE,
    event_ts       TIMESTAMP(6)
);

-- Case 1: Standard Data
INSERT INTO CSV_STRESS_TEST VALUES (
    1, 'Standard', 'Simple Text', TO_CLOB('Simple CLOB content'), 
    SYSDATE, SYSTIMESTAMP
);

-- Case 2: Delimiter Collision & Quotes
INSERT INTO CSV_STRESS_TEST VALUES (
    2, 'Escaping', 'Text with, comma and "quotes"', TO_CLOB('CLOB with "quotes"'), 
    SYSDATE, SYSTIMESTAMP
);

-- Case 3: Newlines & Tabs (Row integrity test)
INSERT INTO CSV_STRESS_TEST VALUES (
    3, 'White Space', 'Line 1' || CHR(10) || 'Line 2' || CHR(9) || 'Tabbed', 
    TO_CLOB('Multi-line' || CHR(10) || 'CLOB content'), 
    SYSDATE, SYSTIMESTAMP
);

-- Case 4: Huge CLOB (Streaming test - 40KB)
INSERT INTO CSV_STRESS_TEST (id, test_case, data_clob)
VALUES (4, 'Large Data', RPAD('Large_Chunk_', 40000, 'X'));

-- Case 5: International/Special Characters
INSERT INTO CSV_STRESS_TEST (id, test_case, data_text)
VALUES (5, 'Special Chars', 'Symbols: & # @ | ! Accented: é, à, ü, ñ, ç');

COMMIT;
PROMPT Test data setup complete.
