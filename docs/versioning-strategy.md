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
    
## Deployment & Routing Integration

This section defines how the **Service Version** links to the **Runtime Environment**, enabling traffic routing from the API Gateway to the correct backend artifact.

### Lambda (Serverless)

We utilize **Lambda Aliases** to decouple the immutable function version from the mutable environment pointer.

1.  **Publish**: When a deployment pipeline runs, it publishes a new **Version** of the Lambda function (e.g., `v13`).
2.  **Alias Update**: The pipeline then updates a specific **Alias** (e.g., `live`) to point to this new version.
3.  **Routing**: API Gateway routes traffic to the alias, not the specific version number.

**API Gateway Integration**:
*   The API Gateway integration URI uses a **Stage Variable**:
    `arn:aws:apigateway:region:lambda:path/functions/arn:aws:lambda:region:account:function:my-function:${stageVariables.lambdaAlias}/invocations`
*   **Deployment**: To promote a build from QA to PROD, we update the `lambdaAlias` stage variable in API Gateway, or update the `live` alias on the Lambda function itself (preferred for simplicity).

### EKS (Containers)

For Kubernetes workloads, we use **image tags** and **Service selectors**.

1.  **Image Build**: The CI process builds a Docker image tagged with the version (e.g., `my-app:v2024.1.105-a1b2c3d`).
2.  **Manifest Update**: The CD process updates the Kubernetes Deployment manifest to use this specific image tag.
3.  **Routing**:
    *   **Ingress Controller**: An AWS Load Balancer Controller manages an ALB that routes traffic to the EKS Service.
    *   **In-Cluster**: The Service object selects pods based on labels (e.g., `app=my-app`).
    *   **Zero-Downtime**: Kubernetes performs a **Rolling Update**, ensuring new pods (with the new image) are healthy before terminating old ones.

### API Gateway Routing Strategy

To support multiple concurrent versions (if required) or canary releases, we use a combination of **Path-based** and **Header-based** routing.

*   **Path-based (Major Versions)**: Used for breaking changes.
    *   `/v1/submit` -> Routes to `Service-v1`
    *   `/v2/submit` -> Routes to `Service-v2`
*   **Header-based (Canary/Testing)**: Used for verified rollouts.
    *   Default -> Routes to `stable` alias.
    *   Header `x-channel: beta` -> Routes to `beta` alias (via Stage Variables).
