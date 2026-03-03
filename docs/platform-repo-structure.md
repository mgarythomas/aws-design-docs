# Recommended Platform Monorepo Structure

Based on your enterprise AWS architecture—where foundational infrastructure and CIAM are physically detached into their own repositories—your platform repositories (`exchange` and `marketplace`) should strictly focus on delivering **Domain Business Value**.

They act as **Platform Monorepos**, housing the polyglot workloads (TS Lambdas, Spring Boot Containers) and the local configurations required to plug those workloads into the foundational infrastructure (API Gateway routes, SQS queues, DB schemas).

## Architectural Principles
1. **Infrastructure Locality**: Base infrastructure (VPCs, EKS clusters) lives in the `infrastructure` repo. Platform infrastructure (API routes, specific application SQS queues, secrets) lives in the platform repo via Terraform.
2. **Polyglot Monorepo**: Separates serverless and containerized workloads structurally but allows shared domain types/libraries.
3. **Database as Code**: SQL schemas and migrations are managed as code, decoupled from the application runtime to ensure declarative, auditable state.

---

## Proposed Git Repository Structure (e.g., `exchange` repo)

```text
/exchange-platform
│
├── /docs                      # Architecture Decision Records (ADRs) and service docs
│
├── /api-contracts             # OpenAPI Specifications (Single source of truth)
│   ├── /dmz                   # External-facing endpoints (routes to DMZ API Gateway)
│   └── /internal              # Internal endpoints (routes to Internal API Gateway)
│
├── /configuration             # Dynamic configurations & Feature Flags
│   └── /appconfig             # AWS AppConfig deployment definitions (OpenFeature targets)
│
├── /database                  # SQL Schemas and Migrations (managed via Flyway)
│   ├── /migrations            # Versioned Flyway SQL scripts (V1__init.sql, V2__add_table.sql)
│   └── /seed-data             # Reference data meant for non-prod environments
│
├── /infrastructure            # Terraform state for platform-specific resources
│   ├── /api-gateway           # TF configuring API endpoints, pointing to CIAM authorizers
│   ├── /ingress               # ALB Ingress routing configurations for EKS services
│   ├── /messaging             # SQS Queues, DLQs, and EventBridge Rules
│   ├── /observability         # OpenTelemetry collectors, CloudWatch logging configs, Elastic SIEM hooks
│   ├── /storage               # S3 bucket policies/configurations required by the platform
│   └── /secrets               # Hashicorp Vault dynamic/static secret configurations
│
├── /services                  # Containerized Applications (Destined for EKS)
│   ├── /matching-engine       # Spring Boot Application
│   │   ├── build.gradle.kts   
│   │   ├── Dockerfile         # Multi-stage build for EKS container registry
│   │   ├── /helm              # Helm charts defining Kubernetes Deployment, Service, HPA, ConfigMaps
│   │   ├── /src               # Java/Kotlin code
│   │   └── /terraform         # (Optional) specific TF for the EKS IAM Roles for Service Accounts (IRSA)
│   │
│   └── /settlement-service    # Another Spring Boot / Node.js service
│       ├── /helm              # Helm charts specific to the settlement service
│       └── ...
│
├── /lambdas                   # Serverless TypeScript Functions
│   ├── /trade-reporting       # Domain boundary Lambda group
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── index.ts
│   │   └── /terraform         # Local TF to deploy the Lambda and its localized IAM roles
│   │
│   └── /notification-handler  # Async EventBridge/SQS driven Lambda
│       └── ...
│
├── /packages                  # Shared Libraries (Internal Monorepo Packages)
│   ├── /ts-types              # Shared TypeScript interfaces (e.g., generated from OpenAPI)
│   └── /java-common           # Shared Java logic (e.g., CIAM validation wrappers, error handling)
│
├── .gitlab-ci.yml             # GitLab CI/CD Pipeline Definitions
├── Makefile                   # Developer CLI wrapping complex build/deploy commands
└── package.json               # Root monorepo tooling (e.g., Turborepo, Nx, or Lerna)
```

---

## How It Integrates with the Broader Ecosystem

### 1. API Gateways & CIAM
Your foundation repository deploys the hard API Gateway instances.
Inside `/infrastructure/api-gateway/`, this repository's Terraform reads the foundational API Gateway IDs (via SSM or Remote State) and registers **API Gateway Integrations**. It maps paths defined in `/api-contracts/dmz/` to the CIAM Authorizer (deployed by the CIAM repo) and sets the backend integration URI to either an EKS Load Balancer or a Lambda ARN.

### 2. Database & Migrations
Because the RDS instance sits in the Internal VPC, the GitLab CI runner executing the Flyway migrations against `/database/migrations` will need network access. This is typically achieved by hosting a dedicated GitLab Runner within the Internal VPC or allowing the runner to connect via AWS Client VPN/PrivateLink.

### 3. Serverless vs Containers & Ingress
- **EKS Services (Helm & ALB)**: For your containerized services (`/services/*`), the GitLab CI pipeline compiles the code, performs a Docker build, and pushes the image to **Sonatype Nexus**. It then invokes **Helm** using the charts defined in `/services/<app>/helm` bringing the new image reference into EKS to execute a rolling update, managing your Pods, Horizontal Pod Autoscalers (HPA), and ConfigMaps.
  - **ALB Ingress**: Under `/infrastructure/ingress`, Terraform or manifest files register endpoints with the AWS Load Balancer Controller running in EKS. The ALB then dynamically maps routing rules to target groups, securely serving traffic into the EKS Pods.
- **Lambdas**: The pipeline for `/lambdas/*` compiles the TypeScript, zips the artifact, and executes the local `/terraform` to update the Lambda code and memory allocations.

### 4. EventBridge & SQS
Event-driven routing between systems (e.g., Exchange fires an event, Marketplace consumes it) is defined in `/infrastructure/messaging`. SQS Queues belonging to this domain are defined here. If a Lambda needs to consume an SQS queue, the event source mapping is bound via Terraform in the localized lambda `terraform/` folder.

### 5. AppConfig & Feature Flags (OpenFeature for UI)
To dynamically control the frontend UI behaviour without redeploying the UI monorepo, backend/platform repositories define their feature flag states inside `/configuration/appconfig`. 
- **AWS AppConfig** is deployed via Terraform mapping to these environments.
- The UI Monorepo incorporates the **OpenFeature SDK** alongside the AWS AppConfig provider plugin. When the React/NextJS app loads or polls, it pulls the latest flag states defined by this platform repo securely, decoupling the backend feature readiness from your frontend deployment cycle.

### 6. API Versioning & Management
Handling multiple, concurrently active API versions (e.g., `v1` vs `v2`) requires careful mapping between Edge infrastructure and internal workloads. Based on this monorepo structure, versioning is achieved via **Path-Based Versioning** managed through OpenAPI and Terraform.

1. **OpenAPI Definitions (`/api-contracts`)**
   - Version your contracts explicitly using subdirectories: `/api-contracts/dmz/v1/openapi.yaml` and `/api-contracts/dmz/v2/openapi.yaml`.
   - Each spec defines its base path (e.g., `/v1/instruments` and `/v2/instruments`).
2. **API Gateway Orchestration (`/infrastructure/api-gateway`)**
   - Your API Gateway Terraform iterates over these specifications, creating distinct resources and methods on the Gateway. 
   - You do NOT create entirely new API Gateways per version; rather, the single DMZ API Gateway handles `/v1/*` and `/v2/*` simultaneously.
3. **Backend Workload Decoupling (`/services` or `/lambdas`)**
   - **Breaking Changes**: If `v2` introduces breaking business logic or database schema changes, deploy a physically separate workload (e.g., `lambdas/trade-reporting-v2`). The `v2/openapi.yaml` points its integration URI to the `v2` Lambda. The older `v1` Lambda continues to operate untouched until traffic fully drains.
   - **Non-Breaking Changes**: If the changes are purely additive, both `/v1/` and `/v2/` API paths can optionally point to the exact same backend service (e.g., the same Spring Boot EKS cluster or Lambda), trusting the underlying code to handle the backwards compatibility.

### 7. Observability, Security, & SIEM
A unified telemetry logging strategy is deeply important for multi-VPC distributed architectures.
- **OpenTelemetry Collection**: All workloads (Spring Boot on EKS, Node TS Lambdas) are instrumented using the vendor-agnostic OpenTelemetry SDK, tracing requests from the Edge API Gateway all the way down to the internal RDS executions.
- **AWS CloudWatch**: Traces, custom application metrics, and generic stdout logs are natively forwarded to targeted CloudWatch Log Groups bound via Terraform in `/infrastructure/observability`.
- **AWS CloudTrail**: Native AWS routing captures all broad infrastructure mutations and administrative API calls across the VPCs.
- **Elastic SIEM**: To provide real-time security tracking and anomaly detection, log shippers (e.g., Filebeat / Elastic Agent running in EKS, or Lambda log forwarders) automatically stream CloudWatch and CloudTrail events into your centralized **Elastic Deployment**, feeding the SIEM engines.
