# @tilia/query

Offline-first queries and optimistic writes for [Tilia](https://tiliajs.dev)
apps.

The query engine owns reactive in-memory results, freshness, and query
lifetime. A store supplies those results and owns persistence and
synchronization. The shipped `Store.make` is the normal starting point: give
it `find`, `upsert`, and `remove`, and it provides a write-through cache,
ordered outbox, conflict handling, and local retention.

> Status: `0.1.0`, API stabilizing. The authoritative contracts are
> [`src/index.d.ts`](src/index.d.ts) and
> [`src/TiliaQuery.resi`](src/TiliaQuery.resi). The IndexedDB export is
> described by [`src/indexeddb.d.ts`](src/indexeddb.d.ts).

## Install

```sh
pnpm add @tilia/query tilia
```

The package exports:

- `@tilia/query` — `make`, `Store`, types, and `sortedStringify`
- `@tilia/query/indexeddb` — an IndexedDB-backed `Kv`

## Quick start

```typescript
import { Store, make, type Loadable } from "@tilia/query";
import { make as indexedDb } from "@tilia/query/indexeddb";

type Todo = {
  id: string;
  title: string;
  done: boolean;
  version: number;
};

type TodoQuery = { done?: boolean };

declare const backend: {
  find(query: TodoQuery): Promise<Todo[]>;
  upsert(
    value: Todo
  ): Promise<
    | { outcome: "saved"; value: Todo }
    | { outcome: "conflict"; value: Todo }
    | { outcome: "rejected"; message: string }
  >;
  remove(
    id: string
  ): Promise<"removed" | { outcome: "rejected"; message: string }>;
};

const persist = indexedDb({
  name: "todos",
  onError: (error) => console.error("IndexedDB", error),
});

const [query, store] = make<Todo, TodoQuery, Store<Todo>>({
  id: (todo) => todo.id,
  matches: (filter, todo) => filter.done === undefined || filter.done === todo.done,
  sort: () => (todos) => [...todos].sort((a, b) => a.title.localeCompare(b.title)),
  store: Store.make<Todo, TodoQuery>({
    persist,
    find(filter, answer) {
      backend.find(filter).then(answer.fresh, (error) => answer.fail(String(error)));
    },
    upsert(todo, reply) {
      backend.upsert(todo).then(reply, () => reply("transient"));
    },
    remove(id, reply) {
      backend.remove(id).then(reply, () => reply("transient"));
    },
  }),
  onError: (filter, message) => {
    console.error("Could not refresh", filter, message);
  },
});
```

`make` returns two connected values:

- `query` reads reactive query results and owns `tick()` and `dispose()`.
- `store` performs writes and exposes synchronization state.

Queries must be plain data. `matches(query, value)` must decide membership
from one row, and `find` must answer with the complete result set. Pagination,
limits, and aggregates do not fit this result model.

`Store.make` uses `Store.online()` unless `online` is supplied. In a browser
that shared signal follows the browser's online/offline events; in an
environment without those events it is online.

## Read results

`query.array(filter)` and `query.one(filter)` return a `Loadable`. Render
loaded data regardless of its claim:

```typescript
function renderTodos(result: Loadable<Todo[]>) {
  if (result === "loading") {
    return renderSpinner();
  }

  if (result.state === "noData") {
    if (result.reason === "offline") {
      return renderOffline();
    }
    if (result.reason.reason === "failed") {
      return renderError(result.reason.message);
    }
    return renderEmpty(); // `noMatch` is produced by `one`, not `array`
  }

  renderList(result.data);

  if (result.claim === "partial") showIncomplete();
  if (result.claim === "local") showCached();
}
```

Claims describe answer strength:

- `"partial"` — locally held matching rows, without proof that they are the
  complete answer
- `"local"` — a complete stored answer
- `"fresh"` — an authoritative answer as of now

A non-empty partial answer is useful data and should normally be rendered.
An empty partial answer is not proof of an empty query: it stays `"loading"`
while an online answer is possible and becomes `{ state: "noData", reason:
"offline" }` offline.

For `array`, a complete empty answer is loaded data:

```typescript
{ state: "loaded", claim: "fresh", data: [] }
```

Only `one` projects a complete empty result to `noMatch`, preserving the
answer's claim:

```typescript
const todo = query.one({ done: false });

if (
  typeof todo === "object" &&
  todo.state === "noData" &&
  todo.reason !== "offline" &&
  todo.reason.reason === "noMatch"
) {
  renderMissing(todo.reason.claim);
}
```

A weaker result never replaces a stronger one. For example, a late local
answer cannot overwrite a fresh answer. `tick()` is the only operation that
lowers a claim: an expired `"fresh"` result becomes `"local"` while its data
remains visible.

If the first find fails with no data to retain, the read site receives
`{ state: "noData", reason: { reason: "failed", message } }`. If data is
already visible, it stays visible and `onError(query, message)` is called
instead.

## Writes and synchronization

Writes go through the returned store:

```typescript
store.upsert({ id: "t1", title: "Ship it", done: false, version: 0 });
store.remove("t1");
```

They update memory and persistence immediately, update membership in every
in-memory query through `matches`, and append to the outbox. While online,
`Store.make` sends outbox operations one at a time in order:

- `{ outcome: "saved", value }` confirms an upsert with the authoritative
  value.
- `"removed"` confirms a remove.
- `{ outcome: "conflict", value }` supplies the backend's current row. The
  store rebases through `merge` and leaves the operation pending for another
  heartbeat; if it cannot merge, remote truth wins and a rejection is
  recorded.
- `{ outcome: "rejected", message }` definitively refuses that one operation.
- `"transient"` says nothing about the operation, stops the sequence, and
  leaves it and all later operations pending for a later `tick()` or
  reconnect.

Backends must preserve client ids. Confirmations and conflicts are matched to
upserts by `id(value)`.

`status` is reactive:

```typescript
store.status.pending;  // operations still in the outbox
store.status.rejected; // refused conflict/failure snapshots
```

Remote truth is already visible when a rejection is presented. A rejection
is history, not an active overlay. Resolve each exact record by retrying its
saved local work or discarding it:

```typescript
const rejection = store.status.rejected[0];
if (rejection) {
  store.retry(rejection);
  // or: store.discard(rejection);
}
```

`retry` reapplies a copy as a new optimistic write against the value that
stands now. `discard` only drops the context. Both are no-ops for a stale
record that has already been replaced or cleared. Writing to the same id also
clears its existing rejection.

## IndexedDB persistence

`@tilia/query/indexeddb` provides the `Kv` used in the quick start:

```typescript
import { make as indexedDb } from "@tilia/query/indexeddb";

const persist = indexedDb({
  name: "todos",
  store: "entries", // default
  version: 1,       // default
  onError: console.error,
});
```

It uses one object store with compound key `[tag, key]`. Rows, query records,
and outbox entries share that keyspace under separate tags. Writes are
batched into transactions, and reads flush queued writes first.

If `persist` is omitted, the same store runs over `Store.memory()`. That
keyspace survives only for the life of the process.

An IndexedDB open or transaction error is reported through its `onError`.
Because `Kv` is command-only, failed reads answer with nothing and failed
writes are dropped; decide at the application boundary whether to alert,
log, or disable offline behavior.

## Expiry and heartbeat

Expiry is intentionally split between the engine and the store:

```typescript
const [query, store] = make({
  // ...
  expiry: {
    refresh: 30_000, // engine: observed query freshness
    memory: 300_000, // engine: unobserved query eviction
  },
  store: Store.make({
    // ...
    expiry: {
      local: 30 * 24 * 60 * 60 * 1000, // store: persisted retention
    },
  }),
});
```

These are the defaults. The engine owns no timer, so call `tick()` at least
twice per refresh interval:

```typescript
const timer = setInterval(query.tick, 15_000);

function stop() {
  clearInterval(timer);
  query.dispose();
}
```

`tick()` refreshes observed non-live queries, ages fresh claims, evicts
unobserved in-memory queries, asks the store to retry transient writes, and
lets the store run local purge. `dispose()` closes open finds, runs their
registered teardowns, stops connectivity watching, and disposes the store.

## Advanced: channel-backed stores

Use `Store.custom` when a backend needs the lower-level channel protocol,
especially when it pushes query snapshots or inbound row facts:

```typescript
const [query, store] = make<Todo, TodoQuery, Store<Todo>>({
  id: (todo) => todo.id,
  matches: (filter, todo) => filter.done === undefined || filter.done === todo.done,
  store: Store.custom({
    remote, // app-owned ReadChannel/WriteChannel adaptor
    persist,
    merge,
  }),
});

store.receive.changed([pushedTodo]);
store.receive.removed(["t2"]);
```

Its remote can publish `fresh` or self-maintained `live` snapshots, register
a teardown, answer batched writes per operation, and push row facts through
the returned store. See [TECHNICAL.md](TECHNICAL.md) for the complete channel
ordering, lifecycle, and reconciliation rules.

`lookup` is another advanced store option. It may answer an unregistered
query with `partial(values)`, or with `local(values)` only when an application
index can certify that the rows are the complete answer.

## Configuration reference

Engine:

```typescript
make({ id, matches, store, expiry?, now?, key?, sort?, onError? })
```

- `key` defaults to `sortedStringify`, deterministic JSON with sorted object
  keys.
- `sort(query)(values)` orders a complete result. It runs reactively, so
  changing a sort field reorders the list.
- `now` defaults to `Date.now`.

Shipped store:

```typescript
Store.make({
  find,
  upsert,
  remove,
  online?,
  persist?,
  lookup?,
  merge?,
  expiry?,
})
```

Queries, and values used by the shipped store, must survive a JSON round trip
unchanged. Use plain data: no functions, cycles, class identity,
`null`/`undefined` rows or queries, or backend-assigned replacement ids.

## Going further

- [TECHNICAL.md](TECHNICAL.md) — engine/store boundary, claims, outbox,
  rejections, live sources, and purge
- [docs/vision.md](docs/vision.md) — intent and product direction
- [llms.txt](llms.txt) — compact contract guide for coding assistants
- [tiliajs.dev/query](https://tiliajs.dev/query) — published documentation

Debug hook: `query._canopy()` lists observed (`live`) and cached (`idle`)
query keys.

## Changelog

- 2026-09-26 **0.1.0**
  - First release: query engine with reactive results, freshness, and query
    lifetime.
  - `Store.make` with write-through cache, ordered outbox, conflict handling,
    and local retention.
  - `@tilia/query/indexeddb` for an IndexedDB-backed `Kv`.

## License

MIT
