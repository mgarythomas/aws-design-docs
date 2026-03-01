# Validation Engine (Proof-of-Concept)

This directory contains a proof-of-concept (PoC) for a validation engine for the digital submission platform, built using the Open Policy Agent (OPA).

**Note:** This is not a complete, production-ready service. It is a demonstration of the core validation logic using OPA and Rego. For the full architectural design, including the API layer and deployment strategy, please see the [Design Document](design.md).

## Overview

The purpose of this PoC is to showcase how OPA can be used to define and enforce validation rules for submissions. The current implementation includes:

-   A set of validation rules for the `CORPORATE_ACTION` submission type.
-   Unit tests for the validation rules.
-   A Dockerfile for running the OPA server with the policies loaded.

## Building and Running

### Prerequisites
- Docker

### Build the Docker Image

To build the Docker image for the validation engine, run the following command from the repository root:

```bash
docker build -t validation-engine -f validation-engine/Dockerfile .
```

### Run the Docker Container

To run the validation engine as a Docker container, use the following command:

```bash
docker run -p 8181:8181 validation-engine
```

This will start the OPA server on port 8181 with the validation policies loaded.

## Usage

You can send a submission to the validation engine by making a POST request to the `/v1/data/corporate_action/allow` endpoint.

### Example Request

```bash
curl -X POST --data-binary @- http://localhost:8181/v1/data/corporate_action/allow <<EOF
{
  "input": {
    "header": {
      "submissionType": "CORPORATE_ACTION"
    },
    "payload": {
      "underlyingSecurity": { "isin": "AU000000BHP4" },
      "corporateActionDetails": {
        "dates": {
          "announcementDate": "2024-10-15",
          "exDate": "2024-11-01"
        }
      },
      "corporateActionGeneralInformation": {
        "mandatoryVoluntaryEventType": "VOLU"
      },
      "options": [{ "defaultOption": true }]
    }
  }
}
EOF
```

### Example Response (Allowed)

A successful validation will return a simple result:

```json
{
  "result": true
}
```

### Example Response (Denied)

If the submission is invalid, the response will include a `deny` field containing an array of validation error messages.

```json
{
  "deny": [
    "Invalid ISIN format"
  ]
}
```

*Note: The `result` field may be absent in a deny response. The presence of the `deny` array indicates a failure.*


## Extending the Engine

This PoC can be extended by:

1.  **Adding more rules:** Add new `deny` blocks and helper functions to `corporate_action.rego`.
2.  **Adding new submission types:** Create a new directory (e.g., `waiver_request`) with its own `waiver_request.rego` policy file.
3.  **Implementing the full service:** Use the provided Dockerfile as a starting point for a production-ready microservice, as described in the [Design Document](design.md).
