# Wrapping Large PL/SQL Packages on Oracle RDS (32KB+)

**TL;DR:** To wrap packages >32KB in RDS, you cannot use simple strings. Instead, **wrap locally** using the `wrap.exe` utility or use the **`DBMS_SQL.VARCHAR2A`** collection to pass the code in chunks.

---

## 1. Quick Start: Simple Obfuscation (<32KB)
If your package is small, you can wrap it directly within a SQL worksheet. 

**Pro-Tip:** Always use the **`q` operator** (Alternative Quote Mechanism) to wrap your code string. This prevents compilation errors if your package body contains single quotes.

```sql
BEGIN
  -- Use q'[ ... ]' to handle internal single quotes safely
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

---

## 2. Solution Comparison
Choose the method that best fits your package size and deployment workflow:

| Feature | Quick Start (DBMS_DDL) | Method 1: Local Wrap Utility | Method 2: DBMS_SQL Array |
| :--- | :--- | :--- | :--- |
| **Max Size** | < 32 KB | **Unlimited** | **Unlimited** |
| **Complexity** | Low (Single Script) | Medium (Requires Local Client) | High (Manual Code Chunking) |
| **Best For** | One-off small fixes | **Production Deployments** | Dynamic/Automated Wrapping |
| **Dependency** | None | Oracle Client (wrap.exe) | PL/SQL Collection Logic |




---

## 3. Method 1: Local Wrapping (Recommended for 32KB+)
The most robust way is to obfuscate the file on your local machine before deployment.

### A. Find and Navigate to your Wrap Utility
Use **PowerShell** to find your local Oracle client's utility:
```powershell
Get-ChildItem -Path C:\ -Filter wrap*.exe -Recurse -ErrorAction SilentlyContinue | Select-Object FullName
```

### B. Generate the Obfuscated File
Once you have the path, change directory to the `bin` folder and run the utility:
```bash
# Navigate to your Oracle bin folder
cd C:\Oracle\Oracle_Home\bin
```
```bash
# Run the wrap utility
wrap iname="C:\your_project\mask_pkg.bdy" oname="C:\your_project\mask_pkg.plb"
```

### C. Deploy to RDS
Execute via SQL*Plus or SQL Developer:
```sql
SQL> @mask_pkg.pks  -- Deploy plain text spec first
SQL> @mask_pkg.plb  -- Deploy wrapped body
```

---

## 4. Method 2: Using DBMS_SQL.VARCHAR2A
Use a collection to bypass the 32KB limit for pure PL/SQL execution.

```sql
DECLARE
  l_source  DBMS_SQL.VARCHAR2A;
BEGIN
  l_source(1) := 'CREATE OR REPLACE PACKAGE BODY mask_pkg AS ';
  l_source(2) := '  PROCEDURE huge_logic IS BEGIN ... ';
  l_source(3) := 'END mask_pkg;';

  SYS.DBMS_DDL.CREATE_WRAPPED(
    ddl     => l_source,
    lb      => 1,
    ub      => l_source.COUNT
  );
END;
/
```

---

## 5. Verification: Did it work?
After deployment, run this query to confirm the code is scrambled in the database:

```sql
SELECT text 
FROM all_source 
WHERE name = 'MASK_PKG' 
AND type = 'PACKAGE BODY' 
AND line = 1;
```
**Expected Result:** The text column should begin with: `PACKAGE BODY MASK_PKG wrapped...`

## Key Takeaways
- **Backups:** Wrapped code is **irreversible**. Always version control your plain-text source code.
- **Forward Slash:** Ensure your `.plb` file ends with a `/` on a new line.
- **Security:** Only wrap the **Body**; keep the **Specification** readable for integration.

---


## Sources 
For further reading on the internal mechanics of PL/SQL wrapping, refer to the official Oracle Documentation:

*   **[PL/SQL Wrapper Utility](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/wrapping-pl-sql-source-text-pl-sql-wrapper-utility.html#GUID-4C024F24-F054-4E11-BCAD-ACA9D6B745D2)** – Detailed syntax and usage for the `wrap` command-line utility.
*   **[DBMS_DDL Package Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DDL.html#GUID-DDFE794A-5D30-48FF-80D2-771B9890CB5E)** – Documentation for the `CREATE_WRAPPED` procedure and the `VARCHAR2A` collection types.


