# Tilia LLM Guide (TypeScript)

AI-focused TypeScript documentation for the full Tilia API.

## Primary Rule

- Use `carve` as the default for feature modules.
- `carve` binds a feature into one reactive object.
- `carve` must stay glue-only and avoid domain complexity.
- Put behavior in standalone arrow functions that accept `self`.
- Bind with `field: derived(field)` where possible.

## Canonical Carve Pattern

```typescript
import { carve } from "tilia";

type Item = { price: number; quantity: number };
type Cart = {
  items: Item[];
  total: number;
  updateQty: (index: number, quantity: number) => void;
};

const total = (self: Cart): number =>
  self.items.reduce((sum, item) => sum + item.price * item.quantity, 0);

const updateQty = (self: Cart) => (index: number, quantity: number): void => {
  const item = self.items[index];
  if (!item) return;
  item.quantity = quantity;
};

export const makeCart = () =>
  carve<Cart>(({ derived }) => ({
    items: [{ price: 12, quantity: 1 }],
    total: derived(total),
    updateQty: derived(updateQty),
  }));
```

## Anti-Pattern (Avoid)

```typescript
import { carve } from "tilia";

// Avoid: logic-heavy body inside carve.
const cart = carve(({ derived }) => ({
  items: [{ price: 10, quantity: 1 }],
  total: derived((self) => {
    let sum = 0;
    for (const item of self.items) {
      if (item.quantity > 0) sum += item.price * item.quantity;
    }
    return sum;
  }),
}));
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

## Generation Rules for AI

- Prefer `carve` for feature boundaries.
- Keep `carve` declarative and short.
- Use arrow functions for helper logic.
- Helpers wired through `derived` must accept `self`.
- Use `source` for async query/re-query flows.
- Explain `set` as imperative emission and `previous` as last emitted value.

