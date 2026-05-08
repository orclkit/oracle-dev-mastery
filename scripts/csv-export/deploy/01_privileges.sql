-- +-----------------------------------------------------------------------------+
-- | NAME: 01_privileges.sql                                                     |
-- | DESCRIPTION: Setup mandatory direct grants for AWS RDS CSV Export Utility   |
-- | COMPATIBILITY: Oracle 19c, 21c, 23c                                         |
-- | LICENSE: GNU General Public License v3.0 (GPL-3.0)                          |
-- | USAGE: Execute as Master/DBA user to grant RDSADMIN and Directory access    |
-- | Author: @orclkit                                                            |
-- +-----------------------------------------------------------------------------+


-- 1. Replace 'YOUR_APP_USER' with the schema that will own the package.
-- 2. Replace 'FILE_LOAD' with your Oracle Directory Object name.

DEFINE pkg_owner = 'YOUR_APP_USER';
DEFINE dir_name = 'FILE_LOAD';

-- Grant access to RDS File Utilities (Required for listing and purging files)
-- This allows the package to see what files exist on the RDS storage.
BEGIN
    rdsadmin.rdsadmin_util.grant_sys_object(
        p_obj_name  => 'RDS_FILE_UTIL',
        p_grantee   => '&&pkg_owner',
        p_privilege => 'EXECUTE'
    );
END;
/

-- Alternative Direct Grant (if the above RDS utility is not used)
-- GRANT EXECUTE ON rdsadmin.rds_file_util TO &&pkg_owner;

-- Grant Direct File System access
-- Required for UTL_FILE to read, write, and delete files in the directory.
GRANT READ, WRITE ON DIRECTORY &&dir_name TO &&pkg_owner;

-- Grant access to DBMS_SCHEDULER 
-- Required if the user needs to create the automated purge job.
GRANT CREATE JOB TO &&pkg_owner;

PROMPT Direct privileges granted to &&pkg_owner for Directory &&dir_name.
PROMPT Setup 01 complete.
