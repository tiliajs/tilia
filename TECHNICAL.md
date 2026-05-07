# Technical Notes

## Tilia Observer Internals

This summarizes the observer state used by `tilia/src/Tilia.res` and relied on by `@tilia/query`.

### Core Types

`observer`

| Field | Type | Purpose |
|---|---|---|
| `root` | `root` | Scheduler root shared by a reactive forest. |
| `notify` | `unit => unit` | Callback invoked when a dependency changes. |
| `observing` | `array<watchers>` | Watcher nodes captured during a tracked read. |

`watchers`

| Field | Type | Purpose |
|---|---|---|
| `state` | `Pristine` / `Changed` / `Cleared` | Watcher lifecycle. |
| `key` | `string` | Observed property key. |
| `observed` | `dict<watchers>` | Parent observed-key map. |
| `observers` | `Set.t<observer>` | Active observers for this key. |
| `computes` | `dict<bool => unit>` | Clear callbacks for computed values. |

`root`

| Field | Type | Purpose |
|---|---|---|
| `observer` | `nullable<observer>` | Current tracking context. |
| `expired` | `Set.t<observer>` | Observers waiting to notify. |
| `lock` | `bool` | Defers flush while batching. |

`meta`

| Field | Type | Purpose |
|---|---|---|
| `target` | `'a` | Raw JS object behind the proxy. |
| `root` | `root` | Scheduler root for the proxy. |
| `observed` | `dict<watchers>` | Key map used to inspect live vs idle keys. |
| `proxied` | `dict<meta<'a>>` | Nested proxy cache. |
| `computes` | `dict<bool => unit>` | Computed cleanup callbacks. |

### Observing Flow

When a proxy key is read during tracking, `observeKey` creates or reuses a watcher for that key and pushes it into `observer.observing`. Later `_ready(observer, ...)` subscribes the observer by adding it to each watcher’s `observers` set.

`Tilia._canopy(proxy)` flushes pending observer changes and returns:

- `live`: keys with at least one active observer.
- `idle`: keys without active observers.

`@tilia/query` relies on `_canopy(queries)` to classify all query keys in one pass during `tick()`.

### Test Introspection

Tests that inspect `_meta` need matching record declarations in the test file. ReScript requires record field names to be in scope before record literals or field access can type-check.
