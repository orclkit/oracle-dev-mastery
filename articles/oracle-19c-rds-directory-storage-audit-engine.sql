-- +----------------------------------------------------------------------------+
-- | NAME: oracle-19c-rds-directory-storage-audit-engine.sql                    |
-- | DESCRIPTION: Unified Amazon RDS for Oracle storage utility. Performs deep  |
-- |              directory space analysis using CROSS APPLY and provides a     |
-- |              declarative JSON-driven "Dry-Run" preview of purge candidates.|
-- | COMPATIBILITY: Amazon RDS for Oracle (19c+)                                |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                         |
-- | USAGE:  Requires rdsadmin privileges.                                      |
-- | Author: @orclkit                                                           |
-- +----------------------------------------------------------------------------+


-- +----------------------------------------------------------------------------+
-- | Step 1: High-Level Directory Capacity & Storage Consumption Summary        |
-- +----------------------------------------------------------------------------+
SELECT drn.column_value                                     directory_name
       ,Count(*)                                            total_files
       /* Converts raw byte sums into an optimal human-readable string format */
       ,dbms_xplan.format_size(Sum(lsd.filesize))           total_size
       ,To_char(Min(lsd.mtime),'DD-MON-YYYY')               min_mtime
       ,To_char(Max(lsd.mtime),'DD-MON-YYYY')               max_mtime
FROM   table(sys.dbms_debug_vc2coll('FILE_LOAD')) drn
       CROSS APPLY table(rdsadmin.rds_file_util.listdir(drn.column_value)) lsd
GROUP  BY drn.column_value;


-- +----------------------------------------------------------------------------+
-- | 2: Declarative JSON-Driven Retention Engine "Dry-Run" Audit                |
-- +----------------------------------------------------------------------------+
WITH t_rules AS (
    --Centralized policy engine. 
    --Note: file_pattern evaluation is strict case-sensitive.
    --Regex escape patterns require double backslashes (\\) inside JSON blocks.
    SELECT q'[ [
        {"file_pattern":"^INV_.*\\.csv$", "days_to_keep":"30"},
        {"file_pattern":"^LOG_.*\\.txt$", "days_to_keep":"3"},
        {"file_pattern":"^\\d{8}_.*",     "days_to_keep":"7"}
    ] ]' as json_data
    FROM dual
)
SELECT jt.file_pattern,
       TO_NUMBER(jt.days_to_keep) as retention_days,
       lsd.filename,
       To_char(lsd.mtime, 'DD-MON-YYYY') as mtime
FROM t_rules tr,
     JSON_TABLE(tr.json_data, '$[*]'
         COLUMNS (
             file_pattern PATH '$.file_pattern',
             days_to_keep PATH '$.days_to_keep'
         )
     ) jt
CROSS APPLY TABLE(rdsadmin.rds_file_util.listdir('FILE_LOAD')) lsd
WHERE lsd.type = 'file'
  /* Apply target regex patterns securely across structural boundaries */
  AND REGEXP_LIKE(lsd.filename, jt.file_pattern)
  AND lsd.mtime < (SYSDATE - TO_NUMBER(jt.days_to_keep))
ORDER BY lsd.mtime ASC;
