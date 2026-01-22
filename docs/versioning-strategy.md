# Service & Component Versioning Strategy

## Core Principles

-   **Build Once, Deploy Many**: A single artifact is built and promoted through environments (DEV -> QA -> UAT -> PROD).
-   **Immutable Artifacts**: Once a version is generated, it cannot be changed.
-   **Traceability**: Every running version can be traced back to a specific commit SHA.

## Versioning Scheme

### Microservices (Lambda / EKS)

Given our **Trunk Based Development** model, we use a Commit-Based versioning strategy for backend services.

**Format**: `v{Year}.{Month}.{BuildNumber}-{ShortHash}`

-   **Year/Month**: Provides chronological context.
-   **BuildNumber**: Monotonically increasing counter from GitLab CI (e.g., `CI_PIPELINE_IID`).
-   **ShortHash**: The first 7 characters of the git commit SHA (`CI_COMMIT_SHORT_SHA`).

**Example**: `v2024.1.105-a1b2c3d`

For internal tracking or purely functional deploy tags, the `{ShortHash}` alone is the unique identifier used to tag container images or Lambda function versions.

### UX Components (React / Shadcn)

#### Monorepo Components
Components that are part of the main application monorepo share the application's version (see Microservices above).

#### Published Libraries
If a set of UI components (e.g., a Design System library) is published to an internal registry (like Artifactory or npm private), it follows **Semantic Versioning (SemVer)** to allow consumers to manage upgrades safely.

**Format**: `MAJOR.MINOR.PATCH` (e.g., `1.2.0`)

-   **MAJOR**: Breaking changes.
-   **MINOR**: New features (backwards compatible).
-   **PATCH**: Bug fixes.
