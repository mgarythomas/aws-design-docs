# B2B API Key Strategy — Architectural Review

## Overview

This document summarises the evaluation of three API authentication strategies for a B2B solution, architectural recommendations, a fourth option for naive clients, and a design for customer-managed keys, scopes, and rotation.

---

## Strategy Comparison

| Dimension | DPoP (OAuth 2.0) | Asymmetric Keys (JWT) | HTTP Message Signatures | Static API Keys |
|---|---|---|---|---|
| **Primary use case** | FAPI-compliant access delegation | Server-to-server B2B | High-stakes financial transactions | Simple / naive client integrations |
| **Token theft protection** | Excellent — sender-constrained | Good — short-lived tokens | Excellent — request-specific | Poor — secret is the credential |
| **Developer complexity** | High | Medium | High | Very low |
| **Infrastructure overhead** | Low | Very low | Low | Very low |
| **Key rotation complexity** | Medium — JWKS endpoint refresh | Low — kid-based rotation | High — coordinate both sides | Low — reissue and revoke |
| **Replay attack resistance** | Strong — nonce + jti | Moderate — exp window | Strong — created/expires fields | None (without nonce layer) |
| **Clock skew sensitivity** | Medium | Medium | High | None |
| **Credential revocation** | Fast — token introspection | Delayed — until token expires | Fast — key revocation propagates | Instant |
| **Audit trail depth** | Rich — per-token, per-request | Basic — JWT claims only | Rich — signed payload hash | Basic — key identity only |
| **Partner onboarding** | Weeks | Days | Weeks | Minutes |
| **Multi-tenant isolation** | Native — scopes + audience | Manual — claims design | Manual — key-per-tenant | Manual — key-per-tenant |
| **Regulatory fit** | PSD2, Open Banking | SOC 2, ISO 27001 | PCI-DSS, FIPS | Internal / low-risk only |

---

## Gaps in the Original Analysis

- The three strategies were framed as mutually exclusive; a production architecture should **layer** them by partner tier.
- **Credential revocation speed** was omitted. In a breach, this is the difference between a 5-minute and 24-hour exposure window.
- JWT's "good" theft protection degrades if tokens are long-lived, which is common in B2B for convenience.
- No treatment of **key lifecycle management** — provisioning, rotation, emergency revocation, or grace periods.
- **Partner onboarding time** is a material cost not reflected in the original table.

---

## Fourth Option: Static API Keys (for Naive Clients)

For partners with limited engineering capability or simple use cases (webhooks, read-only integrations, PoC phases), a **static API key** tier provides the lowest possible onboarding friction.

### Design principles

- Keys are opaque random strings (e.g. 256-bit, base64url-encoded), prefixed for easy identification: `prod_sk_...`, `test_sk_...`
- Keys are **hashed at rest** (Argon2id or SHA-256 with salt) — the plaintext is shown only once at creation
- Each key is bound to a **tenant ID** and a **scope set** at creation time
- Keys are short-lived by default (90-day expiry) with optional manual renewal
- All requests carry the key in the `Authorization: Bearer <key>` header over TLS 1.2+

### Mitigations for the weaker security posture

| Risk | Mitigation |
|---|---|
| Key leakage | Hashed at rest; shown once; immediate revocation available |
| Replay attacks | Rate limiting + request ID header (idempotency key) |
| Overprivileged keys | Mandatory scope selection at creation |
| Long-lived exposure | Default 90-day TTL; rotation reminders via webhook/email |
| No sender binding | Optionally pair with IP allowlist or mTLS at tenant's request |

### Graduation path

Static API keys should be the **entry point**, not the destination. Build a clear upgrade prompt in the developer portal: partners handling sensitive data or hitting volume thresholds are guided toward asymmetric JWT or DPoP automatically.

---

## Customer-Managed Keys, Scopes, and Rotation

### Architecture overview

Customers manage their own credentials via a **self-service key management portal** (API + UI), backed by a centralised key lifecycle service.

```
┌─────────────────────────────────────────────────┐
│              Developer Portal / API              │
│  Create key · Set scopes · Rotate · Revoke       │
└────────────────────┬────────────────────────────┘
                     │
          ┌──────────▼──────────┐
          │   Key Lifecycle      │
          │   Service (KLS)      │
          │  - Issue             │
          │  - Store (hashed)    │
          │  - Rotate            │
          │  - Revoke            │
          │  - Audit log         │
          └──────────┬──────────┘
                     │
     ┌───────────────┼───────────────┐
     ▼               ▼               ▼
  JWKS endpoint   Token store   Scope registry
```

### Key management

- Customers can hold **1–N keys simultaneously** per environment (production / sandbox)
- Each key has a human-readable label, creation timestamp, last-used timestamp, and expiry
- Key creation requires scope selection — no key can be created without an explicit scope set
- On creation, the plaintext key is returned **once only** and never retrievable again
- Customers can generate a **replacement key** before revoking the old one, enabling zero-downtime rotation

### Scope design

Scopes follow a `resource:action` pattern and are additive:

```
read:invoices          write:invoices
read:customers         write:customers
read:webhooks          manage:webhooks
admin:keys             (restricted — enables key management API)
```

- Scopes are **allowlisted per tenant** by the platform at onboarding; customers cannot self-assign scopes beyond their contracted set
- The UI shows scope descriptions in plain language alongside the technical identifier
- API responses include the `X-Granted-Scopes` header so integrators can verify runtime permissions

### Rotation workflow

#### Manual rotation (customer-initiated)

1. Customer creates a new key in the portal (same or updated scope set)
2. Both old and new keys are **valid simultaneously** during the grace period (configurable: 1–72 hours)
3. Customer deploys the new key to their systems
4. Customer revokes the old key manually, or it expires automatically at grace period end
5. Audit log records both keys, the overlap window, and the revoking identity

#### Automated rotation (platform-initiated)

- Configurable expiry policy (30 / 60 / 90 / 180 days)
- Platform sends rotation reminders at T-14 and T-3 days via webhook and email
- If a key expires without rotation, access is suspended (not deleted) for a 7-day recovery window
- Emergency revocation (e.g. suspected compromise) takes effect in under 60 seconds via cache invalidation

### Audit and observability

Every key lifecycle event is written to an **immutable audit log** visible to the customer:

| Event | Logged fields |
|---|---|
| Key created | timestamp, actor, scopes, expiry, environment |
| Key used | timestamp, key ID (not plaintext), endpoint, response code |
| Scope changed | timestamp, actor, old scopes, new scopes |
| Key rotated | timestamp, actor, old key ID, new key ID, overlap window |
| Key revoked | timestamp, actor, reason code |

Customers can export their audit log via API. The platform retains 12 months of log history.

---

## Recommended Tiered Architecture

| Partner tier | Strategy | Trigger to upgrade |
|---|---|---|
| New / naive | Static API keys | Default entry point |
| Standard B2B | Asymmetric JWT | Volume > 10k req/day or PII in payload |
| Regulated / financial | DPoP | Open Banking, PSD2, or contractual requirement |
| High-stakes transactions | HTTP Message Signatures | PCI-DSS scope or financial audit requirement |

### Cross-cutting recommendations

1. **Use mTLS as a transport complement** regardless of signing strategy — client identity at the network layer, key never leaves the partner's infrastructure.
2. **Build the key lifecycle plane once** and have all four strategies consume it for rotation, revocation, and audit.
3. **JWKS endpoint** — publish a rotating JWKS for JWT and DPoP strategies; consumers cache with a short TTL (5 min) and refresh on 401.
4. **Instrument everything** — log `key_id`, `tenant_id`, `scope`, `endpoint`, and `latency` on every request for anomaly detection baseline.
5. **Never store plaintext keys** — hash at rest with Argon2id (for static keys) or store only the public key component (for asymmetric strategies).

---

*Document generated from architectural review session. Strategies should be validated against your specific regulatory obligations and partner technical profile before implementation.*
