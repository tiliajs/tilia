# Test App 2

This test app tests tilia and @tilia/react with:
- ReScript extension set to `.mjs`
- TypeScript tests that use ReScript gen types
- ReScript tests with gen types used in TypeScript
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

- `src/domain/Todo.res` - ReScript todos implementation using tilia
- `src/domain/todos.ts` - TypeScript wrapper that uses ReScript gen types
- `src/domain/todos.spec.ts` - TypeScript tests using ReScript gen types
- `src/domain/todos.feature.ts` - TypeScript BDD step definitions
- `src/domain/Todo.spec.mjs` - ReScript test file
- `src/view/TodoList.tsx` - React component using @tilia/react
- `src/view/TodoList.spec.tsx` - React component tests
