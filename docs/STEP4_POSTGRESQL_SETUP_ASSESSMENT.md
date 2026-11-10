# SafarSetu — Step 4 PostgreSQL Installation and Database Recovery Assessment

## Decision

**Option B is the best-supported next path: PostgreSQL appears unavailable locally, so local PostgreSQL setup may be needed, but installation or service start is not authorized or safe to do yet.** This is not proof that PostgreSQL is absent. The Windows Service Control Manager denied enumeration, so an installation/service outside the checked locations or hidden by permissions cannot be ruled out. No evidence supports options A or C: no reachable local database, usable local PostgreSQL tools/service, or documented remote development database target was found.

**Single next action:** authorize a bounded, read-only elevated check of installed PostgreSQL programs and Windows services. If that confirms an existing instance, identify and recover that instance/database. If it confirms none, separately approve installing a local PostgreSQL version before any installation begins. Do not create a database, role, or cluster until the existing-data question is resolved.

## Verified environment findings

- Process environment inspection found no PostgreSQL/database variables matching `PG*`, `POSTGRES*`, `DATABASE_URL`, `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `SPRING_DATASOURCE*`, or `SPRING_PROFILES_ACTIVE`. Only variable names/presence were inspected; values were not printed.
- `psql`, `postgres`, `pg_ctl`, `pg_ctlcluster`, `docker`, and `podman` were not found in PATH. No processes named `postgres`, `pg_ctl`, `docker`, `podman`, or `java` were running at check time.
- The common PostgreSQL paths checked were absent: `C:\Program Files\PostgreSQL`, `C:\Program Files (x86)\PostgreSQL`, `C:\PostgreSQL`, `C:\tools\pgsql`, and `C:\ProgramData\PostgreSQL`.
- Windows PostgreSQL service enumeration failed with “Cannot open Service Control Manager ... This operation might require other privileges.” Therefore service presence and status remain unknown.
- Ports 5432 and 8080 had no listener. Prior user checks also reported loopback TCP refusal on both ports.
- No project-local `.db`, SQLite, database dump, backup, or PostgreSQL dump files were found in the inspected project tree. This says nothing about data stored in an uninspected external PostgreSQL data directory or another drive.
- Project documentation contains only local JDBC examples for `localhost:5432`; no existing remote development database is documented. There are no remote credentials/targets to use.
- `backend/.env.example` is a template; it is not proof that configured credentials or a database exist. Its values were not printed.

## Project prerequisites and runtime settings

- PostgreSQL: `backend/README.md` specifies **PostgreSQL 14 or later**. The installed PostgreSQL version is unknown.
- Java: `backend/pom.xml` targets **Java 21**. The project README also specifies Java 21.
- Maven: `backend/README.md` requires **Maven 3.6.3 or later**. The documented backend commands are `mvn spring-boot:run`, `mvn test`, and `mvn package` from `backend/`. This assessment did not run Maven or start Java.
- Database variables: `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD` are required. There are no datasource credentials or in-memory fallback defaults in `application.yml`.
- Profile: the default is `dev`. That profile uses `DDL_AUTO` defaulting to `update` and `SEED_DEMO_DATA` defaulting to `true`; the seeder is insert-only but writes synthetic data. Do not use these defaults with an uninspected database.
- Safe validation settings after the existing target/schema is identified: keep the local `dev` profile, explicitly set `DDL_AUTO=validate` and `SEED_DEMO_DATA=false`. Hibernate validation should reject missing/mismatched mappings without asking Hibernate to create/update schema; it does not prove all constraints/migrations are correct.
- `prod` forces validation and disables seed data, but also sets PostgreSQL `sslmode=verify-full` and turns CORS off unless exact origins are supplied. Use it only with the required TLS/CA and deployment configuration, not as a local shortcut.
- The backend uses Spring Data JPA/Hibernate and the PostgreSQL JDBC driver. There is no Flyway/Liquibase dependency or active migration runner. Draft migrations V1–V6 remain unexecuted; V2's arrival uniqueness does not match the entity, and V6 contains a booking-events table without a mapped runtime entity.

The expected schema includes the existing routes, stops, route-stop ordering, buses, ticket events, booking rows, and simulated arrival rows. No target schema was inspected and no local/remote database existence or data contents can be asserted. The full schema caveats and migration review are in [Step 3 database readiness](/C:/Users/PC/OneDrive/Desktop/safersetu/docs/STEP3_DATABASE_READINESS_REPORT.md).

## Safest verification sequence after the instance is identified

### 1. Identify the existing instance and target

Use the authorized administrator/DB owner to identify the service, installation/data directory, PostgreSQL version, intended development database, schema, role, and backup/recovery point. Do not infer a database name from the example `safarsetu` URL and do not create a replacement if a connection fails.

When the actual host, role, and existing database are known and `psql` is available, make a read-only connection and inspect identity/version plus schema objects. The command prompts for the role password if required; never place it in the command:

```powershell
psql -X -h <verified-host> -p <verified-port> -U <verified-role> -d <verified-existing-database> -v ON_ERROR_STOP=1 -c "SELECT current_database(), current_user, version();" -c "SELECT current_schema();" -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog','information_schema') ORDER BY table_schema, table_name;"
```

This lists schema/table names, not passenger or ticket rows. Compare the existing columns and constraints to the entity mappings and draft migration recommendations before backend startup. If read-only inspection permissions are unavailable, stop and ask the database owner; do not grant permissions or use a superuser account as a workaround.

### 2. Start the backend only after schema confirmation

After the target database and compatible schema have been identified and startup is approved, use a PowerShell terminal in `backend/`. Substitute only the verified existing database and role. The password entry is masked; no password literal is placed in shell history or output. This command sequence is prepared only and was not run:

```powershell
Set-Location 'C:\Users\PC\OneDrive\Desktop\safersetu\backend'
$env:SPRING_PROFILES_ACTIVE = 'dev'
$env:DB_URL = 'jdbc:postgresql://<verified-host>:<verified-port>/<verified-existing-database>'
$env:DB_USERNAME = '<verified-existing-role>'
$secureDbPassword = Read-Host 'Existing PostgreSQL password' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureDbPassword)
try {
  $env:DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
}
$env:DDL_AUTO = 'validate'
$env:SEED_DEMO_DATA = 'false'
mvn spring-boot:run
```

Leave the terminal open while running. If schema validation fails, stop with Ctrl+C and review the mismatch; do not switch to `update` or execute a draft migration as a quick fix. Stop this backend only in its owning terminal with Ctrl+C. Remove the temporary process variables afterward:

```powershell
Remove-Item Env:DB_PASSWORD, Env:DB_USERNAME, Env:DB_URL, Env:DDL_AUTO, Env:SEED_DEMO_DATA, Env:SPRING_PROFILES_ACTIVE -ErrorAction SilentlyContinue
Remove-Variable secureDbPassword, passwordPointer -ErrorAction SilentlyContinue
```

### 3. Verify application and database independently

In another PowerShell window, check application liveness:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/health'
```

Then verify a database-backed endpoint:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/stops?page=0&size=1'
```

`/api/health` only says the web application responds. A successful stops query (including an empty page if the identified database has no stop rows) demonstrates a successful JPA/database query. Only after that should clients be pointed at `http://localhost:8080/api`. The backend API has no authentication, so keep it on a local/private network.

## Actions requiring separate approval

- Elevated read-only inspection of installed applications and PostgreSQL Windows services.
- Starting or stopping a specifically identified PostgreSQL service.
- Installing PostgreSQL if the read-only inventory confirms none is available.
- Creating any database, role, or cluster.
- Changing ACLs/permissions or database credentials.
- Applying any draft migration, enabling Hibernate `update`, adding seed rows, or otherwise changing schema/data.

None of these actions occurred in this assessment. The recommended immediate action is the bounded elevated inventory; installation commands are intentionally not prescribed until that check establishes PostgreSQL is actually unavailable.
