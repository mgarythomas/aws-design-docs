---
inclusion: always
---

# Coding Conventions

## TypeScript

- Strict mode always on — no `any`, no unsafe type assertions
- Target: ES2020, module resolution: `bundler`
- Prefer explicit return types on exported functions
- Use `interface` for object shapes, `type` for unions/intersections

## Formatting (Prettier)

- Print width: 100 characters
- 2-space indentation, no tabs
- Single quotes, semicolons, trailing commas (ES5)
- Arrow function parens: always
- Line endings: LF

## Naming

- **Packages**: `@repo/kebab-case`
- **Components**: `PascalCase` files and exports
- **Utilities/types**: `camelCase` functions, `kebab-case` filenames
- **Directories**: `kebab-case`

## File Structure

```
src/
  app/           # Next.js App Router pages and layouts
  components/    # App-specific components
  lib/           # App-specific utilities, schemas, types
  config/        # App-specific configuration
  __tests__/     # Unit and integration test files
```

## React

- Functional components only — no class components
- TypeScript prop types inline or as named interfaces (no PropTypes)
- Tailwind utility classes for all styling — no inline styles, no CSS modules
- Use `clsx` + `tailwind-merge` (via `cn()` from `@repo/ui`) for conditional classes
- Forms: `react-hook-form` + `zod` validation via `@hookform/resolvers`

## Framework

- **Next.js 16** — all apps use Next.js 16.x with the App Router
- No Pages Router usage

## Commit Messages (Conventional Commits)

```
feat: add new button variant
fix: resolve type error in shared-utils
docs: update README with new instructions
refactor: extract form logic into hook
test: add coverage for date utilities
chore: update dependencies
```

## Testing

### Unit & Integration Tests — Vitest (all packages and apps)

- **No Jest** — the entire monorepo uses Vitest exclusively for unit and integration tests
- Test runner: `vitest --run` (single execution, no watch in CI)
- Environment: `jsdom` for React components, `node` for pure utilities
- Setup: `@testing-library/react`, `@testing-library/jest-dom`, `@testing-library/user-event`
- Accessibility: `vitest-axe` / `axe-core` in `@repo/ui`
- AAA pattern: Arrange, Act, Assert
- Test files: co-located in `src/__tests__/` directories

### End-to-End Tests — Playwright

- All e2e tests live in the top-level `e2e/` folder — never inside app `src/` directories
- Structure:
  ```
  e2e/
    dashboard/
    exchange/
    auth/
    playwright.config.ts
  ```
- Run with `pnpm test:e2e` from the root

## Commands

```bash
pnpm test                              # Run all unit/integration tests (Vitest)
pnpm test:e2e                          # Run all e2e tests (Playwright)
pnpm lint                              # Lint all packages
pnpm type-check                        # Type check all packages
pnpm format                            # Format all files
pnpm --filter @repo/<package> <cmd>    # Target a specific package
```
