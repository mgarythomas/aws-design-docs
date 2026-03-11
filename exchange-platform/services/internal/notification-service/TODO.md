# Notification Service TODOs

## Initial Setup & Specifications
- [x] Define what a standardized notification service will do (Specification Docs).
- [x] Update Specification Docs with AWS implementation details (DMZ vs Internal VPC, API Gateways, Lambdas, TypeScript, Vite, Playwright).
- [x] Define REST API OpenAPI specification (Contract First).
- [x] Add AWS API Gateway annotations to the OpenAPI specification.
- [x] Expand API specification to support generating, fetching, and deleting notifications registered against individual users.

## Base Project Configuration
- [x] Initialize Spring Boot (Java LTS, Gradle) for Internal VPC services.
- [ ] Set up infrastructure architecture:
  - [ ] Provision Internal VPC.
  - [ ] Provision Internal API Gateways.
  - [ ] Deploy EKS cluster in the Internal VPC.
  - [x] Create Helm chart to deploy service to EKS Pod with Hashicorp Vault secrets for RDS connection.
  - [x] Create CI/CD pipeline in GitLab with SonarQube.

## Architecture & Implementation
- [x] Implement Hexagonal Architecture (Ports and Adapters).
- [x] Support templating of notifications.
- [x] Enable support for single and multiple notifications in a single request.
- [x] Audit all notifications (track source and destination).
- [ ] Integrate with OpenTelemetry for observability.
- [x] Enable feature flagging using OpenFeature standard.
- [x] Build user notifications feature (start/end dates, metadata) with underlying storage via AWS RDS Postgres.

## Integrations & Adapters
- [x] Define outward ports to delegate to third-party services (SMTP, Email, SMS, WhatsApp, Signal, Bluesky, X).
- [x] Implement initial adapter for Salesforce Email API. (initial implementation).

## Simulator & Testing
- [x] Build a separate notification simulator to capture and record all requests to a CSV file.
- [x] Build a query implementation for the simulator logs using DuckDB.
- [x] Implement automated Playwright tests for the API.
- [x] Build unit tests and Playwright end-to-end tests for the user notifications endpoints.

## Documentation
- [x] Integrate design specification into the primary README.md.
- [x] Add sequence diagram to README.md showing flow from React Client to EKS.
