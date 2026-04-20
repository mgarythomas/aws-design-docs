# Typescript Lambda

## Code Structure
store lambdas in their own named subfolder beneath a parent '/lambdas' folder.

Adhere to the following structure.
```
src/
  handlers/
    createOrder.ts       ← handler entrypoint (thin)
  services/
    orderService.ts      ← business logic
  repositories/
    orderRepository.ts   ← data access
  models/
    order.ts             ← types/interfaces
  utils/
    logger.ts
    errors.ts
handler.ts               ← re-exports handler
```

## Code Length & Complexity
- Handler file: 20–60 lines. If it's longer, you're doing too much in the handler.
- Service classes: 100–300 lines per file. Split by domain concept, not by line count.
- Total Lambda codebase: ideally under 1,000 lines of application code per function. 

If you're pushing past that, question whether this should be one function or several.

The goal is that any engineer can understand the entire execution path of a Lambda in a single reading session.

## Packaging & Build
Esbuild is the right choice. It's significantly faster than tsc + webpack, produces smaller bundles, and handles tree-shaking well. The standard pattern is:

```typescript
import { build } from 'esbuild';
build({
  entryPoints: ['src/handlers/createOrder.ts'],
  bundle: true,
  minify: true,
  platform: 'node',
  target: 'node20',
  outfile: 'dist/createOrder.js',
  external: ['@aws-sdk/*'],  // critical — exclude AWS SDK v3 (pre-bundled in Node 18+)
});
```

## Database persistence

### ORM Tool 

- Prisma, Only version 7 and above.
- Do not bundle the rust binary query engine
- All Lambda must enable cold start
- Must use RDS proxy for all invocations
