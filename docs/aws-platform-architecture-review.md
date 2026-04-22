# Strategic Architecture and Implementation Framework
## Secure Multi-Tier Cloud Platform on AWS — Architecture Review

---

## Table of Contents

1. [Architectural Philosophy](#architectural-philosophy)
2. [Multi-Account Governance](#multi-account-governance)
3. [Service Integration Design Patterns](#service-integration-design-patterns)
4. [Secure Connectivity — PrivateLink Infrastructure](#secure-connectivity)
5. [Internal Tier — Business Logic Core](#internal-tier)
6. [Identity and Zero Trust Authorisation](#identity-and-zero-trust)
7. [EKS Configuration](#eks-configuration)
8. [Secrets Management](#secrets-management)
9. [Observability and OpenTelemetry](#observability)
10. [Data Resilience and Caching](#data-resilience)
11. [CI/CD and Policy-as-Code](#cicd)
12. [Regional Constraints — Australia Only](#regional-constraints)
13. [Disaster Recovery](#disaster-recovery)
14. [Architecture Review Findings](#architecture-review-findings)

---

## 1. Architectural Philosophy {#architectural-philosophy}

The foundational principle of this architecture is the **Proxy-Service Pattern**, which establishes a clear functional and security boundary between ingress orchestration and core data processing. A DMZ VPC handles initial traffic termination; an Internal VPC serves as the source of truth.

This segregation is physically enforced through AWS network isolation, identity-based access controls, and private connectivity mechanisms that prevent direct routing between untrusted environments and the data layer.

The implementation follows a four-tier account strategy — Development, QA, UAT, and Production — ensuring environmental parity throughout the SDLC. Within each account, the dual-VPC strategy provides a secondary layer of defence.

### Conceptual Architecture

```
User/Client
    │
    ▼
AWS WAF
    │
    ▼
Public API Gateway (DMZ VPC)
    ├──► Next.js 16 (Node.js 20.9+)
    └──► TS Orchestration Lambda
              │
              ▼ HTTPS via PrivateLink
        Interface VPC Endpoint (DMZ)
              │
              ▼
        Internal API Gateway (Internal VPC)
              │
         ┌────┴────┐
         ▼         ▼
   VPC Link     TS Lambda
         │
         ▼
  Spring Boot 4 / Java 25 (EKS)
         │
    ┌────┴────┐
    ▼         ▼
  RDS     ElastiCache
        (Aurora PG)  (Valkey)

Async path:
  TS Lambda ──► DMZ EventBridge ──► Internal EventBridge ──► SQS ──► TS Lambda
```

---

## 2. Multi-Account Governance {#multi-account-governance}

Managed via AWS Organizations. Each environment is a discrete account for billing isolation, service quota separation, and blast-radius containment.

| Environment | Account Type  | DMZ VPC CIDR  | Internal VPC CIDR | Primary Objective                                  |
|-------------|---------------|---------------|-------------------|----------------------------------------------------|
| Development | Sandbox/Build | 10.0.0.0/16   | 10.10.0.0/16      | Rapid iteration, component testing, integration    |
| QA          | Testing/STG   | 10.1.0.0/16   | 10.11.0.0/16      | Automated regression, functional and security scan |
| UAT         | Pre-Prod      | 10.2.0.0/16   | 10.12.0.0/16      | User acceptance, performance tuning, final staging |
| Production  | Live Core     | 10.3.0.0/16   | 10.13.0.0/16      | Critical business operations and live data         |

Every component must be deployed across at least three Availability Zones with automated health checks and failover mechanisms to achieve the 99.99% availability target.

---

## 3. Service Integration Design Patterns {#service-integration-design-patterns}

All asynchronous EventBridge interactions are mediated by a Lambda function. DMZ presentation logic resides in Next.js 16 (Node.js 20.9+); internal logic uses Spring Boot 4 with Java 25 or TypeScript Lambdas.

### Pattern 1 — Public API with External Client

**Flow:** External Client → AWS WAF → Public API Gateway (DMZ)

A TS Lambda Authorizer validates the ForgeRock JWT and evaluates Cedar policies before proxying to downstream compute.

### Pattern 2 — Internal API Consumed from Public API

**Variant A (Simple Proxy):** Public API Gateway → Interface VPC Endpoint → Internal API Gateway

**Variant B (With Orchestration):** Public API Gateway → TS Orchestration Lambda → Interface VPC Endpoint → Internal API Gateway. The Lambda handles multi-call aggregation or data scrubbing.

### Pattern 3 — Internal API Implementation

- **Containerised:** Internal API Gateway → VPC Link → Spring Boot 4 (Java 25) on EKS
- **Serverless:** Internal API Gateway → TS Lambda

### Patterns 4 and 5 — API to EventBridge (Lambda-Mediated)

**Flow:** API Gateway → TS Lambda → EventBridge

A TS Lambda acts as the producer to avoid complex VTL mapping. The Lambda receives the API request, optionally enriches the payload, and calls `events:PutEvents` via the AWS SDK.

### Pattern 6 — EventBridge to EventBridge (Cross-VPC)

**Flow:** DMZ EventBridge Bus → EventBridge Rule → Internal EventBridge Bus

The Internal bus resource policy must permit `events:PutEvents` from the DMZ account.

### Pattern 7 — EventBridge to SQS to Lambda (Reliable Async)

**Flow:** EventBridge Rule → SQS Queue → TS Lambda

SQS acts as a durable buffer. The consumer Lambda polls with a configured batch size and retry policy to absorb event volume spikes.

---

## 4. Secure Connectivity — PrivateLink Infrastructure {#secure-connectivity}

VPC Peering and Transit Gateways are explicitly rejected for the DMZ-to-Internal path. AWS PrivateLink is used exclusively.

### Interface VPC Endpoints and Private DNS

The Internal API Gateway is configured as a **Private** API. An Interface VPC Endpoint for `com.amazonaws.<region>.execute-api` is created in the DMZ VPC subnets. DNS resolution is managed through Route 53 Private Hosted Zones associated with both VPCs, resolving a custom internal domain (e.g. `api.internal.platform.com`) to the private ENI IPs in the DMZ.

### Performance Specifications

| Metric       | Target                | Rationale                                      |
|--------------|-----------------------|------------------------------------------------|
| Throughput   | 10 Gbps (scale-out)   | Supports high-volume financial transactions    |
| Latency      | < 5ms P99             | Minimises overhead of cross-VPC calls          |
| Security Group | Port 443 ingress only | Restricts attack surface to encrypted traffic |
| NACLs        | Subnet-level filtering | Secondary defence layer for ENIs              |

ENIs are deployed across multiple Availability Zones to match the DMZ compute footprint. The unidirectional nature of PrivateLink means the Internal VPC has no inherent path to initiate connections back to the DMZ unless separately configured.

---

## 5. Internal Tier — Business Logic Core {#internal-tier}

### Private API Gateway and Authorisation

The Internal API Gateway accepts traffic only through the VPC Endpoint established in the DMZ. A Lambda Authorizer enforces Zero Trust at this boundary — every request must carry a valid ForgeRock identity token and a service-to-service credential. The authorizer uses Cedar policy evaluation to confirm the specific operation is permitted for that user on that resource.

> **Note:** Cedar policy enforcement is applied at the API Gateway Lambda Authorizer layer only. There is no Cedar sidecar pattern in EKS pods.

### Spring Boot Microservices on EKS

Core business logic runs in Spring Boot 4 microservices on a dedicated EKS cluster in the Internal VPC. Services are deployed into private subnets with no route to an Internet Gateway, receiving traffic through an Internal NLB integrated with the Private API Gateway via a VPC Link.

Java 25 virtual threads (Project Loom) are leveraged for high-performance concurrent processing.

### RDS Data Access

The Aurora PostgreSQL instance resides in a dedicated Data Subnet. Security Group rules permit connections on the database port only from EKS node groups and data-access Lambdas. IAM Database Authentication replaces long-lived passwords with short-lived tokens. Direct RDS access from the DMZ is prohibited.

---

## 6. Identity and Zero Trust Authorisation {#identity-and-zero-trust}

### ForgeRock — Authentication and JWT Issuance

ForgeRock is the central Identity Provider. It manages user directories, MFA, and issues OIDC JWTs with cryptographically signed claims covering identity, roles, and organisational context. API Gateway Lambda Authorizers verify token signatures using ForgeRock's JWKS endpoint.

### Cedar — Policy-as-Code

Cedar externalises authorisation logic, allowing security teams to update permissions without service redeployment. Every authorisation decision maps the request to Cedar entities: Principal, Action, and Resource.

Cedar policies are managed in a dedicated repository with CI/CD pipelines performing syntactic validation and unit testing against simulated requests before deployment.

---

## 7. EKS Configuration {#eks-configuration}

### Cluster Architecture

- **Regions:** `ap-southeast-2` (Sydney) primary, `ap-southeast-4` (Melbourne) for DR
- **Availability Zones:** ap-southeast-2a, 2b, 2c — three AZs minimum
- **API server endpoint:** Private only — no public endpoint. `kubectl` access via AWS Systems Manager Session Manager or bastion within the VPC
- **Kubernetes version:** Latest supported EKS release on the standard support track

### Node Group Strategy

#### System Node Group

Runs cluster-critical workloads only.

| Parameter       | Value                                              |
|-----------------|----------------------------------------------------|
| Instance type   | m7i.large                                          |
| Minimum nodes   | 1 per AZ (3 total)                                 |
| Taint           | `CriticalAddonsOnly=true:NoSchedule`               |
| Workloads       | CoreDNS, AWS Load Balancer Controller, ADOT DaemonSet, Karpenter |

#### Application Node Group

Runs Spring Boot services and data Lambda-equivalent workloads.

| Parameter       | Value                                              |
|-----------------|----------------------------------------------------|
| Instance type   | m7i.xlarge or m8g.xlarge (Graviton 4 — evaluate for cost/perf) |
| Minimum nodes   | 2 per AZ (6 total)                                 |
| Maximum nodes   | 10 per AZ                                          |
| Capacity type   | On-demand only                                     |
| Workloads       | Spring Boot 4 microservices, data-access services  |

> **Graviton note:** `m8g` instances are available in Sydney and deliver meaningful cost/performance improvement for Java workloads. Spring Boot on Java 21+ runs well on ARM64. Requires multi-arch container image builds in the CI/CD pipeline.

### Autoscaling

**Karpenter** is used in preference to the legacy Cluster Autoscaler.

- `NodePool` per tier with approved instance families and AZ spread requirements
- `limits` set on total CPU and memory to prevent runaway scaling costs
- `disruption` policy: `WhenUnderutilized` with `consolidateAfter: 5m`
- **HPA** on Spring Boot deployments: CPU utilisation target 65%, with custom metrics from the OTel pipeline via the external metrics adapter

### Networking

**VPC CNI** with **prefix delegation** enabled. This increases pod density from approximately 30 to approximately 110 pods per `m7i.xlarge` node. Subnet CIDR sizing must account for peak pod count before deployment — this cannot be changed without re-provisioning subnets.

**NodeLocalDNSCache** add-on enabled to reduce DNS query latency under load. Spring Boot services with connection pooling generate high DNS traffic at startup.

**Network Policies** are enforced via the native VPC CNI network policy controller (no Calico required). Default-deny ingress and egress on all application namespaces, with explicit allow rules:

| Source            | Destination          | Port  | Direction |
|-------------------|----------------------|-------|-----------|
| Spring Boot pods  | Aurora PostgreSQL     | 5432  | Egress    |
| Spring Boot pods  | ElastiCache Valkey    | 6379  | Egress    |
| NLB Security Group | Spring Boot pods    | 8080  | Ingress   |
| ADOT collector    | OTel endpoint        | 4317  | Egress    |
| All other         | All                  | Any   | Deny      |

### Load Balancer Integration

The AWS Load Balancer Controller (installed on the system node group) manages NLB lifecycle via Kubernetes Service annotations.

- NLB scheme: `internal`
- NLB target type: **IP mode** (pod IPs direct, bypassing kube-proxy iptables)
- Integration path: Internal API Gateway → VPC Link → NLB → Kubernetes Service → Spring Boot pod

IP mode target groups require prefix delegation to be enabled on the VPC CNI.

### Pod Security

**Pod Security Admission (PSA)** enforced at `restricted` profile on all application namespaces.

Required container configuration:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop: ["ALL"]
```

> **Alpine image note:** Alpine defaults to root. All Dockerfiles must include an explicit `USER 1000` (or equivalent named non-root user). Spring Boot processes must write only to designated `emptyDir` or mounted volumes — not to the root filesystem. Validate with `docker run --read-only` locally before pushing to any environment.

### Namespace Strategy

| Namespace      | Contents                              | ResourceQuota |
|----------------|---------------------------------------|---------------|
| `system`       | Karpenter, LBC, ADOT, CoreDNS         | Conservative  |
| `api-services` | Spring Boot microservices             | Per workload  |
| `data-services`| Data-access Lambdas, batch processors | Per workload  |

Apply `LimitRange` objects per namespace to enforce default CPU/memory requests and limits, preventing noisy-neighbour contention.

---

## 8. Secrets Management {#secrets-management}

Secrets management uses a dual-strategy approach.

### Boundary Definition

| Secret Type                        | Store                  |
|------------------------------------|------------------------|
| AWS-native credentials (RDS, MSK)  | AWS Secrets Manager    |
| RDS credential rotation            | AWS Secrets Manager (native rotation Lambda) |
| Application secrets (API keys, tokens, Vault-managed PKI) | HashiCorp Vault |
| Spring Boot application config     | Vault via Vault Agent sidecar or CSI Secrets Store driver |

### Vault Integration on EKS

The **Vault Agent Sidecar Injector** or **Secrets Store CSI Driver** (with the Vault provider) are the two integration options for delivering secrets to Spring Boot pods. The CSI driver is preferred for new deployments as it avoids a sidecar container per pod and delivers secrets as projected volumes with automatic rotation.

Vault must be accessible from the Internal VPC — either as a managed service endpoint reachable via PrivateLink, or self-hosted on EKS in a dedicated `vault` namespace with strict NetworkPolicy isolation.

---

## 9. Observability and OpenTelemetry {#observability}

### OpenTelemetry Integration

The platform connects to the organisation's existing OpenTelemetry implementation. The integration path uses **AWS Distro for OpenTelemetry (ADOT)**.

**EKS:** ADOT deployed as a DaemonSet on the system node group. Spring Boot services emit traces and metrics to the local ADOT collector via OTLP on `localhost:4317`. The collector exports to the existing OTel endpoint.

**Lambda:** The ADOT Lambda layer handles trace propagation automatically for TS Lambda Authorizers and service Lambdas.

**Trace continuity:** The `traceparent` header must be forwarded through all API Gateway integrations (both Public and Internal) to maintain end-to-end trace correlation from the WAF edge to the Spring Boot pod and back.

### Pipeline

```
Spring Boot (OTLP → localhost:4317)
    │
    ▼
ADOT DaemonSet (per node)
    │
    ▼
[Existing OTel endpoint / Collector gateway]
```

### Additional Observability Components

| Component          | Purpose                                               |
|--------------------|-------------------------------------------------------|
| AWS CloudTrail     | API-level audit across all accounts — mandatory for financial services compliance |
| Amazon GuardDuty   | Threat detection — enable EKS Runtime Monitoring add-on |
| AWS Security Hub   | Aggregated security posture across accounts           |
| CloudWatch Logs    | Structured JSON application logs, replicated to centralised Logging Account |
| CloudWatch Alarms  | Metric-based alerting on SLO breach thresholds        |

All application logs must emit structured JSON with a consistent schema to enable SIEM correlation. Define and enforce a log schema standard across all services before go-live.

---

## 10. Data Resilience and Caching {#data-resilience}

### ElastiCache for Valkey

Valkey (open-source Redis fork) deployed in the Internal VPC as the primary caching layer for session state and read-heavy lookup data.

- Secured with RBAC and IAM Authentication
- Accessible only to authorised EKS node groups and Lambdas via Security Group rules
- Deployed across three AZs

### Aurora PostgreSQL

- Multi-AZ deployment with automated failover
- IAM Database Authentication — no long-lived passwords
- **RDS Proxy** should be deployed in front of Aurora to manage connection pooling for Spring Boot pod scaling events. Without RDS Proxy, connection exhaustion during scaling is a known failure mode.
- Automated backups with a retention period aligned to regulatory requirements

---

## 11. CI/CD and Policy-as-Code {#cicd}

The entire platform is defined in Terraform. Pipelines include static analysis steps for security misconfiguration scanning.

Cedar policies are managed in a separate repository with pipelines that perform syntactic validation and unit testing against simulated user requests before deployment.

Container image pipelines must support multi-arch builds (amd64 and arm64) if Graviton instances are adopted for the application node group.

---

## 12. Regional Constraints — Australia Only {#regional-constraints}

All workloads must operate within Australian AWS regions.

| Region             | Code              | Role             |
|--------------------|-------------------|------------------|
| Sydney             | ap-southeast-2    | Primary (active) |
| Melbourne          | ap-southeast-4    | DR (warm standby) |

### Melbourne Service Catalogue Validation

`ap-southeast-4` has a smaller service catalogue than Sydney. Before committing Melbourne as a DR target, validate availability of every platform component:

| Service                    | Sydney | Melbourne     |
|----------------------------|--------|---------------|
| EKS                        | ✓      | ✓             |
| Aurora PostgreSQL          | ✓      | ✓             |
| ElastiCache (Valkey)       | ✓      | Verify        |
| AWS PrivateLink endpoints  | ✓      | Partial       |
| AWS Secrets Manager        | ✓      | ✓             |
| EventBridge                | ✓      | Verify        |
| Interface VPC Endpoints    | ✓      | Reduced catalogue |

---

## 13. Disaster Recovery {#disaster-recovery}

DR posture must be defined before production go-live.

### Recommended Posture

**Tier:** Warm standby (Sydney active, Melbourne passive)

- Aurora Global Database replicates from Sydney to Melbourne with sub-second RPO
- Validate cross-region replication latency between ap-southeast-2 and ap-southeast-4 against Aurora Global Database SLA
- Route 53 health check-based failover for DNS cutover
- EKS cluster pre-provisioned in Melbourne at minimum node count (scale up on failover event)
- ElastiCache in Melbourne is a cold start — session state is non-persistent across a failover event; design application sessions accordingly

### RTO/RPO Targets

Define and agree RTO/RPO targets per environment tier before finalising the DR architecture. Suggested starting position for production:

| Metric | Target      |
|--------|-------------|
| RPO    | < 1 minute  |
| RTO    | < 30 minutes |

---

## 14. Architecture Review Findings {#architecture-review-findings}

### Summary

| Domain                      | Status         | Notes                                                      |
|-----------------------------|----------------|------------------------------------------------------------|
| Network / VPC design        | Strong         | DMZ + Internal split via PrivateLink is correct            |
| Identity and authorisation  | Strong         | ForgeRock + Cedar at API Gateway layer is the right model  |
| Technology versions         | Accepted       | Java 25, Spring Boot 4, Next.js 16 treated as roadmap targets — document current fallback baselines |
| Availability and resiliency | Needs detail   | Add RDS Proxy, RTO/RPO targets, AZ failover runbooks       |
| Secrets management          | Addressed      | Secrets Manager + Vault dual-strategy confirmed            |
| Disaster recovery           | Needs detail   | Melbourne DR catalogue validation required                 |
| Observability               | Needs detail   | OTel integration confirmed; CloudTrail and GuardDuty to be added |
| EKS configuration           | Addressed      | See Section 7 for full specification                       |

### Open Actions

1. Lock current technology baselines (Java 21 LTS, Spring Boot 3.x, Next.js 14/15) as the build baseline while Java 25 / Spring Boot 4 remain pre-release.
2. Validate Melbourne (`ap-southeast-4`) service catalogue against every platform component before committing to DR architecture.
3. Define RTO/RPO targets for production — required for Aurora Global Database sizing and EKS Melbourne pre-provisioning decisions.
4. Add RDS Proxy to the Aurora connectivity design to prevent connection exhaustion during pod scaling events.
5. Define and publish a structured log schema standard for SIEM integration before go-live.
6. Confirm Vault deployment model — managed endpoint via PrivateLink or self-hosted on EKS — and complete the Secrets Store CSI Driver integration design.
7. Validate Alpine Dockerfile compliance with restricted PSA: `USER 1000`, `readOnlyRootFilesystem`, write paths limited to declared volumes.
8. Enable CloudTrail across all accounts (including non-production) and route to the centralised Logging Account.

---

*Document version: 1.1 — Incorporates architecture review findings, EKS detailed configuration, regional constraints, and updated secrets and observability posture.*
