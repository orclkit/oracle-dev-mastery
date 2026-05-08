-- +-----------------------------------------------------------------------------+
-- | NAME: 03_purge_scheduler.sql                                                |
-- | DESCRIPTION: DBMS_SCHEDULER automation for daily CSV file retention/purging |
-- | COMPATIBILITY: Oracle 19c, 21c, 23c                                         |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                          |
-- | USAGE: Configures the "Maintenance Robot" for directory cleanup on RDS      |
-- | Author: @orclkit                                                            |
-- +-----------------------------------------------------------------------------+


-- 1. Configuration Variables
-- Replace 'FILE_LOAD' with your actual Oracle Directory name.
DEFINE dir_name = 'FILE_LOAD';
DEFINE retention_days = '7';

PROMPT Creating Daily Purge Job for &&dir_name...

BEGIN
    -- Check if job already exists and drop it to allow clean re-deployment
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_CSV_PURGE_DAILY');
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    -- Create the maintenance job
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_CSV_PURGE_DAILY',
        job_type        => 'PLSQL_BLOCK',
        -- Calls your package procedure directly
        job_action      => 'BEGIN csv_export_pkg.purge_old_files(p_dir => ''&&dir_name'', p_days_to_keep => &&retention_days); END;',
        start_date      => TRUNC(SYSTIMESTAMP) + 1 + 1/24, -- Starts at 1:00 AM tomorrow
        repeat_interval => 'FREQ=DAILY; BYHOUR=1; BYMINUTE=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Automated daily cleanup of CSV files in &&dir_name older than &&retention_days days.'
    );
END;
/

-- Verify the job creation
COLUMN job_name FORMAT A25
COLUMN next_run_date FORMAT A35
SELECT job_name, enabled, next_run_date 
FROM all_scheduler_jobs 
WHERE job_name = 'JOB_CSV_PURGE_DAILY';

PROMPT 03_purge_scheduler setup complete.
