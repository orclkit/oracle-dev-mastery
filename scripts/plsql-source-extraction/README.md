# Oracle PL/SQL Source Code Extraction Methods

This directory contains professional-grade scripts to extract source code (Package Bodies, Procedures, Functions) from an Oracle Database. Each method serves a specific use case, from routine backups to deep-dive debugging.

## 🚀 Scripts Overview


| File Name | Method | Primary Use Case |
| :--- | :--- | :--- |
| `oracle-dbms-metadata-get-ddl-source-export.sql` | **Metadata API** | Clean, production-ready DDL extraction. |
| `oracle-dbms-preprocessor-source-export.sql` | **Preprocessor** | Debugging conditional compilation ($IF/$THEN). |
| `oracle-dba-source-export-script.sql` | **Data Dictionary** | Manual, high-control scripting and automation. |

---

## 📊 Comparison: Which one should you use?

### 1. DBMS_METADATA (The Standard)
*   **Best For:** Creating exact replicas of database objects.
*   **Pros:** Handles complex dependencies; provides clean "CREATE OR REPLACE" syntax.
*   **Cons:** Can be slow on very large schemas; requires specific session transforms for clean output.
*   **SEO Keywords:** Oracle DDL Export, GET_DDL Script, Database Migration.

### 2. DBMS_PREPROCESSOR (The Debugger)
*   **Best For:** Seeing the "Final Truth" of your code after compiler flags are evaluated.
*   **Pros:** Essential for troubleshooting environment-specific logic.
*   **Cons:** Strips some original formatting and comments.
*   **SEO Keywords:** Post-processed PL/SQL, Oracle Conditional Compilation, Debugging PL/SQL.

### 3. DBA_SOURCE (The Manual Way)
*   **Best For:** Bulk exports and custom version control integration.
*   **Pros:** High speed; works even when Metadata API permissions are restricted.
*   **Cons:** Requires manual handling of the "/" terminator and headers.
*   **SEO Keywords:** Query USER_SOURCE, Oracle Code Backup Script, SQL*Plus Spooling.

---

## 🛠 How to Use
1. Open the desired script.
2. Update the `pkg_owner` and `pkg_name` variable to your target object name.
3. Update the `base_path` variable path to your local directory (e.g., `C:\Temp\`).
4. Execute the script in **SQL*Plus**, **SQL Developer**, or **Oracle SQLCL**.

---
*Part of the [Oracle Dev Mastery](https://github.com) collection.*
