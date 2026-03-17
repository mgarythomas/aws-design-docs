# Notification Service Architecture Design

## 1. Introduction

This document outlines the architecture design for the Notification Service within the Cloud Native Digital Platform. It employs the **Hexagonal (Ports and Adapters) Architecture**. By isolating the core notification domain from delivery mechanisms, the service is perfectly positioned to swap or add new channels (e.g., SMS, Push, Slack) seamlessly without impacting business logic.

This pattern naturally complements a **Domain-Driven Design (DDD)** approach, allowing the modeling of core entities—such as schedules, templates, and distribution lists—purely around business rules rather than infrastructure concerns. The architecture addresses specific integrations, notably Salesforce Marketing Cloud (SFMC) and deployment within AWS EKS.

---

## 2. The Core Domain (Inside the Hexagon)

The core domain is the heart of the application. It is framework-agnostic and contains no Spring annotations, AWS SDKs, or SFMC dependencies.

### Domain Models (Aggregates)
*   **`Notification`**: Represents the message intent, payload, and status.
*   **`Schedule`**: Defines when a notification should trigger (e.g., cron expression, one-off timestamp).
*   **`DistributionListRef`**: A domain representation of a list (contains metadata and an external identifier).
*   **`DeliveryStat`**: Tracks crucial engagement metrics including opens, clicks, bounces, and deliveries.

### Inbound Ports (Interfaces)
These are the APIs the core exposes to the outside world, defining the operations valid on the domain domain.
*   **`NotificationUseCase`**: Methods to trigger immediate sends or schedule future sends.
*   **`ListManagementUseCase`**: Methods to create, update, or append to distribution lists.

### Outbound Ports (Interfaces)
These specify the contracts the domain requires from the infrastructure to perform its tasks.
*   **`NotificationProviderPort`**: e.g., `sendEmail(payload, templateId, recipientList)`
*   **`ListProviderPort`**: e.g., `createList(name)`, `addSubscriber(listId, subscriberData)`
*   **`ScheduleRepositoryPort`**: To persist and retrieve schedules from the database.

---

## 3. Primary (Driving) Adapters

Primary adapters sit on the "left side" of the hexagon. They drive the application by invoking the Inbound Ports.

*   **`NotificationRestController`**: Spring MVC/WebFlux controllers exposing the REST API for other microservices. It maps incoming JSON HTTP requests to domain commands and passes them to the `NotificationUseCase`.
*   **`ScheduleTriggerAdapter`**: Manages the scheduling internally. This could be a Spring `@Scheduled` component or an integration with a distributed scheduler (like Quartz or AWS EventBridge) that wakes up and calls the core domain to dispatch pending notifications.
*   **`SfmcWebhookController`**: Handles real-time stats. SFMC's Event Notification Service (ENS) pushes HTTP POST requests to the service when emails are opened, clicked, or bounced. This adapter receives these webhooks and passes them into the domain to update internal metrics.

---

## 4. Secondary (Driven) Adapters

Secondary adapters sit on the "right side" of the hexagon. They are invoked by the core domain and implement the Outbound Ports.

*   **`SfmcEmailAdapter`**: Implements the `NotificationProviderPort`. It handles SFMC REST API authentication (fetching OAuth 2.0 bearer tokens) and translates the domain's `Notification` object into an SFMC Transactional Messaging API or Triggered Send payload.
    *   *Template Handling*: The core domain simply passes a `templateId`. This adapter maps that ID to the corresponding SFMC Customer Key and injects the dynamic payload variables.
*   **`SfmcListManagementAdapter`**: Implements the `ListProviderPort`. Since SFMC handles list management via "Data Extensions", this adapter uses the SFMC API to create Data Extensions or add/remove subscribers. The core domain delegates the heavy lifting and simply stores the resulting `DataExtensionKey` for future use.
*   **`DatabaseAdapter`**: Uses Spring Data JPA or R2DBC to persist schedules, audit logs, and delivery stats to the Internal VPC database (e.g., Aurora Postgres instance).

---

## 5. AWS EKS Deployment Considerations

Deploying within EKS allows the platform to leverage AWS native features to secure external SFMC connections and route traffic safely.

*   **Secret Management**: Store the SFMC Client ID, Client Secret, and Subdomain in **AWS Secrets Manager**. Use an EKS Kubernetes External Secrets operator or the AWS Parameter and Secrets Lambda extension (if transitioning to Fargate) to inject these credentials into the Spring Boot environment securely.
*   **Egress Traffic**: As this service requires calling public SFMC APIs, ensure the EKS worker nodes (or the NAT Gateway in the VPC) have the appropriate outbound internet access. Concurrently, strict boundary controls must restrict inbound access exclusively to the Internal network or API Gateway, ensuring the "No Database in DMZ" target state is up-kept.

---

## 6. Architectural Summary

The following table summarizes the mapping of hexagon layers to their specific components within the Notification Service.

| Layer | Component | Responsibility |
| :--- | :--- | :--- |
| **Primary Adapter** | `NotificationController` | Exposes REST API to internal microservices. |
| **Primary Adapter** | `StatsWebhookController` | Receives real-time open/click events from SFMC. |
| **Core Domain** | `NotificationService` | Validates requests, manages business logic, orchestrates ports. |
| **Outbound Port** | `EmailProviderPort` | Contract for sending messages (Domain owns this interface). |
| **Secondary Adapter** | `SfmcEmailAdapter` | Implements the port; handles SFMC OAuth 2.0 bearer tokens and JSON mapping. |
| **Secondary Adapter** | `PostgresAdapter` | Persists schedules and audit logs to AWS RDS. |
