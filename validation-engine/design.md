> **Note:** This document has been deprecated and is no longer maintained. Please refer to the new [Validation Framework Design Document](../docs/validation-framework-design.md) for the latest information.

# Validation Engine Design Document

## 1. Introduction

This document outlines the design for a new validation engine for the digital submission platform. The engine will be responsible for validating all incoming submissions, ensuring they adhere to the required format and business rules.

## 2. Requirements

The validation engine must meet the following requirements:

*   **Comprehensive Validation**: The engine must be able to validate individual fields, related fields, and entire submissions.
*   **Reusable Rules**: Validation rules should be reusable across different submission types.
*   **Readable Rules**: The rules should be expressed in a human-readable format, close to natural language.
*   **Performance**: The engine must be performant and not introduce significant latency.
*   **Testability**: It must be possible to write automated tests for the validation rules.
*   **API-Driven**: The engine must be accessible via a modern API (e.g., REST, gRPC).
*   **Flexible Deployment**: The engine should be deployable on AWS as a serverless or containerized service.

## 3. Recommended Solution: Open Policy Agent (OPA)

To meet these requirements, we recommend using the **Open Policy Agent (OPA)** with its declarative language **Rego**.

### 3.1 Rationale

*   **Reusable and Composable Rules**: Rego policies are organized into packages and rules that can be imported and reused, which is ideal for validating common fields across different submission types.
*   **Open Standard and Readability**: While Rego is a formal language, it is designed to be declarative and readable, closely mirroring the business logic it represents.
*   **Performance**: OPA is designed for high performance and can compile policies into an intermediate representation for fast evaluation.
*   **Testability**: OPA has a built-in testing framework that allows you to write unit tests for your policies in Rego, ensuring your validation rules are correct.
*   **API-Driven**: OPA can be deployed as a standalone service with a RESTful API, allowing you to send a JSON payload and receive a validation decision.
*   **Deployment Flexibility**: OPA can be deployed as a standalone container, a sidecar container, or a library within another service, aligning with the AWS Lambda or containerized service deployment model.
*   **Comprehensive Validation**: Rego is well-suited for expressing complex rules that span multiple fields or the entire submission payload.

### 3.2 A Note on Readability

A key requirement is that the validation rules be expressed in a format that is as close to natural language as possible. While Rego is a formal policy language, it is designed to be declarative and far more readable than a traditional programming language, making it an excellent choice for bridging the gap between business requirements and technical implementation.

Consider the following business rule:

**"The submission is invalid if the ex-date is not after the announcement date."**

In Rego, this rule can be expressed as:

```rego
# Deny if the ex-date is not after the announcement date
deny[msg] {
    not validate_dates(input.payload.corporateActionDetails.dates)
    msg := "Ex-date must be after announcement date"
}

# Helper function for date validation
validate_dates(dates) {
    dates.exDate > dates.announcementDate
}
```

As this example illustrates, Rego provides a structured, readable, and unambiguous way to define business rules. This clarity is essential for ensuring that all stakeholders, including those in non-technical roles, can understand and verify the validation logic.

## 4. Architecture

The validation engine will be deployed as a separate microservice. When a new submission is received by the platform, the API gateway will route the request to the validation engine for validation. The validation engine will then evaluate the submission against the relevant policies and return a validation decision.

```mermaid
graph TD
    A[Client] --> B{API Gateway};
    B --> C[Submission Service];
    C --> D[Validation Engine (AWS Lambda or EKS)];
    D --> E{OPA};
    E --> F[Rego Policies];
    D --> C;
    C --> G[Database];
```

## 5. API Layer

The validation engine will expose a RESTful API using OPA's built-in server. This eliminates the need for a separate API wrapper service for the initial implementation.

### 5.1 Endpoint

The primary endpoint for validation will be:

`POST /v1/data/{package_name}/{rule_name}`

-   `{package_name}`: The name of the Rego package for the submission type (e.g., `corporate_action`).
-   `{rule_name}`: The name of the rule to evaluate (e.g., `allow`).

### 5.2 Request Format

The request body should contain a JSON object with an `input` field, which contains the submission to be validated.

```json
{
  "input": {
    "header": { ... },
    "payload": { ... }
  }
}
```

### 5.3 Response Format

The response will be a JSON object containing the result of the policy evaluation. If the submission is valid, the `result` will be `true`. If it is invalid, the `result` will be `false`, and there will be a `deny` field containing an array of validation error messages.

```json
{
  "result": false,
  "deny": [
    "Invalid ISIN format",
    "Ex-date must be after announcement date"
  ]
}
```

## 6. Implementation and Deployment

### 6.1 Policy Structure

The Rego policies will be organized by submission type. Each submission type will have its own package with a set of rules for validating the submission. A common set of utility functions will be shared across all submission types.

### 6.2 Testing

Each Rego policy file will have a corresponding test file with a set of unit tests. These tests will be run as part of the CI/CD pipeline to ensure the policies are working correctly.

### 6.3 Deployment to AWS Lambda

OPA can be run as a library within a Go program, which can then be compiled and deployed as a Lambda function.

1.  **Create a Go Wrapper**: Write a small Go application that imports the OPA library and the Rego policies. The application will expose a handler function that can be invoked by the Lambda runtime.
2.  **Compile for Lambda**: Compile the Go application into a static binary.
3.  **Package for Deployment**: Create a zip file containing the compiled binary.
4.  **Create Lambda Function**: Create a new Lambda function and upload the zip file. The Lambda function will be configured with an API Gateway trigger.

This approach provides a serverless, event-driven deployment for the validation engine.

### 6.4 Deployment to Amazon EKS

The validation engine can be deployed as a containerized service on Amazon EKS.

1.  **Build and Push Docker Image**: The Docker image will be built and pushed to Amazon Elastic Container Registry (ECR).
2.  **Create Kubernetes Deployment**: A Kubernetes deployment will be created to manage the OPA pods. The deployment will specify the Docker image, the number of replicas, and the container port (8181).
3.  **Create Kubernetes Service**: A Kubernetes service of type `LoadBalancer` or `NodePort` will be created to expose the OPA pods.
4.  **Configure Ingress**: An Ingress controller can be used to manage external access to the service and provide features like SSL termination and path-based routing.

This approach provides a scalable and resilient deployment for the validation engine, and it is well-suited for high-traffic, low-latency use cases.

## 7. Extended Use Cases: Dynamic UI Control

Beyond backend data validation, the OPA engine can be used as a general-purpose decision engine to drive the user experience in the frontend. This allows for the centralization of business logic, ensuring that the rules for UI presentation are consistent with the rules for data validation.

### 7.1 How It Works

The frontend application can query a dedicated OPA endpoint, sending the current state of a submission form as input. OPA will then return a JSON object that describes the desired state of various UI components (e.g., whether a field should be visible, hidden, or read-only).

### 7.2 Example Use Case

**Business Rule:** "The 'Dividend Reinvestment Plan' section should only be visible if the event type is 'Cash Dividend' (`DVCA`)."

A Rego policy can be created to enforce this rule:

```rego
package corporate_action.ui

# By default, all components are visible
default component_states = {
    "dividendReinvestmentPlanSection": "visible",
    "cashProceedsRateField": "visible"
}

# Define the conditions to hide a component
component_states = {
    "dividendReinvestmentPlanSection": "hidden"
} if {
    input.payload.corporateActionGeneralInformation.eventType != "DVCA"
}
```

The frontend would query an endpoint like `POST /v1/data/corporate_action/ui/component_states` and use the response to dynamically render the UI.

### 7.3 Benefits

*   **Centralized Logic:** The rules for both backend validation and frontend presentation are in one place, using the same language.
*   **Decoupling:** UI presentation rules can be updated without requiring a redeployment of the frontend application.
*   **Consistency:** Ensures that the user is only presented with fields and options that are valid for their current submission context, reducing user error.

## 8. Future Considerations

*   **Dynamic Policy Loading**: The validation engine could be enhanced to load policies dynamically from a central repository, allowing for easier management of the validation rules.
*   **gRPC Support**: To improve performance, the validation engine could be exposed via a gRPC interface in addition to the REST API.
*   **Integration with a Schema Registry**: The validation engine could be integrated with a schema registry to automatically generate basic validation rules from the submission schemas.
