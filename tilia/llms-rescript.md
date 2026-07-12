# Tilia LLM Guide (ReScript)

AI-focused ReScript documentation for the full Tilia API.

## Install

npm install tilia @tilia/react

## Primary Rule

- Use `carve` as the default for feature modules.
- `carve` must glue parts into one reactive object.
- Do not put business complexity inside `carve`.
- Put logic in standalone functions that take `self`.
- Bind with `field: derived(field)` when possible.

## Canonical Carve Pattern

```rescript
open Tilia

type feature = {
  mutable count: int,
  double: int,
  add: int => unit,
}

type service = {
  fetchCount: (int, int => unit) => unit,
  updateCount: (int, unit => unit) => unit,
}

let double = (self: feature) => self.count * 2

let add = (service: service) => (self: feature) => (count: int) => {
  let prevValue = self.count
  self.count += count // optimistic write
  service.updateCount(self.count, () => self.count = prevValue)
}

let makeFeature = service =>
  carve(({derived}) => {
    count: source(0, service.fetchCount),
    double: derived(double),
    add: derived(add(service)),
  })

let feature = makeFeature(service)
feature.add(4)
```

## Anti-Pattern (Avoid)

```rescript
open Tilia

// Avoid: logic-heavy body inside carve.
let cart = carve(({derived}) => {
  items: [{price: 10.0, quantity: 1}],
  total: derived(self => {
    let mutable sum = 0.0
    for i in 0 to Array.length(self.items) - 1 {
      switch self.items[i] {
      | Some(item) => sum = sum +. item.price *. Float.fromInt(item.quantity)
      | None => ()
      }
    }
    sum
  }),
})
```

## Feature File Organization

Use this if the project does not provide other guidelines.

```text
[feature-name]/
  index.res     // carve glue
  type.res      // type of the feature
  computed.res  // all computed/derived values
  actions.res   // all mutating functions
  service.res   // external dependencies (db fetch, etc)
```

## Full API Map (ReScript)

### `tilia`

Wrap an object/array into a reactive proxy.

```rescript
let state = tilia({count: 0})
state.count = 1
```

### `carve`

Create a reactive feature object with helper-function injection via `derived`.

```rescript
type feature = {value: int, doubled: int}
let doubled = (self: feature) => self.value * 2

let feature = carve(({derived}) => {
  value: 1,
  doubled: derived(doubled),
})
```

### `observe`

Push reactivity. Callback re-runs when tracked reads change.

```rescript
observe(() => Js.log(state.count))
```

### `watch`

Split tracking and effect.

```rescript
watch(
  () => state.count,
  v => Js.log(v),
)
```

### `batch`

Group writes and flush once.

```rescript
batch(() => {
  state.a = 1
  state.b = 2
})
```

### `signal`

Single mutable reactive value + setter.

```rescript
let (count, setCount) = signal(0)
setCount(2)
```

### `derived` (signal API)

Create a derived signal from signals or reactive reads.

```rescript
let (a, setA) = signal(1)
let b = derived(() => a.value * 2)
setA(2)
```

### `lift`

Insert signal value into a `tilia` object.

```rescript
let (s, setS) = signal(0)
let state = tilia({count: lift(s), setS})
```

### `readonly`

Insert non-tracked immutable data wrapper.

```rescript
let app = tilia({form: readonly(bigData)})
```

### `computed`

Pull reactivity. Re-computes on read after dependency invalidation.

```rescript
let state = tilia({
  count: 1,
  double: computed(() => state.count * 2),
})
```

### `source` (async query and re-query)

Use `source(initial, setup)` for async loaders and re-loaders.

- **Tracking rule:** Never use `async` in the `setup` function. Tilia tracks reactive reads during synchronous execution of `setup` only. Tracking ONLY HAPPENS INSIDE A CALLBACK. Read dependencies synchronously, then delegate async work.
- `initial` is returned until `set` is called.
- `setup(previous, set)` runs on first read.
- `setup(previous, set)` runs again when tracked dependencies inside setup change.
- `set(next)` updates the source value imperatively.
- `previous` is the last emitted value, useful for incremental updates.
- `previous` also supports stale-while-revalidate UI (keep old data visible, e.g. greyed out, while reloading to avoid blinking).

```rescript
open Tilia

let sleep: unit => promise<unit> = async () =>
  %raw(`new Promise(resolve => setTimeout(resolve, 10))`)

let fetchName = self => (previous, set) => {
  // 1. Synchronous read (tracked)
  let q = self.query

  // 2. Delegate async work
  let _ = sleep()->Promise.thenResolve(() => {
    switch q {
    | "helena" => set("Helena")
    | "bob" => set("William")
    | _ => set(previous ++ "+" ++ q)
    }
  })
}

let user = carve(({derived}) => {
  query: "helena",
  name: source("Loading", derived(fetchName)),
})

// Re-query
user.query = "bob"
```

#### `source` + `derived` inside `carve` (conditional loader strategy)

```rescript
open Tilia

let loader = service => self => (previous, set) => {
  // 1. Synchronous read (tracked)
  let id = self.projectId
  set(stale(previous))
  
  // 2. Delegate async work
  let _ = service.loadProject(id)->Promise.thenResolve(project => {
    set(loaded(project))
  })
}

let selectProject = self => id => self.projectId = id

let projectBranch = carve(({derived}) => {
  projectId: "main",
  project: source(empty(), derived(loader(service))),
  selectProject: derived(selectProject),
})
```

Use this when loading depends on feature fields (`self.projectId`) and keep `previous` to preserve old UI data until new values are ready.

#### Loading state sentinel pattern

To represent a "loading" state, use an empty tilia object as a sentinel. Use `===` identity comparison to distinguish "loading" from "loaded but empty."

```rescript
let loading = tilia(Dict.make())
let repo = carve(({derived}) => {
  data: source(loading, derived(loader(service))),
})
if repo.data === loading { /* still loading */ }
```

### `store`

Managed state with setup returning current value and receiving a setter.

```rescript
type auth = LoggedOut | Loading | LoggedIn

let machine = set => LoggedOut
let app = tilia({auth: store(machine)})
```

### `changing` (write tracking for sync connectors)

Track key-level writes on a tilia-proxied dict. Takes an accessor `() => dict<'a>` so the tracker can follow source swaps. Returns `{ changes, mute }`: `changes` drains accumulated changes into `{ upsert, remove }` when read by `watch`; `mute` runs a callback with tracking suppressed. `upsert` contains objects captured at write time. `remove` contains keys of deleted entries. Last write wins per key. Each call creates an independent accumulator.

- `changing(() => data)` -- returns `{ changes, mute }`. `changes` drains accumulated changes as `{ upsert: array<'a>, remove: array<string> }`. `mute(fn)` runs `fn` without tracking (for inbound writes).
- `changing(() => data, ~guard=() => expr)` -- optional reactive guard. When guard returns false, changes accumulate silently. When guard flips to true, all accumulated changes drain and the effect fires.

```rescript
open Tilia

type item = {id: string, name: string, quantity: int}
type syncService = {
  upsert: array<item> => unit,
  remove: array<string> => unit,
}
type localDb = {
  upsert: array<item> => unit,
  remove: array<string> => unit,
}
type actor = {mutable online: bool}

let makeItemsRepo = (service: syncService, localDb: localDb, actor: actor) => {
  let data: dict<item> = tilia(Dict.make())

  // Local DB: always sync
  let {changes} = changing(() => data)
  watch(changes, ({upsert, remove}) => {
    localDb.upsert(upsert)
    localDb.remove(remove)
  })

  // Remote: sync only when online
  let remote = changing(() => data, ~guard=() => actor.online)
  watch(remote.changes, ({upsert, remove}) => {
    service.upsert(upsert)
    service.remove(remove)
  })

  // Inbound: apply remote data without triggering outbound sync
  // remote.mute(() => Dict.assign(data, remoteData))

  data
}
```

Multiple repos use the same pattern:

```rescript
let settings = changing(() => settingsRepo.data, ~guard=() => actor.online)
watch(settings.changes, ({upsert, remove}) => {
  settingsService.upsert(upsert)
  settingsService.remove(remove)
})
```

Architectural summary:
- `source` handles inbound (loading from external into reactive data)
- `changing` + `watch` handles outbound (pushing reactive writes to external)
- `changes` returns `{ upsert, remove }` — upsert contains objects captured at write time, remove contains keys of deleted entries
- `mute` prevents feedback loops: inbound writes are reactive but not tracked
- The guard parameter leverages tilia's natural tracking for offline accumulation
- The accessor pattern `() => data` lets the tracker follow source swaps automatically

### `make`

Create isolated Tilia context (`tilia`, `carve`, `observe`, etc.).

```rescript
let ctx = make()
let local = ctx.tilia({count: 0})
```

## React Integration

### Dependency Injection (useApp)

Create a context-based hook to inject the app state. Track with `leaf`, provision app with `useApp`.

```rescript
let context = React.createContext(emptyApp)
let useApp = () => React.useContext(context)
```

### Avoid Over-Destructuring

Do not destructure all state variables at the top of a component, as it defeats granular tracking by reading everything immediately.

```rescript
// ❌ BAD: Reads `total` immediately, defeating conditional tracking
let {cart: {total}} = useApp()

// ✅ GOOD: Read properties only when needed in the JSX
let {cart} = useApp()
<div>{React.float(cart.total)}</div>
```

## Generation Rules for AI

- Prefer `carve` over ad-hoc `tilia` for feature modules.
- Keep `carve` declarative and short.
- Extract domain logic into external functions.
- Functions wired with `derived` take `self` first.
- Use `source` for async query/re-query flows.
- Explain `set` as imperative emitter and `previous` as last emitted value.
- Use `changing(() => data)` + `watch` for outbound sync connectors (persistence, remote sync). Destructure `{ changes, mute }`.
- `changes` returns `{ upsert, remove }` — upsert contains objects, remove contains keys. Use the accessor pattern so the tracker follows source swaps.
- Use `mute` for inbound writes to prevent feedback loops in bidirectional sync.
- `source` = inbound, `changing` = outbound.

