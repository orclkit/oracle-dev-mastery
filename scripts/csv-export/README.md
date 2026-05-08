# High-Performance PL/SQL CSV Export Utility (RDS Optimized)

A production-grade Oracle PL/SQL utility designed to handle complex data exports. This project demonstrates advanced database engineering techniques to solve real-world challenges like **CLOB streaming**, **Excel data corruption**, and **Cloud (AWS RDS) file system management**.

---

## 📂 Repository Structure

```text
scripts/csv-export/
├── deploy/
│   ├── 01_privileges.sql      # Security & Grant requirements for RDS
│   └── 02_csv_export_pkg.sql  # Core Package Specification & Body
├── automation/
│   └── 03_purge_scheduler.sql # DBMS_SCHEDULER logic for auto-cleanup
├── tests/
│   ├── 04_test_setup.sql      # Stress-test data (Special chars, CLOBs, Timestamps)
│   └── 05_run_tests.sql       # Execution samples
└── docs/
    └── technical-analysis.md  # Detailed ORA- error mapping & limitations
```

---

## 🚀 Features & Robustness
What makes this utility superior to standard export scripts:

*   **Infinite Row Width:** Bypasses the 32KB `UTL_FILE` line limit by streaming column-by-column. You can export tables with 100+ columns without crashing.
*   **CLOB Streaming:** Handles Large Objects in 8KB chunks, allowing you to export massive text fields with a minimal memory footprint.
*   **Excel Data Shield:** Automatically wraps Timestamps and large Numbers in Excel formulas (`="value"`) to prevent data truncation or scientific notation.
*   **Internationalization (i18n):** Integrated **UTF-8 BOM** support. Accented characters and symbols display correctly in Excel immediately upon opening.
*   **Self-Cleaning Architecture:** Includes RDS-compatible purging logic to prevent storage outages on cloud instances.

---

## 🛠️ Deployment & Requirements

### 1. Create Oracle Directory
Before deploying the package, the physical path must be registered in the database (Run as DBA):
```sql
-- Replace path with your actual server path
CREATE OR REPLACE DIRECTORY FILE_LOAD AS '/u01/app/oracle/oradata/exports';
```

### 2. Grant Permissions (RDS Specific)
On RDS, direct grants are mandatory for the package to execute correctly:
```sql
GRANT EXECUTE ON rdsadmin.rds_file_util TO <your_user>;
GRANT READ, WRITE ON DIRECTORY FILE_LOAD TO <your_user>;
```

### 3. Execution Sample
```sql
BEGIN
    csv_export_pkg.export_to_csv(
        p_query           => 'SELECT * FROM big_data_table',
        p_dir             => 'FILE_LOAD',
        p_filename_base   => 'SALES_REPORT',
        p_delimiter       => '|'
    );
END;
```

---

## 🛠️ Troubleshooting & Best Practices


| Error Code | Issue | Potential Cause | Recommended Fix |
| :--- | :--- | :--- | :--- |
| **ORA-29283** | Invalid File Operation | OS permissions or the directory path does not exist. | Verify the physical folder exists and the `oracle` user has write access. |
| **ORA-29280** | Invalid Directory Path | The Directory Object name is misspelled or not created. | Check `ALL_DIRECTORIES` and ensure the name is passed in UPPERCASE. |
| **ORA-01031** | Insufficient Privileges | Access was granted via a Role instead of a Direct Grant. | Re-run `01_privileges.sql` to apply direct object grants. |
| **ORA-06502** | Numeric or Value Error | A single field (without newlines) exceeded the 32k buffer. | Cleanse data or ensure long text contains line breaks to flush the buffer. |
| **ORA-01821** | Date Format Not Recognized | Passing `.FF` to a standard DATE column. | The package now auto-strips `.FF` for Dates; ensure `p_date_format` is valid. |
| **ORA-29285** | File Write Error | Disk is full or the file is locked by another process. | Check RDS storage metrics or run the `purge_old_files` procedure. |

---

## 👨‍💻 Technical Challenges Solved
*   **The "Question Mark" Bug:** Solved character corruption in Thai/Legacy environments by utilizing `NCHAR` streaming.
*   **Automated Maintenance:** Created a `DBMS_SCHEDULER` bridge to handle file retention in headless Cloud environments.

---

**Focus:** Database Architecture | PL/SQL Performance | AWS RDS Optimization
