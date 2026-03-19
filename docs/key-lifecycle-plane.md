# Key Lifecycle Plane (KLP) — Detailed Design

## Overview

The Key Lifecycle Plane is a shared internal service that all authentication strategies delegate credential management to. It is the secrets control plane for the B2B platform — no individual authentication strategy manages its own storage, rotation, or revocation logic. Instead, each strategy (Static API Keys, Asymmetric JWT, DPoP, HTTP Message Signatures) consumes the KLP for issuance, validation, rotation, and revocation.

### Design goals

- Single source of truth for all credential state across all authentication tiers
- Sub-millisecond validation on the hot path via cache-first architecture
- Customer self-service for key creation, scope management, and rotation
- Revocation propagation within 60 seconds across all gateway nodes
- Immutable audit trail queryable by both customers and platform operators

---

## Architecture

The KLP comprises four internal subsystems, three shared stores, and a notification bus. External callers are the developer portal (customer-initiated actions), the API gateway (per-request validation), and the scheduler (background expiry and reminder jobs).

```
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Developer portal │   │   API gateway    │   │    Scheduler     │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘
         │                      │                       │
         └──────────────────────┴───────────────────────┘
                                │
          ┌─────────────────────▼──────────────────────┐
          │           Key Lifecycle Plane               │
          │                                             │
          │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
          │  │ Issuance │ │Validation│ │ Rotation │ │Revocation│ │
          │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
          │       │            │             │             │       │
          │  ┌────▼────────────▼─────┐  ┌───▼─────┐  ┌───▼─────┐ │
          │  │   Credential store   │  │Revocation│  │  Audit  │ │
          │  │  hashed keys + meta  │  │  cache   │  │   log   │ │
          │  └──────────────────────┘  └──────────┘  └────┬────┘ │
          └──────────────────────────────────────────────┬─┘      
                                                         │
                                          ┌──────────────▼──────────────┐
                                          │  Notification bus            │
                                          │  webhooks / email            │
                                          └─────────────────────────────┘
```

---

## Subsystem: Issuance

Issuance is responsible for generating a cryptographically safe credential and binding it to tenant identity and permissions before it ever reaches storage. It is invoked by the developer portal when a customer creates a new key.

### Generation

Keys are generated using a cryptographically secure random number generator (CSPRNG) producing 32 bytes, encoded as base64url. A structured prefix is prepended to make keys visually identifiable and safely greppable in logs without exposing sensitive material:

```
prod_sk_<base64url(32 bytes)>
test_sk_<base64url(32 bytes)>
```

The plaintext key is returned to the caller exactly once in the creation response and then discarded. The KLP retains no copy of the plaintext.

### Storage format

The credential store record for each key contains:

| Field | Description |
|---|---|
| `key_id` | Non-secret UUID, used as the primary reference in all logs and API responses |
| `key_hash` | Argon2id hash of the plaintext key |
| `tenant_id` | Owning tenant |
| `label` | Human-readable name set by the customer |
| `scope_set` | Array of granted scopes |
| `environment` | `production` or `sandbox` |
| `status` | `active`, `grace`, `expired`, or `revoked` |
| `created_at` | Issuance timestamp |
| `expires_at` | Computed from tenant expiry policy at creation |
| `last_seen_at` | Updated asynchronously on each successful validation |
| `grace_until` | Set during rotation; null otherwise |

Argon2id is used over SHA-256 for static keys because it is deliberately slow and memory-hard, making offline brute-force against a stolen credential store infeasible.

### Scope binding

The scope set is the critical policy enforcement point at issuance. The customer selects from their contracted scope set; the issuance subsystem validates this selection against the tenant's platform-managed allowlist and rejects anything outside it. No key can ever be issued with more permissions than the tenant's contract permits. This separation — customer controls their own keys, platform controls the ceiling — is the foundation of the self-service model.

Scopes follow a `resource:action` pattern:

```
read:invoices        write:invoices
read:customers       write:customers
read:webhooks        manage:webhooks
admin:keys
```

`admin:keys` is a restricted scope that enables the key management API itself. It must be explicitly contracted and cannot be self-assigned.

---

## Subsystem: Validation

Validation is the hot path, called on every inbound API request. Latency is the primary constraint; correctness is non-negotiable.

### Request flow

```
Inbound request
       │
       ▼
Extract key from Authorization: Bearer header
       │
       ▼
Parse key_id from prefix
       │
       ▼
Check revocation cache  ──── HIT ──── Reject (401)
       │ MISS
       ▼
Verify Argon2id hash against credential store
       │ FAIL
       ├──────────────────────────────── Reject (401)
       │ PASS
       ▼
Check status: active or grace?  ──── NO ──── Reject (401)
       │ YES
       ▼
Return (tenant_id, scope_set) to gateway
       │
       ▼
Update last_seen_at (async, fire-and-forget)
```

The revocation cache check is in-memory and sub-millisecond. A cache hit causes immediate rejection without touching the database. The hash verification is the only step with meaningful latency; this can be reduced by caching a verified `(key_id → tenant_id, scope_set)` mapping with a short TTL (30–60 seconds) so repeated calls with the same key avoid redundant hash computation.

### Grace window handling

During rotation, a tenant may legitimately hold two valid keys simultaneously. The validation subsystem accepts both `active` and `grace` status. The gateway is unaware of which key is in which state — it receives only the resolved `(tenant_id, scope_set)` tuple and proceeds normally.

### Scope enforcement

The gateway enforces scope against the requested endpoint after receiving the resolved scope set from validation. This is a deliberate separation: the KLP resolves *what is permitted*, the gateway enforces *what is requested*. Neither system needs to understand the other's internals.

---

## Subsystem: Rotation

Rotation is where most customer-facing complexity lives. The design is deliberately forgiving — the goal is zero-downtime key replacement without requiring customers to coordinate a precise cutover.

### Standard rotation flow

```
1. Customer creates new key via portal or API
         │
         ▼
2. New key issued with status: active
   Old key transitions to status: grace
   grace_until = now + grace_window (default 24h, range 1–72h)
         │
         ▼
3. Both keys valid simultaneously during grace window
         │
         ▼
4a. Customer manually revokes old key  ──OR──  4b. grace_until passes, scheduler auto-revokes
         │
         ▼
5. Old key status: revoked, revocation cache poisoned
   Audit log records both key IDs, overlap duration, revocation identity
```

The grace window is configurable per-key at rotation time. Customers running automated deployment pipelines may want a shorter window (1–4 hours); those with manual processes may want the full 72 hours.

### Emergency rotation

When a key compromise is suspected, the standard grace window is bypassed:

- Old key is immediately set to `revoked`
- Revocation cache is poisoned within 60 seconds
- Customer is notified via webhook and email
- A new key can be issued immediately if needed

Emergency rotation is available via the portal and the management API (`DELETE /keys/{key_id}?reason=compromised`).

### Scheduler jobs

The scheduler runs two background jobs that interact with the rotation subsystem:

**Expiry sweeper** — runs hourly. Finds all keys where `expires_at < now` and `status = active`. Transitions them to `expired`, triggers the 7-day recovery window (status remains queryable but key is rejected by validation), then permanently revokes after recovery window.

**Reminder dispatcher** — runs daily. Finds all keys where `expires_at` is within 14 days or 3 days. Fires a reminder payload to the tenant's registered webhook and email address. The payload includes:

```json
{
  "event": "key.expiry_reminder",
  "key_id": "...",
  "label": "Production integration key",
  "expires_at": "2026-06-15T00:00:00Z",
  "days_remaining": 14,
  "rotate_url": "https://portal.example.com/keys/rotate?key_id=...&token=..."
}
```

The `rotate_url` is a pre-signed deep link valid for 48 hours, enabling a human or automated system to initiate rotation without separately authenticating to the portal.

---

## Subsystem: Revocation

Revocation must be fast and final. The architecture uses a two-layer approach: a durable write to the credential store combined with an immediate push to the revocation cache.

### Propagation guarantee

| Layer | Write | Read latency | Durability |
|---|---|---|---|
| Credential store | Synchronous | ~5ms | Full |
| Revocation cache | Async push after credential write | <1ms | TTL-based |

The revocation cache holds denied `key_id` values with a TTL slightly longer than the validation subsystem's cache refresh interval. This ensures no validation node can serve a stale `active` result after revocation. Maximum propagation delay across all gateway nodes is under 60 seconds.

On cache node failure, the validation subsystem falls back to a synchronous credential store lookup for the status field. This adds latency but maintains correctness — a revoked key will never be accepted.

### Retention policy

Keys are never hard-deleted. The lifecycle is:

```
active → grace → revoked → [90-day retention] → purged
active → expired → [7-day recovery] → revoked → [90-day retention] → purged
```

Retaining revoked keys for 90 days supports audit queries of the form "was this key valid at the time of this request?" — essential for dispute resolution in financial and regulated contexts.

---

## Shared stores

### Credential store

The primary database for all key records. Characteristics:

- Relational schema with row-level tenant isolation
- Encryption at rest (AES-256)
- Audit triggers on every write — no record can be modified without an audit event
- Never queried directly by gateway nodes; all access is through the validation subsystem
- Indexed on `(key_id)`, `(tenant_id, status)`, and `(expires_at, status)` for scheduler efficiency

### Revocation cache

A distributed in-memory store (Redis or equivalent) keyed by `key_id`. Traded durability for speed. Cache node failure degrades to synchronous database reads — see revocation propagation above.

TTL for each entry is set to `max(grace_until, expires_at) + 5 minutes` to ensure expired entries are not retained indefinitely.

### Audit log

An append-only, tenant-partitioned event stream. Key design constraints:

- Writes are off the critical path — validation and mutation operations write to an async queue that drains to the log store
- Customers can query their own partition via the management API
- Platform operators have cross-tenant read access for incident investigation
- Retained for a minimum of 12 months; configurable per tenant for regulatory requirements

#### Logged events

| Event | Key fields logged |
|---|---|
| `key.created` | timestamp, actor, key_id, scopes, expiry, environment |
| `key.validated` | timestamp, key_id, endpoint, response code |
| `key.scope_changed` | timestamp, actor, key_id, old_scopes, new_scopes |
| `key.rotation_started` | timestamp, actor, old_key_id, new_key_id, grace_window |
| `key.revoked` | timestamp, actor, key_id, reason_code |
| `key.expired` | timestamp, key_id, was_rotated |
| `key.grace_ended` | timestamp, key_id, trigger (manual / auto) |

---

## Notification bus

The notification bus delivers lifecycle events to customer-registered endpoints via webhook and email. It is not on the critical path — delivery is best-effort with retry (3 attempts, exponential backoff, 24-hour window).

Customers register a webhook URL and signing secret via the portal. All webhook payloads are signed with HMAC-SHA256 using the signing secret, allowing customers to verify authenticity. The signature is delivered in the `X-KLP-Signature` header.

Events delivered via the notification bus mirror the audit log events, with the addition of `key.expiry_reminder` (T-14 and T-3 days) and `key.compromised_suspected` (triggered by platform anomaly detection or manual emergency revocation).

---

## mTLS alternatives

mTLS was considered as a transport complement to the KLP's credential strategies but excluded due to operational overhead. The following lighter alternatives are recommended instead, in order of increasing strength:

| Alternative | Mechanism | Overhead | Adds |
|---|---|---|---|
| IP allowlisting | Customer registers allowed source IPs at key creation | Minimal | Network-layer origin check |
| HMAC request signing | Shared secret signs a request fingerprint | Low | Per-request integrity, replay resistance |
| Short-lived setup tokens | Secure channel used once to exchange a long-lived credential | Low | Protected initial handshake |

IP allowlisting can be combined with any KLP-issued key as an optional additional control, configured per-key in the portal. It is recommended for customers with static server infrastructure and provides a meaningful reduction in blast radius if a key is leaked.

---

## Customer self-service summary

Customers interact with the KLP exclusively through the developer portal and the management API. The platform retains control of the scope ceiling; customers control everything within it.

| Capability | Customer can | Platform controls |
|---|---|---|
| Key creation | Create keys, set label, choose scopes from allowlist | Scope allowlist, max keys per tenant |
| Scope management | Modify scopes on existing keys (within allowlist) | Contracted scope ceiling |
| Rotation | Initiate rotation, set grace window, revoke old key | Minimum/maximum grace window bounds |
| Expiry policy | Choose TTL within allowed range (30–180 days) | Allowed TTL range per tier |
| Emergency revocation | Revoke any key instantly | — |
| Audit log | Query own partition, export via API | Cross-tenant access, retention policy |
| Webhook registration | Register URL and signing secret | — |

---

*This document covers the internal design of the Key Lifecycle Plane. See the API Key Strategy document for the broader authentication tier architecture and partner onboarding guidance.*
