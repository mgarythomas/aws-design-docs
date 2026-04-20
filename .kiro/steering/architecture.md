---
inclusion: always
---

# Project Architecture

This is a **micro frontend monorepo** using Turborepo and pnpm workspaces.

## Apps

| App | Package | Port | Purpose |
|-----|---------|------|---------|
| `apps/dashboard` | `@repo/dashboard` | 3000 | Dashboard micro frontend |
| `apps/exchange` | `@repo/exchange` | 3001 | ASX announcement forms |
| `apps/auth` | `@repo/auth` | 3002 | Authentication micro frontend |
| `apps/storybook` | `@repo/storybook` | — | Component documentation |

## Shared Packages

| Package | Purpose |
|---------|---------|
| `@repo/ui` | Centralised shadcn component library (Radix UI primitives) |
| `@repo/design-tokens` | W3C design token → Tailwind CSS transformation |
| `@repo/shared-types` | Shared TypeScript types across all apps |
| `@repo/shared-utils` | Shared utilities (dates, strings, API, storage) |
| `@repo/tailwind-config` | Shared Tailwind CSS configuration |
| `@repo/typescript-config` | Shared TypeScript configurations |
| `@repo/eslint-config` | Shared ESLint configurations |

## Key Architectural Principles

1. **Check `packages/` first** — before creating any utility, type, or component, check if it already exists in a shared package
2. **Design tokens are the source of truth** — colours, spacing, and typography flow from `@repo/design-tokens` into Tailwind; never hardcode design values
3. **Components live in `@repo/ui`** — new reusable components belong there, not duplicated across apps
4. **Each app is independently deployable** — avoid tight coupling between apps
5. **Turborepo task graph** — `build` depends on `^build`; shared packages must be built before apps

## Internal Dependency Protocol

Use `workspace:*` for all internal package references:
```json
"@repo/ui": "workspace:*"
```

## CI/CD

GitLab CI/CD (`.gitlab-ci.yml`) — builds only affected packages using Turborepo's affected detection.
