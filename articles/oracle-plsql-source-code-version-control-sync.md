---
title: "Export Clean PL/SQL Source Code in Oracle 19c/23ai for Version Control"
author: "Kitti Taweepanyayot (@orclkit)"
date: "2026-05-05"
tags: [oracle, plsql, devops, dba]
---

# Extract Clean PL/SQL Source Code for Version Control

> [!NOTE]
> This article covers source extraction techniques for Oracle Database 12c through 23ai. 
>
> **Goal:** Standardize PL/SQL exports by removing system-generated noise and capturing evaluated logic for Git-based workflows.

## TL;DR
* **Problem:** Standard DDL exports often include "dirty" keywords like `EDITIONABLE` or hide logic behind conditional compilation flags.
* **Solution:** Use a three-tier approach: `DBMS_METADATA` for clean DDL, `DBMS_PREPROCESSOR` for logic verification, and `USER_SOURCE` for high-speed automation.
* **Key Command:** `SELECT DBMS_METADATA.GET_DDL('PACKAGE_BODY', 'NAME', USER, '11.2') FROM DUAL;`

---

## 📑 Table of Contents
- [Prerequisites](#prerequisites)
- [The Challenge](#the-challenge)
- [Step-by-Step Implementation](#step-by-step-implementation)
- [Performance Verification](#performance-verification)
- [Summary](#summary)

## 🛠 Prerequisites
Before starting, ensure you have:
- [ ] Oracle Database 12c, 19c, 21c, or 23ai.
- [ ] `SELECT` privileges on `DBA_SOURCE` or `USER_SOURCE`.
- [ ] Execution rights on `DBMS_METADATA` and `DBMS_PREPROCESSOR`.

## 💡 The Challenge
Default exports often contain environment-specific metadata that causes "false positive" diffs in Git.
Using standard tools without transformation parameters results in cluttered files.

```sql
-- Avoid generic exports like this
-- It includes EDITIONABLE and physical storage clauses that break between environments
SELECT DBMS_METADATA.GET_DDL('PACKAGE_BODY', 'MY_PKG') FROM DUAL;
```

## 🚀 Step-by-Step Implementation

### 1. The Clean Metadata Method
To get code ready for another environment, you must strip the `EDITIONABLE` keyword and storage attributes.
Using the `version => '11.2'` parameter is the most efficient way to force a legacy, clean output format.

[View Script: oracle-dbms-metadata-get-ddl-source-export.sql](https://github.com/orclkit/oracle-dev-mastery/blob/main/scripts/plsql-source-extraction/oracle-dbms-metadata-get-ddl-source-export.sql)

```sql
-- Set session-level transforms for clean DDL
BEGIN
   -- Adds the SQL terminator (/) to make the script runnable immediately
   DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
   -- Removes tablespace and storage info not needed for package bodies
   DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
END;
/

-- Extracting code using 11.2 compatibility to remove EDITIONABLE clutter
SELECT DBMS_METADATA.GET_DDL('PACKAGE_BODY', 'TELEMETRY_PKG', USER, '11.2') FROM DUAL;
```

### 2. The Preprocessor Method for Logic Verification
When using conditional compilation (`$IF $THEN`), the actual code running in the DB may differ from the source.
`DBMS_PREPROCESSOR` reveals the evaluated truth.

[View Script: oracle-dbms-preprocessor-source-export.sql](https://github.com/orclkit/oracle-dev-mastery/blob/main/scripts/plsql-source-extraction/oracle-dbms-preprocessor-source-export.sql)

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
   -- Prints the code exactly as it exists in the SGA after evaluation
   DBMS_PREPROCESSOR.PRINT_POST_PROCESSED_SOURCE (
      object_type => 'PACKAGE BODY',
      schema_name => USER,
      object_name => 'TELEMETRY_PKG'
   );
END;
/
```

### 3. The High-Speed Manual Spool
For bulk automation across thousands of objects, querying `USER_SOURCE` directly avoids the overhead of the Metadata API's XML parsing logic.

[View Script: oracle-dba-source-export-script.sql](https://github.com/orclkit/oracle-dev-mastery/blob/main/scripts/plsql-source-extraction/oracle-dba-source-export-script.sql)

```sql
-- Direct dictionary query for maximum throughput
SELECT text 
FROM USER_SOURCE 
WHERE name = 'TELEMETRY_PKG' 
  AND type = 'PACKAGE BODY'
ORDER BY line;
-- Ordered by line to ensure code structure integrity
```

## 📊 Comparison Summary


| Feature | `DBMS_METADATA` | `DBMS_PREPROCESSOR` | Scripted Spool (`DBA_SOURCE`) |
| :--- | :--- | :--- | :--- |
| **Best For** | Routine DDL Extraction | Debugging Logic | Automation & File Exports |
| **Output Type** | CLOB (Raw DDL) | Console Print | Text File (.pck/.sql) |
| **Accuracy** | High (Internal Tool) | High (Post-compiled) | Moderate (Script-dependent) |
| **Speed** | Fast | Fast | Slower (Querying views) |

### Recommendations:
*   **Use Option 1** for a quick look at the code or routine backups.
*   **Use Option 2** if you are confused by why a certain part of your code isn't running due to conditional flags.
*   **Use Option 3** if you are building a high-volume deployment pipeline and need to save code to a hard drive.


### Implementation Checklist
- [ ] Use `SET LONG 2000000` in SQL*Plus to prevent CLOB truncation.
- [ ] Apply `SQLTERMINATOR` to ensure files are ready for CI/CD deployment.
- [ ] Use the `11.2` version flag to maintain cross-version compatibility.

## 🏁 Summary
Standardizing your PL/SQL extraction ensures that your Git history reflects actual logic changes rather than database-generated metadata. 
Use `DBMS_METADATA` for DDL consistency and `DBMS_PREPROCESSOR` for debugging complex logic.

---
*Found a bug? Open an [Issue](https://github.com) or a PR!*
