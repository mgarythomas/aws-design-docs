# Validation Framework Design Document

## 1. Executive Summary

This document outlines the design for a unified validation framework that serves both client-side and server-side validation needs for the digital submission platform. The framework is designed to be extensible, maintainable, and provide a consistent validation experience across the platform.

The core of the framework is a unified, technology-agnostic format for defining validation rules. These rules are then transformed into Zod schemas for client-side validation in the React frontend and Open Policy Agent (OPA) policies for server-side validation in the backend.

## 2. Goals

*   **Single Source of Truth**: To create a single source of truth for validation rules, reducing duplication and inconsistencies.
*   **Technology-Agnostic**: To define validation rules in a format that is not tied to a specific technology or programming language.
*   **Extensible**: To allow for the easy addition of new validation rules and submission types.
*   **Maintainable**: To make it easy to understand, modify, and maintain the validation rules.
*   **Consistent User Experience**: To provide a consistent validation experience for users, with real-time feedback on the client-side and comprehensive validation on the server-side.

## 3. Solution Architecture

The validation framework consists of the following components:

*   **Unified Rule Definition**: A set of YAML files that define the validation rules for each submission type.
*   **Rule Transformer**: A script or service that transforms the unified rule definitions into Zod schemas and OPA policies.
*   **React Frontend**: A React application that uses React Hook Form and the generated Zod schemas to perform client-side validation.
*   **Validation Service**: An AWS Lambda function or EKS service that uses OPA and the generated Rego policies to perform server-side validation.
*   **API Gateway**: An AWS API Gateway that provides a RESTful API for the validation service.

The following diagram illustrates the architecture of the validation framework:

```mermaid
graph TD
    A[React Frontend] --> B{API Gateway};
    B --> C[Validation Service (Lambda or EKS)];
    C --> D{OPA};
    D --> E[Rego Policies];
    C --> B;
    F[Unified Rule Definition] --> G{Rule Transformer};
    G --> E;
    G --> H[Zod Schemas];
    H --> A;
```

## 4. Unified Rule Definition

The validation rules will be defined in a set of YAML files. Each file will correspond to a submission type and will contain a list of fields and validation rules.

The following is an example of a unified rule definition for a corporate action submission:

```yaml
- name: corporate_action
  fields:
    - name: isin
      label: ISIN
      type: string
      required: true
      validations:
        - type: regex
          value: "^[A-Z]{2}[A-Z0-9]{9}[0-9]$"
          message: "Invalid ISIN format"
    - name: announcementDate
      label: Announcement Date
      type: date
      required: true
    - name: exDate
      label: Ex-Date
      type: date
      required: true
  validations:
    - type: comparison
      field1: exDate
      operator: ">"
      field2: announcementDate
      message: "Ex-date must be after announcement date"
```

## 5. Rule Transformer

The rule transformer will be a script or service that transforms the unified rule definitions into Zod schemas and OPA policies. The transformer will be run as part of the CI/CD pipeline, and the generated files will be stored in the appropriate packages.

### 5.1 Zod Schema Generation

The rule transformer will generate a Zod schema for each submission type. The Zod schema will be a TypeScript file that can be imported into the React frontend.

The following is an example of a generated Zod schema:

```typescript
import { z } from "zod";

export const corporateActionSchema = z.object({
  isin: z.string().regex(/^[A-Z]{2}[A-Z0-9]{9}[0-9]$/, {
    message: "Invalid ISIN format",
  }),
  announcementDate: z.date(),
  exDate: z.date(),
}).refine((data) => data.exDate > data.announcementDate, {
  message: "Ex-date must be after announcement date",
});
```

### 5.2 OPA Policy Generation

The rule transformer will generate an OPA policy for each submission type. The OPA policy will be a Rego file that can be loaded into the OPA engine.

The following is an example of a generated OPA policy:

```rego
package corporate_action

default allow = false

allow {
    # Add rules here
}

deny[msg] {
    not re_match("^[A-Z]{2}[A-Z0-9]{9}[0-9]$", input.payload.isin)
    msg := "Invalid ISIN format"
}

deny[msg] {
    input.payload.exDate <= input.payload.announcementDate
    msg := "Ex-date must be after announcement date"
}
```

## 6. Client-Side Validation

The client-side validation will be performed by the React frontend using React Hook Form and the generated Zod schemas.

The following is an example of how to use the generated Zod schema in a React component:

```typescript
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { corporateActionSchema } from "./schemas";

const CorporateActionForm = () => {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm({
    resolver: zodResolver(corporateActionSchema),
  });

  const onSubmit = (data) => {
    // Submit the form data
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register("isin")} />
      {errors.isin && <p>{errors.isin.message}</p>}

      <input {...register("announcementDate")} type="date" />
      {errors.announcementDate && <p>{errors.announcementDate.message}</p>}

      <input {...register("exDate")} type="date" />
      {errors.exDate && <p>{errors.exDate.message}</p>}

      <button type="submit">Submit</button>
    </form>
  );
};
```

## 7. Server-Side Validation

The server-side validation will be performed by a validation service that uses OPA and the generated Rego policies. The validation service will be deployed as an AWS Lambda function or an EKS service.

The validation service will expose a RESTful API that accepts a submission and returns a validation decision. The validation decision will be a JSON object that contains a list of validation errors.

The following is an example of a request to the validation service:

```
POST /validate/corporate_action
{
  "payload": {
    "isin": "US0378331005",
    "announcementDate": "2023-01-01",
    "exDate": "2023-01-02"
  }
}
```

The following is an example of a response from the validation service:

```json
{
  "isValid": true,
  "errors": []
}
```

## 8. Implementation and Deployment Strategy

The validation framework will be implemented and deployed in the following stages:

1.  **Develop the unified rule definition format**: The first stage will be to develop the unified rule definition format. This will involve defining the structure of the YAML or JSON files that will be used to define the validation rules.
2.  **Develop the rule transformer**: The second stage will be to develop the rule transformer. The rule transformer will be a script or a service that transforms the unified rule definitions into OPA policies and Zod schemas.
3.  **Develop the validation service**: The third stage will be to develop the validation service. This will involve creating the Lambda function or EKS service that will host the OPA engine.
4.  **Integrate the validation service with the React frontend**: The final stage will be to integrate the validation service with the React frontend. This will involve generating the Zod schemas and using them to perform client-side validation in the submission forms.
5.  **Deployment**: The validation service will be deployed to AWS using the serverless framework or a CI/CD pipeline for EKS. The React frontend will be deployed to AWS Amplify.
