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

- **Tracking rule:** Never use `async` in the `setup` function. Tilia tracks reactive reads during synchronous execution of `setup` only. Tracking ONLY HAPPENS INSIDE A CALLBACK. Read dependencies synchronously, then delegate async work.
- `initial` is returned before first `set`.
- `setup(previous, set)` runs on first read.
- `setup(previous, set)` runs again when tracked dependencies in setup change.
- `set(next)` imperatively publishes a new value.
- `previous` is the latest emitted value, useful for incremental updates.
- `previous` also supports stale-while-revalidate UI (keep old data visible, e.g. greyed out, while reloading to avoid blinking).

```typescript
import { carve, source } from "tilia";

const sleep = () => new Promise((resolve) => setTimeout(resolve, 10));

type User = { query: string; name: string };

const fetchName = (self: User) => (previous: string, set: (value: string) => void): void => {
  // 1. Synchronous read (tracked)
  const q = self.query;

  // 2. Delegate async work
  sleep().then(() => {
    if (q === "helena") set("Helena");
    else if (q === "bob") set("William");
    else set(`${previous}+${q}`);
  });
};

const user = carve<User>(({ derived }) => ({
  query: "helena",
  name: source("Loading", derived(fetchName)),
}));

// Re-query
user.query = "bob";
```

#### `source` + `derived` inside `carve` (conditional loader strategy)

```typescript
const loader =
  (service: Service) =>
  (self: { projectId: string }) =>
  (previous: Project, set: (value: Project) => void) => {
    // 1. Synchronous read (tracked)
    const id = self.projectId;
    set(stale(previous));
    
    // 2. Delegate async work
    service.loadProject(id).then((project) => {
      set(loaded(project));
    });
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

#### Loading state sentinel pattern

To represent a "loading" state, use an empty tilia object as a sentinel. Use `===` identity comparison to distinguish "loading" from "loaded but empty."

```typescript
const loading = tilia({});
const repo = carve(({ derived }) => ({
  data: source(loading, derived(loader(service))),
}));
if (repo.data === loading) { /* still loading */ }
```

### `store`

Managed value with setup that returns current state and receives setter.

```typescript
import { tilia, store } from "tilia";
type Auth = { t: "LoggedOut" } | { t: "LoggedIn" };
const auth = (set: (next: Auth) => void): Auth => ({ t: "LoggedOut" });
const app = tilia({ auth: store(auth) });
```

### `changing` (write tracking for sync connectors)

Track key-level writes on a tilia-proxied dict. Takes an accessor `() => Record<string, T>` so the tracker can follow source swaps. Returns `{ changes, mute }`: `changes` drains accumulated changes into `{ upsert, remove }` when read by `watch`; `mute` runs a callback with tracking suppressed. `upsert` contains objects captured at write time. `remove` contains keys of deleted entries. Last write wins per key. Each call creates an independent accumulator.

- `changing(() => data)` -- returns `{ changes, mute }`. `changes` drains accumulated changes as `{ upsert: T[], remove: string[] }`. `mute(fn)` runs `fn` without tracking (for inbound writes).
- `changing(() => data, guard)` -- optional reactive guard function. When guard returns false, changes accumulate silently. When guard flips to true, all accumulated changes drain and the effect fires.

```typescript
import { tilia, watch, changing } from "tilia";

type Item = { id: string; name: string; quantity: number };
type SyncService = {
  upsert: (items: Item[]) => void;
  remove: (ids: string[]) => void;
};
type LocalDb = {
  upsert: (items: Item[]) => void;
  remove: (ids: string[]) => void;
};
type Actor = { online: boolean };

const makeItemsRepo = (service: SyncService, localDb: LocalDb, actor: Actor) => {
  const data = tilia<Record<string, Item>>({});

  // Local DB: always sync
  const { changes } = changing(() => data);
  watch(changes, ({ upsert, remove }) => {
    localDb.upsert(upsert);
    localDb.remove(remove);
  });

  // Remote: sync only when online
  const remote = changing(() => data, () => actor.online);
  watch(remote.changes, ({ upsert, remove }) => {
    service.upsert(upsert);
    service.remove(remove);
  });

  // Inbound: apply remote data without triggering outbound sync
  // remote.mute(() => Object.assign(data, remoteData));

  return data;
};
```

Multiple repos use the same pattern:

```typescript
const settings = changing(() => settingsRepo.data, () => actor.online);
watch(settings.changes, ({ upsert, remove }) => {
  settingsService.upsert(upsert);
  settingsService.remove(remove);
});
```

Architectural summary:
- `source` handles inbound (loading from external into reactive data)
- `changing` + `watch` handles outbound (pushing reactive writes to external)
- `changes` returns `{ upsert, remove }` — upsert contains objects captured at write time, remove contains keys of deleted entries
- `mute` prevents feedback loops: inbound writes are reactive but not tracked
- The guard parameter leverages tilia's natural tracking for offline accumulation
- The accessor pattern `() => data` lets the tracker follow source swaps automatically

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
- Use `changing(() => data)` + `watch` for outbound sync connectors (persistence, remote sync). Destructure `{ changes, mute }`.
- `changes` returns `{ upsert, remove }` — upsert contains objects, remove contains keys. Use the accessor pattern so the tracker follows source swaps.
- Use `mute` for inbound writes to prevent feedback loops in bidirectional sync.
- `source` = inbound, `changing` = outbound.

