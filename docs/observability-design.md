# End-to-End Observability Design

This document outlines the observability strategy for the AWS exchange architecture, focusing on distributed tracing, correlation ID propagation, and centralized logging using AWS CloudWatch and OpenTelemetry (OTel).

## 1. Traceability Standards

To ensure traceability across heterogenous components (API Gateway, Lambda, EKS, EventBridge, SQS), we will adhere to the following standards:

### 1.1 Correlation ID
*   **Header Name:** `x-correlation-id`
*   **Purpose:** Business-level tracking ID.
*   **Format:** UUID v4.
*   **Behavior:**
    *   **Ingress (API Gateway):** If present, accept it. If missing, generate a new UUID.
    *   **Propagation:** Must be passed downstream in all headers and message attributes.
    *   **Logging:** Must be included in the structured log context as `correlation_id`.

### 1.2 W3C Trace Context
*   **Standards:** We will strictly follow the [W3C Trace Context](https://www.w3.org/TR/trace-context/) specification.
*   **Headers:**
    *   `traceparent`: `version-traceid-parentid-traceflags`
    *   `tracestate`: Vendor-specific trace data (optional, preserved if present).
*   **Purpose:** Distributed tracing (OpenTelemetry/X-Ray compatibility).
*   **Behavior:**
    *   **Ingress:** API Gateway/ALB should initiate or propagate the standard headers.
    *   **Services:** All services must extract the context, create a child span, and inject the new context into downstream calls.

## 2. Architecture & Data Flow

```mermaid
graph TD
    subgraph "Trace Context Propagation"
        Client[Client] -->|x-correlation-id| APIGW[API Gateway]
        APIGW -->|traceparent, x-correlation-id| Lambda[Validation Lambda]
        Lambda -->|Trace Context + Msg Attr| EB[EventBridge]
        
        EB -->|Trace Context| SQS[SQS Queues]
        SQS -->|Trace Context| JavaApp[Orchestrator (EKS)]
        SQS -->|Trace Context| NodeApp[Adapters (Lambda)]
    end

    subgraph "Telemetry Collection"
        Lambda -.->|OTLP| ADOT_Sidecar[ADOT Collector (Lambda Layer)]
        JavaApp -.->|OTLP| ADOT_Daemon[ADOT Collector (DaemonSet)]
        
        ADOT_Sidecar -->|Traces| XRay[AWS X-Ray]
        ADOT_Sidecar -->|Logs| CW[CloudWatch Logs]
        
        ADOT_Daemon -->|Traces| XRay
        ADOT_Daemon -->|Logs| CW
    end
```

## 3. Component Implementation Details

### 3.1 API Gateway
*   **Action:** Enable **X-Ray Tracing** on the stage.
*   **Mapping Templates:** Ensure `x-correlation-id` is passed to the integration.
*   **Logs:** Enable Access Logging with JSON format including `$context.requestId` and `$context.extendedRequestId`.

### 3.2 Compute: Lambda (TypeScript)
Use the **AWS Distro for OpenTelemetry (ADOT) Lambda Layer** for NodeJS.

*   **Setup:**
    *   Layer: `arn:aws:lambda:<region>:901920570463:layer:aws-otel-nodejs-<ver>:1`
    *   Env Var: `AWS_LAMBDA_EXEC_WRAPPER = /opt/otel-handler`
*   **Code Instrumentation:**
    ```typescript
    import { trace, context } from '@opentelemetry/api';
    
    // In handler
    const currentSpan = trace.getSpan(context.active());
    currentSpan.setAttribute('correlation_id', event.headers['x-correlation-id']);
    
    // Logger integration (e.g. Winston/Pino)
    logger.info('Processing item', { 
        correlation_id: event.headers['x-correlation-id'],
        trace_id: currentSpan.spanContext().traceId 
    });
    ```

### 3.3 Compute: EKS (Spring Boot)
Use the **AWS Distro for OpenTelemetry (ADOT) Java Agent**.

*   **Setup:**
    *   Add the javaagent to the container startup: `-javaagent:aws-opentelemetry-agent.jar`
*   **Configuration:**
    *   Enable X-Ray ID generation compatibility: `OTEL_PROPAGATORS=xray,tracecontext,baggage`
*   **MDC (Mapped Diagnostic Context):**
    *   Configure Logback/Log4j2 to include the trace ID and span ID in the log layout using `%X{trace_id} %X{span_id}`.
    *   Add `correlation_id` to MDC from the incoming request header.

### 3.4 Asynchronous Messaging (EventBridge & SQS)
*   **Standard:** All asynchronous messages MUST adhere to the **CloudEvents Distributed Tracing Extension**.
*   **Implementation:**
    *   **Propagators:** Configure OTEL propagators to map the W3C Context directly to CloudEvents attributes.
    *   **Attributes:**
        *   `traceparent`: Carries the operation's unique ID and the causal relationship.
        *   `tracestate`: Carries system-specific tracing data.
    *   **Producer:** Inject `traceparent` and `tracestate` as top-level fields in the CloudEvents envelope (NOT inside `data`).
    *   **Consumer:** Extract context from these specific CloudEvents attributes to parent the next span.

## 4. Logging Standards (CloudWatch)

All applications must adhere to a strict **Standardized JSON Schema** aligned with the OpenTelemetry Log Data Model. This ensures consistency and enables valid cross-service querying in CloudWatch Logs Insights.

### 4.1 Log Schema Strategy

#### Mandatory Fields (Required)
These fields must be present in **every** log entry.
*   `timestamp` (String): ISO 8601 format (e.g., `2023-10-27T10:00:00.123Z`).
*   `severity_text` (String): Log level (e.g., `INFO`, `WARN`, `ERROR`).
*   `service.name` (String): The name of the service emitting the log.
*   `body` (String): The primary log message / event description.
*   `trace_id` (String): The W3C Trace ID from the active context.
*   `span_id` (String): The W3C Span ID from the active context.

#### Optional Fields (Recommended)
Include these when available to provide common context.
*   `user.id` (String): The ID of the authenticated user.
*   `http.request.method` (String): HTTP verb (e.g., `POST`).
*   `http.route` (String): The route template (e.g., `/api/v1/orders/{id}`).
*   `error.code` (String): Application or HTTP error code.
*   `error.stack` (String): Stack trace (typically for ERROR level).

#### Extensions (Flexible Attributes)
All component-specific or "free-form" data MUST be typically placed inside a nested `attributes` object. This prevents top-level schema pollution.

### 4.2 Example Standard Log
```json
{
  "timestamp": "2023-10-27T10:00:00.123Z",
  "severity_text": "INFO",
  "service.name": "validation-lambda",
  "body": "Validation successful for order processing",
  "trace_id": "5759e988bd862e3fe1be46a994272793",
  "span_id": "53995c3f42cd8ad8",
  "user.id": "user-123",
  "http.request.method": "POST",
  "attributes": {
    "order_id": "ORD-555",
    "payment.provider": "Stripe",
    "processing_time_ms": 45
  }
}
```

## 5. Data Security & Masking

To ensure compliance and protect user privacy, no PII (Personally Identifiable Information) or sensitive data shall be written to logs or traces in plain text.

### 5.1 Sensitive Data Categories
The following data types must be masked, redacted, or hashed:
*   **PII:** Social Security Numbers, Passport Numbers, Driver's License.
*   **Financial:** Credit/Debit Card Numbers (PCI-DSS), Bank Account Numbers.
*   **Contact:** Email Addresses, Phone Numbers.
*   **Authentication:** Passwords, API Keys, Tokens.

### 5.2 Masking Strategy
*   **Application-Side:** Masking MUST occur within the application before data, logs, or traces are emitted.
*   **Techniques:**
    *   **Redaction:** Replace with `[REDACTED]` (e.g., passwords).
    *   **Partial Masking:** Show last 4 digits (e.g., `****-****-****-1234` for cards).
    *   **Hashing:** One-way hash for correlation (only if needed).

### 5.3 Implementation

#### Node.js / Lambda
*   **Log Redaction:** Use a logging wrapper or middleware that recursively scans objects for sensitive keys (e.g., `code`, `password`, `email`) and sensitive values using regex patterns to catch data leaks.
*   **Library Recommendation:** Use `fast-redact` with Pino or custom serializers for Winston.

#### Java / Spring Boot
*   **Logback/Log4j2:** Configure masking converters or regex replacements in the logging configuration.
    *   *Example Pattern:* `replace(%msg){'\b\d{16}\b', '****-****-****-****'}` (basic example)
*   **Custom Annotation:** Implement a `@LogMasked` annotation and AspectJ aspect to sanitize method arguments before logging entrance/exit.

## 6. Aggregation & Visualization
*   **CloudWatch ServiceLens:** Use ServiceLens to visualize the Service Map, linking traces (X-Ray) with logs (CloudWatch Logs).
*   **CloudWatch Logs Insights:** Query logs using the correlation ID across all log groups.
    *   `fields @timestamp, @message | filter correlation_id = "..." | sort @timestamp desc`
