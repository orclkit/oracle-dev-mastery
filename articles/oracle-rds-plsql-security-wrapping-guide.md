---
title: "Secure Large PL/SQL Packages on Oracle RDS using Local Wrapping and DBMS_DDL"
author: "@orclkit"
date: "2026-05-05"
tags: [oracle, rds, plsql, security]
---

# Obfuscate Large PL/SQL Packages in Oracle RDS for Intellectual Property Protection

> [!NOTE]
> This article covers PL/SQL source protection for Oracle Database 19c and 23ai.
>
> **Goal:** Securely deploy PL/SQL package bodies exceeding 32KB to Amazon RDS environments while bypassing buffer limitations.

## TL;DR
* **Problem:** Oracle RDS restricts direct file system access, and standard SQL strings in `DBMS_DDL.CREATE_WRAPPED` fail for code exceeding 32,767 bytes.
* **Solution:** Use the local `wrap.exe` utility for offline obfuscation or implement `DBMS_SQL.VARCHAR2A` collections to stream code in chunks.
* **Key Command:** `wrap iname=source.bdy oname=source.plb`

---

## 📋 Table of Contents
- [Prerequisites](#-prerequisites)
- [The Challenge](#-the-challenge)
- [Step-by-Step Implementation](#-step-by-step-implementation)
- [Solution Comparison](#-solution-comparison)
- [Implementation Checklist](#-implementation-checklist)
- [Summary](#-summary)

## ✅ Prerequisites
Before starting, ensure you have:
- [ ] Oracle Client (Instant Client or Full) installed locally.
- [ ] `CREATE PROCEDURE` privileges on the target RDS instance.
- [ ] SQL*Plus, SQLcl, or SQL Developer for deployment.

## ⚠️ The Challenge
Standard PL/SQL deployment often involves passing code as a single VARCHAR2 string.
In Amazon RDS, the absence of a local file system prevents using server-side wrapping.
Passing a large package body (>32KB) as a literal string triggers `ORA-06502: PL/SQL: numeric or value error: character string buffer too small`.

**Pro-Tip:** Always use the **`q` operator** (Alternative Quote Mechanism) to wrap your code string.
This prevents compilation errors if your package body contains single quotes.

```sql
-- Avoid this for large packages
BEGIN
  -- Use q'[ ... ]' to handle internal single quotes safely
  -- This pattern fails if the string literal exceeds 32,767 bytes
  SYS.DBMS_DDL.CREATE_WRAPPED(q'[
    CREATE OR REPLACE PACKAGE BODY quick_demo AS
      PROCEDURE hello IS
      BEGIN
        DBMS_OUTPUT.PUT_LINE('It's a wrapped package!');
      END;
    END;
  ]');
END;
/
```

## 🛠️ Step-by-Step Implementation

### 1. Method 1: Local Pre-Deployment Wrapping (Recommended)
This method obfuscates the code on your workstation before it ever reaches the network.
It is the most efficient way to handle files of unlimited size.

#### A. Find and Navigate to your Wrap Utility
Use **PowerShell** to find your local Oracle client's utility:
```powershell
# Scan C: drive for the wrap executable
Get-ChildItem -Path C:\ -Filter wrap*.exe -Recurse -ErrorAction SilentlyContinue | Select-Object FullName
```

#### B. Generate the Obfuscated File
Once you have the path, change directory to the `bin` folder and run the utility:
```bash
# Navigate to your Oracle bin folder
cd C:\Oracle\Oracle_Home\bin

# Generate the obfuscated .plb (PL/SQL Binary) file
# iname: Input source file (plain text)
# oname: Output wrapped file (obfuscated)
wrap iname="C:\project\quick_demo.pkb" oname="C:\project\quick_demo.plb"
```

#### C. Deploy to RDS
Execute via SQL*Plus or SQL Developer:
```sql
-- Deploy the plain-text specification first
@quick_demo.pks
-- Deploy the wrapped body
@quick_demo.plb
```

### 2. Method 2: Chunked Array Processing (DBMS_SQL.VARCHAR2A)
If you must wrap dynamically within the database, use a collection to bypass the scalar string limit.

```sql
DECLARE
  l_source  DBMS_SQL.VARCHAR2A;
BEGIN
  -- Break code into chunks smaller than 32KB
  l_source(1) := 'CREATE OR REPLACE PACKAGE BODY data_processor AS ';
  l_source(2) := '  PROCEDURE process_huge_set IS BEGIN NULL; END; ';
  /* ... add additional chunks here ... */
  l_source(3) := 'END data_processor;';

  -- Pass the collection to the DDL utility
  SYS.DBMS_DDL.CREATE_WRAPPED(
    ddl     => l_source,
    lb      => 1,
    ub      => l_source.COUNT
  );
END;
/
```

## 🔍 Solution Comparison
Wrapping does not change the execution plan logic, but it adds a negligible overhead during the initial compilation phase.



| Metric | Direct String (Literal) | Local Wrap Utility | VARCHAR2A Collection |
| :--- | :---: | :---: | :---: |
| **Max Size** | < 32 KB | **Unlimited** | **Unlimited** |
| **Network Overhead** | High (Text) | **Low (Compressed)** | Medium (Chunks) |
| **RDS Compatibility** | Partial | **Full** | Full |
| **Complexity** | Low | **Medium** | High |
| **Best For** | One-off small fixes | **Production Deployments** | Dynamic/Automated Wrapping |
| **Dependency** | **None** | Oracle Client (wrap.exe) | PL/SQL Collection Logic |

### Verification Query
Confirm the source is successfully scrambled in the RDS data dictionary:

```sql
-- Check the first line of the source code
-- Wrapped code starts with 'PACKAGE BODY <NAME> wrapped'
SELECT text
FROM all_source
WHERE name = 'QUICK_DEMO'
AND type = 'PACKAGE BODY'
AND line = 1;
```

## 📝 Implementation Checklist
- [ ] **Version Control:** Ensure plain-text source is committed to Git; wrapped code is irreversible.
- [ ] **Spec vs Body:** Only wrap the `PACKAGE BODY`. The `PACKAGE` (specification) should remain plain text.
- [ ] **Trailing Slashes:** Verify the `.plb` file ends with a `/` on a new line to trigger execution in SQL*Plus.
- [ ] **Dependency Check:** Compile the specification before the wrapped body to avoid `ORA-00942`.

## 🏁 Summary
Wrapping large PL/SQL packages on Oracle RDS requires moving away from simple string literals.
For production pipelines, local obfuscation using the `wrap` utility is the industry standard.
For dynamic scenarios, leveraging the `DBMS_SQL.VARCHAR2A` collection type provides a robust internal workaround for the 32KB buffer limit.

## Sources
For further reading on the internal mechanics of PL/SQL wrapping, refer to the official Oracle Documentation:

*   **[PL/SQL Wrapper Utility](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/wrapping-pl-sql-source-text-pl-sql-wrapper-utility.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2)** – Detailed syntax and usage for the `wrap` command-line utility.
*   **[DBMS_DDL Package Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DDL.html#GUID-DDFE794A-5D30-48FF-80D2-771B9890CB5E)** – Documentation for the `CREATE_WRAPPED` procedure and the `VARCHAR2A` collection types.

---

*Found a bug? Open an [Issue](https://github.com) or a PR!*
