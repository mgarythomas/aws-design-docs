# Database Automation Strategy

## Overview
To support our **Trunk Based Development** and **Zero Downtime** goals, database schema changes must be automated and strictly versioned.

## Tool Selection: Flyway vs Liquibase

### 1. Flyway (Recommended)
-   **Approach**: SQL-first. Migrations are written in plain SQL files (e.g., `V1__init.sql`).
-   **Pros**:
    -   Simplicity: Developers write exactly the SQL that runs on the DB.
    -   Performance: No overhead of translating XML/JSON to SQL.
    -   Control: Full power of Postgres-specific features.
-   **Cons**: Rollbacks must be manually scripted (or use "Undo" migrations in Pro edition).

### 2. Liquibase
-   **Approach**: Abstraction-first. Migrations are written in XML, YAML, or JSON.
-   **Pros**: Database agnostic; Auto-generated rollbacks for simple operations.
-   **Cons**: Verbose syntax; abstraction layer can hide performance issues.

### Recommendation
We recommend **Flyway** for the Digital Platform.
-   **Reasoning**: We use **Aurora Postgres** exclusively. The need for DB agnosticism is low. Our team is proficient in SQL. Flyway's "Forward Only" philosophy aligns with our immutable delivery pipeline.

## Implementation Details

### Directory Structure
```text
/backend-service
  /src
  /db/migration
    V1__Initial_Schema.sql
    V2__Add_User_Table.sql
```

### Versioning
-   **Prefix**: `V`
-   **Version**: `{Timestamp}` (e.g., `202401151200`) or strictly sequential integers.
-   **Separator**: `__`
-   **Description**: Snake_Case description.
-   **Example**: `V2024.01.15.1200__Create_Submission_Table.sql`

### GitLab Pipeline Integration

The database migration runs as a distinct stage in the pipeline **before** the application deployment.

```yaml
db-migrate:
  stage: deploy-infra
  image: flyway/flyway:latest
  script:
    - flyway -url=jdbc:postgresql://$DB_HOST:5432/$DB_NAME -user=$DB_USER -password=$DB_PASSWORD migrate
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_TAG
```

### Zero Downtime Strategy
To ensure 24/7 availability during deployments, we use the **Expand and Contract** pattern:

1.  **Expand**: Add new columns/tables (nullable). Code is deployed that can use old OR new schema.
2.  **Migrate**: Update data.
3.  **Contract**: Remove old columns/tables (only after all code is on the new version).

**Rule**: Never rename or drop a column in a single release.
