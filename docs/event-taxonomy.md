# Exchange Platform Event Taxonomy

## 1. Overview

This document defines the event taxonomy for the Digital Platform. To ensure interoperability and standardisation, all events emitted by the platform conform to the **CNCF CloudEvents v1.0** specification.

The payload of business events must align with the **ISO 20022** data model defined in `docs/data-model.md`.

## 2. CloudEvents Envelope

All messages published to the Event Bus (EventBridge) must adhere to the following envelope structure:

| Field | Description | Example Value |
| :--- | :--- | :--- |
| `specversion` | CloudEvents version. | `1.0` |
| `type` | Hierarchical event identifier. | `exchange.submission.received` |
| `source` | URI of the event producer. | `/domain/submission` |
| `id` | Unique UUID for the event. | `5334c44f-1234-5678-b233-1a2b3c4d5e6f` |
| `time` | Timestamp of event creation (UTC). | `2024-10-15T10:00:00Z` |
| `datacontenttype` | Content type of the data. | `application/json` |
| `subject` | (Optional) The specific resource ID. | `CA_2024_DIV_001` |
| `data` | The business payload. | `{ ... }` |

## 3. Event Hierarchy & Registry

Events are named using the dot-notation convention: `exchange.<domain>.<entity>.<action>`.

### 3.1 Submission Domain (`/domain/submission`)
Events related to the technical ingestion validation lifecycle.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.submission.received` | A new submission has been successfully ingested. | `submissionId`, `submitterId` |
| `exchange.submission.validated` | Submission passed all business rules. | `submissionId`, `validationResult` |
| `exchange.submission.rejected` | Submission failed validation. | `submissionId`, `errorDetails` |
| `exchange.submission.committed` | Data durably stored in System of Record. | `submissionId`, `dbRef` |

### 3.2 Corporate Action Domain (`/domain/corporate-action`)
Events triggering downstream processing of market data.
*Note: Granular legacy events (DividendDeclared, StockSplitApproved) are mapped to `announced` with specific ISO 20022 Event Types (DVCA, SPLF).*

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.corp_action.announced` | New announcement (ISO 20022 seev.031). Covers Dividends, Splits, Mergers. | `offclCorpActnEvtId`, `evtTp` |
| `exchange.corp_action.updated` | Update to existing announcement. | `offclCorpActnEvtId`, `updateDetails` |
| `exchange.corp_action.cancelled` | Cancellation of an announcement. | `offclCorpActnEvtId`, `reason` |
| `exchange.corp_action.distribution_executed` | Cash or securities delivered to shareholders. | `offclCorpActnEvtId`, `payoutDetails` |

### 3.3 Submission Lifecycle Domain (`/domain/submission`)
Business lifecycle of a submission document.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.submission.material_event_identified` | Issuer identifies MNPI (Price Sensitive Info). | `issuerId`, `description` |
| `exchange.submission.draft_created` | Initial draft of submission started. | `submissionId` |
| `exchange.submission.review_requested` | Draft sent for internal review. | `submissionId`, `reviewers` |
| `exchange.submission.approved` | Final executive or legal sign-off received. | `submissionId`, `approver` |
| `exchange.submission.trading_halt_requested` | Issuer requests halt pending announcement. | `issuerId`, `reason` |
| `exchange.submission.trading_halt_confirmed` | Exchange operations confirms halt. | `haltId`, `status` |
| `exchange.submission.market_sensitive_released` | Public release of price-sensitive info. | `submissionId`, `releaseTime` |
| `exchange.submission.embargo_lifted` | Embargo period has ended, info is public. | `submissionId` |

### 3.4 Regulatory Reporting Domain (`/domain/reporting`)
Periodic financial reporting and structured data.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.reporting.period_closed` | Financial period end reached. | `issuerId`, `periodEndDate` |
| `exchange.reporting.audit_completed` | External audit opinion received. | `reportId`, `auditor` |
| `exchange.reporting.xbrl_tagging_completed` | Data tagging finished and validated. | `reportId`, `taxonomyVersion` |
| `exchange.reporting.filed` | Report formally submitted to regulator. | `reportId`, `filingRef` |
| `exchange.reporting.published` | Report made available to the market. | `reportId`, `publicUrl` |

### 3.5 Investor Registry Domain (`/domain/registry`)
Shareholder ownership and major holder tracking.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.registry.shareholder_registered` | New holder added to register. | `holderId`, `units` |
| `exchange.registry.threshold_crossed` | Substantial holding limit (e.g., 5%) breached. | `holderId`, `percentage` |
| `exchange.registry.substantial_notice_filed` | Generic substantial holder notice submitted. | `holderId`, `filingId` |
| `exchange.registry.insider_trade_executed` | Director/Executive trade completed. | `personId`, `tradeDetails` |
| `exchange.registry.insider_trade_reported` | Regulator notified of insider trade. | `filingId` |

### 3.6 Market Distribution Domain (`/domain/distribution`)
Dissemination to news wires, websites, and vendors.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.distribution.job_created` | Delivery task initiated for a release. | `jobId`, `channels` |
| `exchange.distribution.transmitted` | Message sent to a specific channel (e.g., Bloomberg). | `jobId`, `channel` |
| `exchange.distribution.delivered` | Successful receipt confirmed by channel. | `jobId`, `channel`, `ackId` |
| `exchange.distribution.failed` | Delivery failed, retry scheduled. | `jobId`, `error`, `retryCount` |
| `exchange.distribution.completed` | All targeted channels successfully reached. | `jobId`, `finishTime` |

### 3.7 Compliance Domain (`/domain/compliance`)
Rule enforcement and audit.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.compliance.violation_detected` | Rule breach identifying during validation. | `ruleId`, `entityId` |
| `exchange.compliance.exception_granted` | Waiver applied to a specific requirement. | `waiverId`, `requirement` |
| `exchange.compliance.audit_recorded` | Immutable evidence logged. | `auditId`, `action` |
| `exchange.compliance.regulatory_inquiry` | Formal query received from regulator. | `inquiryId` |

### 3.8 Identity Domain (`/domain/identity`)
Security and auditing events.

| Event Type | Description | Key Payload Fields |
| :--- | :--- | :--- |
| `exchange.identity.login_success` | User successfully authenticated. | `userId`, `method` |
| `exchange.identity.mfa_challenged` | User prompted for MFA. | `userId`, `challengeId` |
| `exchange.identity.role_changed` | User entitlements updated. | `userId`, `previousRole`, `newRole` |

## 4. CloudEvent Example

The following is an example of a **Corporate Action Announcement** event. The `data` field contains the ISO 20022 structure.

```json
{
  "specversion": "1.0",
  "type": "exchange.corp_action.announced",
  "source": "/domain/corporate-action",
  "id": "e8d9c0a1-b2c3-4d5e-6f7g-8h9i0j1k2l3m",
  "time": "2024-10-15T12:00:00Z",
  "datacontenttype": "application/json",
  "subject": "CA_2024_DIV_001",
  "data": {
    "submissionId": "a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890",
    "corporateActionGeneralInformation": {
      "officialCorporateActionEventID": "CA_2024_DIV_001",
      "eventType": "DVCA",
      "mandatoryVoluntaryEventType": "MAND"
    },
    "underlyingSecurity": {
      "isin": "AU000000BHP4",
      "ticker": "BHP"
    },
    "corporateActionDetails": {
      "dates": {
        "announcementDate": "2024-10-15",
        "exDate": "2024-11-01",
        "recordDate": "2024-11-02",
        "paymentDate": "2024-11-15"
      },
      "rateAndPrice": {
        "grossDividendRate": {
           "amount": 0.75,
           "currency": "AUD"
        }
      }
    }
  }
}
```