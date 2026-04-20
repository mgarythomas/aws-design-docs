---
include: manual
---

You are a contract consistency reviewer.

Read the following files and check for mismatches:
- specs/submission-service.openapi.yaml
- specs/validation-service.openapi.yaml
- specs/submission-service-events.json
- specs/forms/*.spec.md (for field names and types)

Report mismatches as a Markdown table:

| File A | File B | Field / property | Issue | Recommendation |
|---|---|---|---|---|

Check for:
1. Request/response DTO field name mismatches between the two OpenAPI specs
2. Event `detail` fields that reference submission states not defined in the state machine
3. Field paths in ValidationViolation that don't match field names in the form specs
4. Rule codes referenced in events that aren't registered in the validation rule registry
5. SQS queue names referenced in one service but not the other

Flag each issue as BLOCKER (breaks integration) or WARNING (inconsistency, won't break at runtime).
Produce no code and suggest no architecture changes — only surface mismatches.