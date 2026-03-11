# Notification Service Specification

## 1. Overview
The Notification Service is a standardized, enterprise-grade platform responsible for routing and delivering messages across multiple channels. It acts as a central hub for all outbound communications, ensuring reliability, observability, and auditability.

## 2. Technical Stack
- **Framework**: Spring Boot
- **Language**: Java 21+ (Latest LTS version, OpenJDK)
- **Build Tool**: Gradle
- **Architecture**: Hexagonal Architecture (Ports and Adapters)
- **Deployment Strategy**: 
  - **Internal VPC**: Amazon EKS (Elastic Kubernetes Service) for core business services.
- **API Distribution**: AWS API Gateway. There are two API Gateways: one in the DMZ and one in the Internal VPC. The Notification Service is only available on the internal API Gateway and VPC.

## 2.1 AWS Implementation Details
- **VPC Topology**: The architecture employs 2 VPCs: a DMZ VPC and an Internal VPC.
- **EKS Cluster**: Sits securely in the Internal VPC.
- **External Routing**: All external-facing services are exposed via the DMZ VPC, utilizing an API Gateway in the DMZ, which routes traffic internally to endpoints on the Internal VPC.
- **DMZ Implementation constraints**: Service endpoints in the DMZ VPC can only be implemented in TypeScript as AWS Lambdas.
- **DMZ Testing**: TypeScript Lambdas will be tested using Vite.

## 3. Core Capabilities
- **Multi-Channel Delivery**: Abstracted delivery for SMTP, Email, SMS, WhatsApp, Signal, Bluesky, and X.
- **Templating**: Built-in functionality for message templating to allow dynamic content generation customized per request.
- **Auditing**: Comprehensive database auditing of all processed notifications, capturing the exact source and destination endpoints for strict compliance and tracking.
- **Flexibility in Request Batching**: An intelligent API design that accommodates both single and multiple notifications in a single payload.
- **Feature Flagging**: Interwoven with OpenFeature (Open Standard) to evaluate flags that toggle notification channels, delivery strategies, or application features dynamically.
- **Observability**: Fully integrated with OpenTelemetry to emit traces, standard logs, and metrics for request performance, queue depth, and delivery monitoring.

## 4. Third-Party Integrations
Following strict ports-and-adapters routing, the service delegates physical message delivery to external third-party services via specialized adapters.
- **Initial Implementation**: An adapter specifically integrating with the **Salesforce Email API**.
- **Future Adapters**: Standardised outbound ports allowing future configuration of SMTP and interactions with SNS/Twilio (SMS), WhatsApp, Signal, Bluesky, and X networks.

## 5. System Architecture
The application strictly enforces **Hexagonal Architecture** principles, effectively isolating business logic from input triggers and external delivery mechanics:
- **Web & Network Topology**: 
  - **Internal VPC**: Contains the Internal API Gateway and the EKS cluster running the core Java Spring Boot Notification Service. All external service requests proxy strictly through the internal gateway.
  - **Routing**: Internal request hits Internal API Gateway → ALB Ingress Controller → Spring Boot services on EKS.
- **Core Domain**: Contains templating engine integrations, core audit definitions, business rules for evaluating flags, and generic notification behaviors.
- **Inbound Ports (Primary)**: REST APIs, structurally defined and constrained by an initial contract-first OpenAPI specification.
- **Outbound Ports (Secondary)**: Abstractions for Notification Channel Gateways, Auditing Repositories, and Telemetry/Feature flag providers.
- **Adapters**: Concrete implementations wrapping Salesforce Email APIs, standard console/HTTP event emitters, PostgreSQL audits, etc.

## 6. Testing Strategy
- **Notification Simulator**: A detached simulator service built to intercept, blindly capture, and record all dispatched messages and API requests. Entries are stored into a local CSV file. A built-in query interface backed by **DuckDB** enables high-performance analytical queries directly on the CSV audit logs, ensuring isolation devoid of third-party network calls.
- **Automated API Testing**: Comprehensive end-to-end REST API automated tests authored using Playwright, targeted against the standardized API definitions and executed alongside CI validation.
