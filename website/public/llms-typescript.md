# Tilia LLM Guide (TypeScript)

AI-focused TypeScript documentation for the full Tilia API.

## Install

npm install tilia @tilia/react

## Primary Rule

- Use `carve` as the default for feature modules.
- `carve` binds a feature into one reactive object.
- `carve` must stay glue-only and avoid domain complexity.
- Put behavior in standalone arrow functions that accept `self`.
- Bind with `field: derived(field)` where possible.

## Canonical Carve Pattern

```typescript
import { carve, source } from "tilia";

type Feature = {
  count: number;
  double: number;
  add: (count: number) => void;
};

type Service = {
  fetchCount: () => (previous: number, set: (value: number) => void) => void;
  updateCount: (next: number, rollback: () => void) => void;
};

const double = (self: Feature): number => self.count * 2;

const add =
  (service: Service) =>
  (self: Feature) =>
  (count: number): void => {
    const prevValue = self.count;
    self.count += count; // optimistic write
    service.updateCount(self.count, () => (self.count = prevValue));
  };

export const makeFeature = (service: Service) =>
  carve<Feature>(({ derived }) => ({
    count: source(0, service.fetchCount()),
    double: derived(double),
    add: derived(add(service)),
  }));

const feature = makeFeature(service);
feature.add(4);
```

## Anti-Pattern (Avoid)

```typescript
import { carve } from "tilia";

// Avoid: logic-heavy body inside carve.
const feature = carve(({ derived }) => ({
  count: 0,
  double: derived((self) => {
    let acc = 0;
    for (let i = 0; i < self.count; i++) acc += 2;
    return acc;
  }),
}));
```

## Feature File Organization

Use this if the project does not provide other guidelines.

```text
[feature-name]/
  index.ts      // carve glue
  type.ts       // ts type of the feature
  computed.ts   // all computed/derived values
  actions.ts    // all mutating functions
  service.ts    // external dependencies (db fetch, etc)
```

## Full API Map (TypeScript)

### `tilia`

Wrap object/array into reactive proxy.

```typescript
import { tilia } from "tilia";
const state = tilia({ count: 0 });
state.count = 1;
```

### `carve`

Create feature object and inject `self` via `derived`.

```typescript
import { carve } from "tilia";

type Feature = { value: number; doubled: number };
const doubled = (self: Feature): number => self.value * 2;

const feature = carve<Feature>(({ derived }) => ({
  value: 1,
  doubled: derived(doubled),
}));
```

### `observe`

Push reactivity callback.

```typescript
import { observe } from "tilia";
observe(() => console.log(state.count));
```

### `watch`

Capture and effect separation.

```typescript
import { watch } from "tilia";
watch(
  () => state.count,
  (value) => console.log(value),
);
```

### `batch`

Group writes and flush once.

```typescript
import { batch } from "tilia";
batch(() => {
  state.a = 1;
  state.b = 2;
});
```

### `signal`

Single mutable reactive value and setter.

```typescript
import { signal } from "tilia";
const [count, setCount] = signal(0);
setCount(2);
```

### `derived` (signal API)

Derived signal from signals/reactive reads.

```typescript
import { signal, derived } from "tilia";
const [a, setA] = signal(1);
const b = derived(() => a.value * 2);
setA(2);
```

### `lift`

Expose signal in object as reactive value.

```typescript
import { signal, lift, tilia } from "tilia";
const [s, setS] = signal(0);
const state = tilia({ count: lift(s), setS });
```

### `readonly`

Insert immutable data wrapper without tracking inner mutations.

```typescript
import { tilia, readonly } from "tilia";
const app = tilia({ form: readonly({ version: 1 }) });
```

### `computed`

Pull-based derived value with cache + invalidation.

```typescript
import { computed, tilia } from "tilia";
const state = tilia({
  count: 1,
  double: computed(() => state.count * 2),
});
```

### `source` (async query and re-query)

Use `source(initial, setup)` for async loading and re-loading.

- `initial` is returned before first `set`.
- `setup(previous, set)` runs on first read.
- `setup(previous, set)` runs again when tracked dependencies in setup change.
- `set(next)` imperatively publishes a new value.
- `previous` is the latest emitted value, useful for incremental updates.
- `previous` also supports stale-while-revalidate UI (keep old data visible, e.g. greyed out, while reloading to avoid blinking).

```typescript
import { signal, tilia, source } from "tilia";

const sleep = () => new Promise((resolve) => setTimeout(resolve, 10));
const [query, setQuery] = signal("helena");

const fetchName =
  (q: string) =>
  async (previous: string, set: (value: string) => void): Promise<void> => {
    await sleep();
    if (q === "helena") set("Helena");
    else if (q === "bob") set("William");
    else set(`${previous}+${q}`);
  };

const user = tilia({
  name: source("Loading", fetchName(query.value)),
});

// Re-query
setQuery("bob");
```

#### `source` + `derived` inside `carve` (conditional loader strategy)

```typescript
const loader =
  (service: Service) =>
  (self: { projectId: string }) =>
  async (previous: Project, set: (value: Project) => void) => {
    set(stale(previous));
    const project = await service.loadProject(self.projectId);
    set(loaded(project));
  };

const selectProject = (self: ProjectBranch) => (id: string) => {
  self.projectId = id;
};

const projectBranch = carve<ProjectBranch>(({ derived }) => ({
  projectId: "main",
  project: source(empty(), derived(loader(service))),
  selectProject: derived(selectProject),
}));
```

Use this when loading depends on feature fields (`self.projectId`) and keep `previous` to preserve old UI data until new values are ready.

### `store`

Managed value with setup that returns current state and receives setter.

```typescript
import { tilia, store } from "tilia";
type Auth = { t: "LoggedOut" } | { t: "LoggedIn" };
const auth = (set: (next: Auth) => void): Auth => ({ t: "LoggedOut" });
const app = tilia({ auth: store(auth) });
```

### `make`

Create isolated Tilia context.

```typescript
import { make } from "tilia";
const ctx = make();
const local = ctx.tilia({ count: 0 });
```

## React Integration

### Dependency Injection (useApp)

Create a context-based hook to inject the app state. Track with `leaf`, provision app with `useApp`.

```typescript
import { createContext, useContext } from "react";

const AppContext = createContext<App>(emptyApp);
export const useApp = () => {
  return useContext(AppContext);
};
```

### Avoid Over-Destructuring

Do not destructure all state variables at the top of a component, as it defeats granular tracking by reading everything immediately.

```typescript
// ❌ BAD: Reads `total` immediately, defeating conditional tracking
const { cart: { total } } = useApp();

// ✅ GOOD: Read properties only when needed in the JSX
const { cart } = useApp();
return <div>{cart.total}</div>;
```

## Generation Rules for AI

- Prefer `carve` for feature boundaries.
- Keep `carve` declarative and short.
- Use arrow functions for helper logic.
- Helpers wired through `derived` must accept `self`.
- Use `source` for async query/re-query flows.
- Explain `set` as imperative emission and `previous` as last emitted value.

