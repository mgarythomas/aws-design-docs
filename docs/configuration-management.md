# Configuration Management Strategy

We use **Hashicorp Vault** to manage secrets and environment-specific configuration, ensuring strict separation of concerns and secure delivery of config to our 4 environments: **DEV**, **QA**, **UAT**, and **PROD**.

## Vault Path Structure

Configuration is organized hierarchically to allow for granular access control and logical separation.

**Pattern**: `secret/{environment}/{domain}/{service-name}`

### Examples

-   `secret/dev/submission/submission-service`
-   `secret/prod/identity/auth-lambda`

## Environment Promotion

1.  **DEV**: Values are often managed by developers or CI for rapid iteration.
2.  **QA / UAT**: Values represent stable integration states.
3.  **PROD**: Values are strictly controlled and may require elevated privileges to change.

As an artifact moves from DEV -> PROD, the code remains the same, but it fetches configuration from the corresponding Vault path based on its runtime `ENVIRONMENT` variable.

## Integration Methods

### EKS (Kubernetes)
We use the **Vault Agent Injector** (or External Secrets Operator).
-   The running pod authenticates to Vault.
-   Secrets are injected into the file system or environment variables at runtime.

### AWS Lambda
We use the **Vault Lambda Extension** (or a client library wrapper).
-   **Cold Start**: Secrets are fetched during initialization and cached.
-   **Caching**: To reduce latency and Vault load, secrets are cached for the duration of the execution context (with a TTL).

## Versioning Configuration
While Vault supports versioning (KV v2), we primarily rely on **Environment Separation**.
-   **Feature Flags**: If a specific app version needs a specific config toggle, we prefer using Feature Flags (e.g., LaunchDarkly or a specific Vault key `EnableFeatureX`) rather than binding the app version exclusively to a Vault version number.
-   This ensures operational simplicity: rolling back code doesn't strictly require rolling back Vault, as long as backward compatibility is maintained in the config structure.
