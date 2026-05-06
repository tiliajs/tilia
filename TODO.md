# TiliaJS Architecture Updates: Reactive Queries & Lifecycles

## 1. `@tilia/query`: The LRU & Lifecycle Pattern

The query engine manages caching outside the reactive graph using an autonomous background interval ("Tick") and Observer Counting.

- **API Layering:** `@tilia/query` is intentionally low-level. It may expose signals and loadables internally to integrate with Tilia, but it is meant to be used inside carved features. A feature should lift query helpers such as `byId` and expose plain domain-shaped data, e.g. `dict<'a>`, without leaking reactive signal machinery through the feature API.
- **Core Assumption:** Tilia core observer cleanup now back-propagates through `computed`, `source`, and `store`, so query nodes can rely on reaching `0` observers when no view is actively reading them.
- **Garbage Collection (Timestamp/LRU):** During the Tick, the Query Manager inspects active queries. If a query has `0` observers, it is marked with a `lastUnobservedAt` timestamp. If it remains unobserved beyond the `gcTime` threshold, the query and its unreferenced entities are safely purged from RAM.
- **Object Purge Guard:** Do not purge any object that is still referenced by an unpurged query. Before removing an object from RAM, collect the ids from all live queries and keep any object id still present in that live id set.
- **Stale-While-Revalidate (SWR):** If a query has active observers (`count > 0`), the Tick checks its `lastFetched` age against the `staleTime`. If stale, it triggers a background network fetch without disrupting the UI state.

> **Footnote: Real-Time Invalidation Hook**
> The query architecture must include an explicit hook/method (e.g., `queryRepo.invalidate(hash)`). This is critical for real-time systems (WebSockets/SSE) to manually mark a query as stale or evict it upon receiving a push event, bypassing the standard Tick schedule to force an immediate reactive refresh.

## 2. Documentation Updates

**Action Required:** Update the official documentation to formally deprecate the "intentional state" pattern utilizing `watch/changes` for remote data fetching, directing users to the `@tilia/query` model instead.

- **AI Architectural View:** In my view, deprecating the `watch/changes` pattern for network synchronization is the absolute right move. Mixing asynchronous network lifecycles directly into synchronous reactive views often leads to fragile code; pushing that complexity into a dedicated, normalized Query Manager provides a strictly deterministic mental model that is vastly superior for both human developers and AI-driven code generation.

---

## Appendix: Observing State Field Reference

This documents the fields used to save observing state, including in `computed`, to understand the back-propagation pattern.

### Core Types (from `tilia/src/Tilia.res`)

#### `observer` — the actor that watches for changes

| Field | Type | Purpose |
|---|---|---|
| `root` | `root` | The scheduler root this observer belongs to (shared across a forest). |
| `notify` | `unit => unit` | Callback invoked by `flush` when a dependency changed. |
| `observing` | `array<watchers>` | List of `watchers` this observer wants to register itself into during `_ready`. |

#### `watchers` — per-key tracking node

| Field | Type | Purpose |
|---|---|---|
| `state` | `state` (`Pristine`/`Changed`/`Cleared`) | The lifecycle state of this watcher. |
| `key` | `string` | The property name of the parent object this watcher tracks (e.g. `"name"`, `"city"`). |
| `observed` | `dict<watchers>` | Back-reference to the parent object's `observed` map that owns this watcher. |
| `observers` | `Set.t<observer>` | **The important set** — all observers currently subscribed to changes on this key. `Set.size(w.observers)` gives the observer count. |
| `computes` | `dict<bool => unit>` | Per-key clear callbacks used to prune cold computed dependencies. |

#### `root` — the scheduler state shared by all proxies in a forest

| Field | Type | Purpose |
|---|---|---|
| `observer` | `nullable<observer>` | **The active tracking context.** Set by `_observe`, unset by `_done`/`_ready`/`_clear`. When non-null, Proxy `get` traps push watchers into it. |
| `expired` | `Set.t<observer>` | Observers that have been cleared and are waiting for their `notify()` callback to fire during the next `flush`. |
| `lock` | `bool` | `true` during `batch()` — defers `flush` until the batch ends. |

#### `meta` — per-proxy state (one per `tilia()` call)

| Field | Type | Purpose |
|---|---|---|
| `target` | `'a` | The raw JS object (not the Proxy). Used for identity comparison. |
| `root` | `root` | The scheduler for this proxy. |
| **`observed`** | **`dict<watchers>`** | **The key map.** Each key that has been read while tracking gets a `watchers` entry here. `meta.observed["value"].observers` is how you inspect observer counts. |
| `proxied` | `dict<meta<'a>>` | Cache of nested child proxies, keyed by property name. |
| `computes` | `dict<bool => unit>` | Per-key teardown callbacks for installed `computed` values. The boolean controls whether the cached slot is reset. |

### The `observeKey` function — creating watchers on first access

When a Proxy `get` trap fires with an active `root.observer`:

```rescript
switch node.root.observer {
| Value(o) =>
  if isArray && key == "length" {
    let w = observeKey(node.observed, indexKey, node.computes)
    Array.push(o.observing, w)
  } else {
    let w = observeKey(node.observed, key, node.computes)
    Array.push(o.observing, w)
  }
| _ => ()
}
```

A `watchers` struct is created in `node.observed[key]` and pushed into `o.observing[]`. Later `_ready(o)` iterates `o.observing` and does `Set.add(w.observers, o)` — registering the observer in the watcher's set.

### Test-file mirrored types (for `getMeta` introspection)

The test file in `tilia/test/Tilia_test.res` mirrors a subset of these types:

```rescript
type watchers = {
  key: string,
  observers: Set.t<Tilia.observer>,
}

type root = {
  observer: nullable<Tilia.observer>,
  lock: bool,
}

type rec meta<'a> = {
  target: 'a,
  observed: Map.t<string, watchers>,
  proxied: 'b. Map.t<string, meta<'b>>,
  computes: 'b. Map.t<string, bool => unit>,
  proxy: 'a,
  root: root,
}
```

**Important constraint:** ReScript requires a declared record type for field names to resolve. The test's `meta` uses `Map.t<string, watchers>` (a JS `Map`), matching the real `dict<watchers>` which is also a `Map`. When writing test records like `{label: "hello"}`, declare a corresponding type first (e.g. `type domino = {label: string}`) so ReScript knows how to type the literal. Without the declaration, untyped record fields produce a "no corresponding record type is in scope" error.
