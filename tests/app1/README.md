# Test App 1

This test app tests tilia and @tilia/react with:
- ReScript extension set to `.res.mjs`
- TypeScript tests that use tilia functions
- ReScript tests that import TypeScript functions
- React component tests using @tilia/react

## Setup

```bash
pnpm install
```

## Build ReScript

```bash
pnpm res:build
```

## Run Tests

```bash
pnpm test
```

## Test Structure

- `src/domain/counter.ts` - TypeScript counter implementation using tilia
- `src/domain/counter.spec.ts` - TypeScript unit tests
- `src/domain/counter.feature.ts` - TypeScript BDD step definitions
- `src/domain/Counter.res` - ReScript tests that import TypeScript counter
- `src/domain/Counter.spec.res.mjs` - ReScript test file
- `src/view/Counter.tsx` - React component using @tilia/react
- `src/view/Counter.spec.tsx` - React component tests
