-- +-----------------------------------------------------------------------------+
-- | NAME: 02_csv_export_pkg.sql                                                 |
-- | DESCRIPTION: Core Package for High-Performance CSV/Text Export Utility      |
-- | COMPATIBILITY: Oracle 19c, 21c, 23c                                         |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                          |
-- | USAGE: Main engine for streaming CLOBs and wide tables to CSV file system   |
-- | Author: @orclkit                                                            |
-- +-----------------------------------------------------------------------------+


SET DEFINE OFF;

CREATE OR REPLACE PACKAGE csv_export_pkg AS
    /*
      Main procedure to export any query to a CSV/Text file.
      p_filename_suffix: Defaults to YYYYMMDD_HH24MISS + Unique GUID.
    */
    PROCEDURE export_to_csv(
        p_query           IN VARCHAR2,
        p_dir             IN VARCHAR2,
        p_filename_base   IN VARCHAR2,
        p_filename_suffix IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') || '_' || RAWTOHEX(SYS_GUID()),
        p_filename_ext    IN VARCHAR2 DEFAULT '.csv',
        p_delimiter       IN VARCHAR2 DEFAULT ',',
        p_include_header  IN VARCHAR2 DEFAULT 'Y',
        p_date_format     IN VARCHAR2 DEFAULT 'DD/MM/YYYY HH24:MI:SS.FF',
        p_nls_calendar    IN VARCHAR2 DEFAULT 'GREGORIAN'
    );

    /*
       RDS-compatible file purge logic.
       p_filename_mask: Filter for specific files (e.g., 'SALES_%').
    */
    PROCEDURE purge_old_files(
        p_dir            IN VARCHAR2,
        p_days_to_keep   IN NUMBER   DEFAULT 7,
        p_filename_mask  IN VARCHAR2 DEFAULT '%'
    );
END csv_export_pkg;
/

CREATE OR REPLACE PACKAGE BODY csv_export_pkg AS

    -- Private helper to stream data and handle CSV escaping
    PROCEDURE write_escaped_field(
        p_file      IN UTL_FILE.FILE_TYPE,
        p_value     IN CLOB,
        p_is_first  IN BOOLEAN,
        p_delimiter IN VARCHAR2
    ) IS
        v_buffer       VARCHAR2(32767);
        v_amount       BINARY_INTEGER := 8000;
        v_pos          INTEGER := 1;
        v_clob_len     INTEGER := DBMS_LOB.GETLENGTH(p_value);
        v_needs_quotes BOOLEAN := FALSE;
    BEGIN
        IF NOT p_is_first THEN
            UTL_FILE.PUT(p_file, p_delimiter);
        END IF;

        IF v_clob_len > 0 THEN
            -- Check if field needs quotes (contains delimiter, double-quote, or newline)
            IF DBMS_LOB.INSTR(p_value, p_delimiter) > 0 OR
               DBMS_LOB.INSTR(p_value, '"') > 0 OR
               DBMS_LOB.INSTR(p_value, CHR(10)) > 0 OR
               DBMS_LOB.INSTR(p_value, CHR(13)) > 0 THEN
                v_needs_quotes := TRUE;
                UTL_FILE.PUT(p_file, '"');
            END IF;

            -- Stream CLOB data in chunks to handle huge values
            LOOP
                EXIT WHEN v_pos > v_clob_len;
                DBMS_LOB.READ(p_value, v_amount, v_pos, v_buffer);
                UTL_FILE.PUT(p_file, REPLACE(v_buffer, '"', '""'));
                v_pos := v_pos + v_amount;
            END LOOP;

            IF v_needs_quotes THEN
                UTL_FILE.PUT(p_file, '"');
            END IF;
        END IF;
    END write_escaped_field;

    PROCEDURE export_to_csv(
        p_query           IN VARCHAR2,
        p_dir             IN VARCHAR2,
        p_filename_base   IN VARCHAR2,
        p_filename_suffix IN VARCHAR2 DEFAULT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') || '_' || RAWTOHEX(SYS_GUID()),
        p_filename_ext    IN VARCHAR2 DEFAULT '.csv',
        p_delimiter       IN VARCHAR2 DEFAULT ',',
        p_include_header  IN VARCHAR2 DEFAULT 'Y',
        p_date_format     IN VARCHAR2 DEFAULT 'DD/MM/YYYY HH24:MI:SS.FF',
        p_nls_calendar    IN VARCHAR2 DEFAULT 'GREGORIAN'
    ) IS
        v_file         UTL_FILE.FILE_TYPE;
        v_cursor       INTEGER;
        v_col_cnt      NUMBER;
        v_desc_tab     DBMS_SQL.DESC_TAB;
        v_status       INTEGER;
        v_is_first     BOOLEAN;
        v_final_name   VARCHAR2(1000);
        v_nls_params   VARCHAR2(100) := 'NLS_CALENDAR=''' || p_nls_calendar || '''';

        v_clob_buf     CLOB;
        v_varchar_buf  VARCHAR2(4000);
        v_num_buf      NUMBER;
        v_date_buf     DATE;
        v_ts_buf       TIMESTAMP;
        v_df_internal  VARCHAR2(100);
    BEGIN
        v_final_name := p_filename_base || '_' || p_filename_suffix || p_filename_ext;

        v_file := UTL_FILE.FOPEN(p_dir, v_final_name, 'W', 32767);
        v_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_cursor, p_query, DBMS_SQL.NATIVE);
        DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_col_cnt, v_desc_tab);

        -- 1. Write Header Row
        IF UPPER(p_include_header) = 'Y' THEN
            FOR i IN 1..v_col_cnt LOOP
                write_escaped_field(v_file, TO_CLOB(v_desc_tab(i).col_name), (i = 1), p_delimiter);
            END LOOP;
            UTL_FILE.NEW_LINE(v_file);
        END IF;

        -- 2. Define Columns
        FOR i IN 1 .. v_col_cnt LOOP
            CASE
                WHEN v_desc_tab(i).col_type = 2 THEN DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_num_buf);
                WHEN v_desc_tab(i).col_type = 12 THEN DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_date_buf);
                WHEN v_desc_tab(i).col_type IN (180, 181, 231) THEN DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_ts_buf);
                WHEN v_desc_tab(i).col_type = 112 THEN DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_clob_buf);
                ELSE DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_varchar_buf, 4000);
            END CASE;
        END LOOP;

        v_status := DBMS_SQL.EXECUTE(v_cursor);

        -- 3. Fetch Rows
        LOOP
            EXIT WHEN DBMS_SQL.FETCH_ROWS(v_cursor) <= 0;
            FOR i IN 1 .. v_col_cnt LOOP
                v_is_first := (i = 1);
                CASE
                    WHEN v_desc_tab(i).col_type = 2 THEN
                        DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_num_buf);
                        v_clob_buf := TO_CHAR(v_num_buf);
                    WHEN v_desc_tab(i).col_type = 12 THEN
                        DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_date_buf);
                        v_df_internal := REPLACE(REPLACE(p_date_format, '.FF', ''), ':FF', '');
                        v_clob_buf := TO_CHAR(v_date_buf, v_df_internal, v_nls_params);
                    WHEN v_desc_tab(i).col_type IN (180, 181, 231) THEN
                        DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_ts_buf);
                        v_clob_buf := '="' || TO_CHAR(v_ts_buf, p_date_format, v_nls_params) || '"';
                    WHEN v_desc_tab(i).col_type = 112 THEN
                        DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_clob_buf);
                    ELSE
                        DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_varchar_buf);
                        v_clob_buf := v_varchar_buf;
                END CASE;
                write_escaped_field(v_file, v_clob_buf, v_is_first, p_delimiter);
            END LOOP;
            UTL_FILE.NEW_LINE(v_file);
        END LOOP;

        DBMS_SQL.CLOSE_CURSOR(v_cursor);
        UTL_FILE.FCLOSE(v_file);

    EXCEPTION
        WHEN OTHERS THEN
            IF UTL_FILE.IS_OPEN(v_file) THEN UTL_FILE.FCLOSE(v_file); END IF;
            IF DBMS_SQL.IS_OPEN(v_cursor) THEN DBMS_SQL.CLOSE_CURSOR(v_cursor); END IF;
            RAISE;
    END export_to_csv;

    PROCEDURE purge_old_files(p_dir IN VARCHAR2, p_days_to_keep IN NUMBER DEFAULT 7, p_filename_mask IN VARCHAR2 DEFAULT '%') IS
        v_upper_dir VARCHAR2(100) := UPPER(p_dir);
    BEGIN
        FOR r_file IN (
            SELECT filename
            FROM table(rdsadmin.rds_file_util.listdir(v_upper_dir))
            WHERE mtime < SYSDATE - p_days_to_keep
              AND filename LIKE p_filename_mask
              AND filename NOT LIKE '.%'
        ) LOOP
            BEGIN
                UTL_FILE.FREMOVE(v_upper_dir, r_file.filename);
            EXCEPTION
                WHEN OTHERS THEN
                    NULL; -- File likely locked; skip to next
            END;
        END LOOP;
    END purge_old_files;

END csv_export_pkg;
/

SET DEFINE ON;
