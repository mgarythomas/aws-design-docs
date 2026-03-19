# Scope Management and Policy-Based Authorisation

## Overview

This document describes how OAuth 2.0 scope management and Cedar-based policy enforcement work together to provide a two-layer authorisation model for the B2B platform. Scopes act as the coarse-grained gate at the API boundary; Cedar policies provide fine-grained, attribute-based governance within that boundary.

The two layers are complementary and intentionally distinct. Conflating them — either by pushing business rules into scope design, or by removing scope enforcement in favour of Cedar alone — produces a system that is harder to reason about, slower under load, and opaque to partners who need to understand their permission surface.

---

## The two-layer model

### Layer 1: OAuth scope enforcement (API gateway)

Scopes answer a coarse question: *does this client have permission to interact with this resource category at all?* This check happens at the API gateway, before Cedar is invoked, using only the validated JWT and the endpoint being requested. It is stateless, fast, and documented — scopes form part of the API contract that partners read and reason about.

A request that fails scope enforcement is rejected at the gateway with `403 Forbidden` and never reaches Cedar or the resource server.

### Layer 2: Cedar policy evaluation (PEP)

Cedar answers fine-grained questions: *given that this client is authenticated and holds the relevant scope, is this specific action on this specific resource permitted under current policy?* Cedar can express constraints that scopes cannot: resource ownership, resource state, environmental conditions, token binding requirements, tenant-level feature flags, and time-based rules.

A request that passes scope enforcement is forwarded to the resource server, which invokes the Cedar PEP before handling the request. A Cedar `Deny` produces a `403 Forbidden` with a policy-specific reason code; a `Permit` allows execution to proceed.

### Request flow

```
Client request
      │
      ▼
API gateway
  Validate JWT signature + expiry
  Enforce scope against endpoint
      │
      ├── scope miss ──► 403 Forbidden (insufficient scope)
      │
      ▼
Cedar PEP
  Construct principal, action, resource, context
  Evaluate policy set
      │
      ├── Deny ──► 403 Forbidden (policy denied)
      │
      ▼
Resource server
  Handle request
      │
      ▼
200 OK
```

The gateway passes resolved identity context to downstream services as trusted headers after JWT validation:

```
X-Tenant-Id:        tenant_xyz
X-Client-Id:        client_id_abc
X-Granted-Scopes:   read:invoices write:invoices
X-Token-Environment: production
X-DPoP-Bound:       true
```

The Cedar PEP reads these headers to construct its authorisation request. It does not re-validate the JWT — that responsibility stays with the gateway.

---

## Scope design

### The three layers of scope management

There is a meaningful difference between what a client *can* request, what it *does* request, and what the authorisation server *grants*. These are three separate decisions made by three different actors.

#### Scope registry (platform-controlled)

The scope registry is the complete catalogue of every scope that exists in the system. No scope can be granted that does not exist here. This layer changes only when a new API capability is added and is entirely under platform control.

```
read:invoices        write:invoices
read:customers       write:customers
read:webhooks        manage:webhooks
admin:keys
```

`admin:keys` enables the key management API. It must be explicitly contracted and cannot be self-assigned by a customer.

#### Tenant allowlist (contract-controlled)

At onboarding, each tenant is assigned a subset of the registry based on their contract tier. This is the hard ceiling — a customer can never grant a key more than their allowlist permits, regardless of what they request.

Example: a read-only integration partner receives `read:invoices read:customers`. A full-tier partner receives the complete registry minus `admin:keys` unless explicitly contracted.

#### Key scope set (customer-controlled)

Within their allowlist, the customer assigns scopes to individual keys. They might create a reporting key with only `read:invoices` even though their allowlist includes write access. This is least-privilege in practice, under the customer's own control.

At token request time, the authorisation server computes:

```
granted_scope = requested_scope ∩ key_scope_set ∩ tenant_allowlist
```

Each intersection takes the narrower set. If the client omits the `scope` parameter entirely, the full key scope set is granted by default (RFC 6749 default behaviour).

### Scope naming convention

Scopes follow a `resource:action` pattern and are intentionally coarse — a single scope covers a class of operations, not individual actions. The granularity below the scope boundary is Cedar's responsibility.

| Scope | Covers |
|---|---|
| `read:invoices` | List, fetch, search invoices |
| `write:invoices` | Create, update, void invoices |
| `read:customers` | List, fetch customer records |
| `write:customers` | Create, update customer records |
| `manage:webhooks` | Register, update, delete webhook endpoints |
| `admin:keys` | Create, rotate, revoke API keys via management API |

### Downscoping at token request time

Clients may request a token with *fewer* scopes than their key holds. This limits the blast radius of a token compromise when performing a narrow operation:

```http
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&scope=read:invoices
```

The authorisation server issues a token scoped only to `read:invoices` even if the key holds additional scopes. This does not modify the key's scope set — it only affects the individual token.

The key scope set defines the *envelope* of what an integration can ever do. Token scopes define what it is doing *right now*.

### Customer self-service scope management

| Action | Actor |
|---|---|
| Define which scopes exist | Platform |
| Set which scopes a tenant may use | Platform (at contract time) |
| Assign scopes to a specific key | Customer |
| Reduce scopes on an existing key | Customer (within allowlist) |
| Increase scopes on an existing key | Customer (within allowlist — cannot exceed ceiling) |
| Request a narrowed token at runtime | Client (at token acquisition) |
| Audit scope changes on a key | Customer (read own), Platform (read all) |

---

## Cedar policy-based authorisation

### Why Cedar alongside scopes

Scopes provide a documented, contract-visible permission surface. Partners read them, SDKs use them, and they are part of the public API contract. Cedar policies are internal governance logic — partners do not read them and should not need to.

Cedar's value is in constraints that scopes cannot express:

- Resource ownership: "a client may only act on resources that belong to their tenant"
- Resource state: "a client may only void an invoice in `draft` status"
- Environmental conditions: "this action requires a DPoP-bound token"
- Tenant feature flags: "this action is only permitted for tenants on the Enterprise tier"
- Composite rules: combinations of the above that would require an explosion of scopes if expressed at the OAuth layer

### Cedar concepts mapped to B2B

Cedar evaluates every authorisation request as a tuple of `(principal, action, resource, context)`.

#### Principal

The principal represents the B2B client. In a client credentials flow there is no end user, so the principal is the client itself. A two-level hierarchy is recommended:

- `Tenant::"tenant_xyz"` — the owning organisation
- `Client::"client_id_abc"` — a specific integration, child of the tenant

This allows policies to apply to an entire tenant or to a specific client within a tenant.

#### Action

Actions map to the fine-grained operations within a scope. Where the scope `write:invoices` covers all write operations, Cedar distinguishes `Invoice::Action::"Create"`, `Invoice::Action::"Update"`, and `Invoice::Action::"Void"` as separate actions with potentially different policy rules.

#### Resource

The specific entity being acted on: `Invoice::"inv_123"`, `Customer::"cust_456"`. This is the level at which Cedar provides the most value — individual resource instances with attributes such as ownership, status, and value.

#### Context

Dynamic request attributes not captured in the principal or resource entity model:

- `request_time` — for time-based policy conditions
- `environment` — `production` or `sandbox`
- `dpop_bound` — whether the token was issued with DPoP binding
- `ip_address` — for IP allowlist conditions
- `scopes` — the granted scope set from the JWT (used as a condition in policies)

---

## Cedar schema

```
namespace B2B {

  entity Tenant {};

  entity Client {
    tenant:      Tenant,
    scopes:      Set<String>,
    environment: String,
  };

  entity Invoice {
    owner_tenant:  Tenant,
    status:        String,
    amount_cents:  Long,
  };

  entity Customer {
    owner_tenant: Tenant,
  };

  action Create, Read, Update, Void
    appliesTo {
      principal: [Client],
      resource:  [Invoice, Customer],
    };
}
```

---

## Cedar policy examples

### Basic tenant isolation

The foundational policy — a client may only act on resources that belong to their own tenant. This applies to every action on every resource type and should be expressed as a base-level permit with ownership as a mandatory condition:

```
permit (
  principal is B2B::Client,
  action,
  resource is B2B::Invoice
)
when {
  resource.owner_tenant == principal.tenant
};
```

### Scope-gated read access

Scope presence is verified as a Cedar condition. The gateway has already confirmed the token is valid; Cedar uses the scope as one condition among many:

```
permit (
  principal is B2B::Client,
  action == B2B::Action::"Read",
  resource is B2B::Invoice
)
when {
  principal.scopes.contains("read:invoices") &&
  resource.owner_tenant == principal.tenant
};
```

### State-conditional write

A client may update an invoice only if it is in `draft` status. Attempting to update a `posted` or `voided` invoice is denied regardless of scope:

```
permit (
  principal is B2B::Client,
  action == B2B::Action::"Update",
  resource is B2B::Invoice
)
when {
  principal.scopes.contains("write:invoices") &&
  resource.owner_tenant == principal.tenant &&
  resource.status == "draft"
};
```

### High-stakes action requiring DPoP binding

Voiding an invoice is treated as a high-stakes operation. It requires the `write:invoices` scope, tenant ownership, draft status, an amount below a threshold, and a DPoP-bound token. None of these conditions beyond the scope check are expressible in OAuth alone:

```
permit (
  principal is B2B::Client,
  action == B2B::Action::"Void",
  resource is B2B::Invoice
)
when {
  principal.scopes.contains("write:invoices") &&
  resource.owner_tenant == principal.tenant &&
  resource.status == "draft" &&
  resource.amount_cents < 1000000 &&
  context.dpop_bound == true
};
```

### Sandbox isolation

Production clients must not be able to act on sandbox resources, and vice versa:

```
forbid (
  principal is B2B::Client,
  action,
  resource
)
unless {
  principal.environment == context.environment
};
```

This is a `forbid` rule — Cedar's default-deny model means that without a matching `permit`, requests are already denied. `forbid` rules add an explicit override that blocks even when a `permit` would otherwise match, making the sandbox/production boundary inviolable.

---

## PEP authorisation request construction

The PEP constructs the Cedar authorisation request from the trusted headers injected by the gateway, combined with entity data fetched from the platform's data layer.

```json
{
  "principal": { "type": "B2B::Client", "id": "client_id_abc" },
  "action":    { "type": "B2B::Action", "id": "Void" },
  "resource":  { "type": "B2B::Invoice", "id": "inv_123" },
  "context": {
    "tenant_id":   "tenant_xyz",
    "scopes":      ["read:invoices", "write:invoices"],
    "environment": "production",
    "dpop_bound":  true,
    "request_time": "2026-03-19T10:00:00Z"
  },
  "entities": [
    {
      "uid": { "type": "B2B::Client", "id": "client_id_abc" },
      "attrs": {
        "tenant":      { "type": "B2B::Tenant", "id": "tenant_xyz" },
        "scopes":      ["read:invoices", "write:invoices"],
        "environment": "production"
      },
      "parents": [{ "type": "B2B::Tenant", "id": "tenant_xyz" }]
    },
    {
      "uid": { "type": "B2B::Invoice", "id": "inv_123" },
      "attrs": {
        "owner_tenant": { "type": "B2B::Tenant", "id": "tenant_xyz" },
        "status":       "draft",
        "amount_cents": 10000
      },
      "parents": []
    }
  ]
}
```

### Entity data caching

The resource entity data (invoice status, owner tenant, amount) must be fetched from the platform's data layer before the Cedar evaluation can proceed. This fetch is the primary latency contributor in the PEP path.

Recommended approach: a per-request in-process cache with a short TTL (5–10 seconds). For high-throughput endpoints, a shared read-through cache (Redis or equivalent) keyed on `(resource_type, resource_id)` with a TTL of 30–60 seconds is appropriate, accepting a small window of stale attribute data. For operations where stale data is unacceptable — particularly the `Void` action — the entity fetch should bypass the cache and read directly from the source of truth.

---

## Responsibility boundary summary

| Question | Answered by |
|---|---|
| Does this client type have access to this resource category? | OAuth scope at gateway |
| Is the JWT signature valid and unexpired? | API gateway |
| Does this client own the resource they are acting on? | Cedar policy |
| Is this action permitted given the current resource state? | Cedar policy |
| Does this tenant have the feature enabled for this action? | Cedar policy (context) |
| Was the token issued in the right environment? | Both — JWT claim and Cedar context condition |
| Was this token issued with DPoP binding? | Cedar context condition |
| Is this request within rate or volume limits? | Gateway or Cedar context condition |

---

## Operational considerations

### Policy deployment

Cedar policies are stored and versioned separately from application code. A policy change takes effect at next evaluation — there is no need to redeploy the application. Policy sets should be tested in a staging environment against a representative corpus of authorisation requests before promotion to production, as a Cedar `forbid` rule that is too broad will silently deny legitimate requests.

### Authorisation decision logging

Every Cedar evaluation should emit a structured log entry regardless of outcome:

```json
{
  "decision":   "Deny",
  "principal":  "B2B::Client::client_id_abc",
  "action":     "B2B::Action::Void",
  "resource":   "B2B::Invoice::inv_123",
  "reason":     "dpop_bound condition not satisfied",
  "tenant_id":  "tenant_xyz",
  "request_id": "req_abc123",
  "latency_ms": 3
}
```

Deny decisions should be surfaced to the customer's audit log (via the KLP notification bus) with the `reason` field, enabling self-service debugging without requiring a support ticket. The reason field must not leak internal policy structure — describe the condition that failed in plain language rather than exposing policy identifiers.

### Relationship to the Key Lifecycle Plane

The Cedar PEP receives its principal attributes (scopes, environment, tenant) from the JWT validated and forwarded by the gateway. The KLP is the source of truth for those attributes at token issuance time. Changes to a key's scope set take effect at the next token acquisition — existing tokens retain the scopes they were issued with until they expire.

This means a scope reduction on a key in the portal does not immediately affect in-flight tokens. If immediate scope reduction is required (for example, following a suspected over-permission), the appropriate action is emergency revocation of the key via the KLP, forcing re-authentication and re-issuance with the updated scope set.

---

*This document covers scope management and Cedar-based policy authorisation. See the API Key Strategy document for the broader authentication tier architecture, and the Key Lifecycle Plane document for credential issuance, rotation, and revocation.*
