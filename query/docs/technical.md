# TiliaQuery Technical Overview

## Purpose And Boundary

TiliaQuery is a small offline-first query-state layer for collections in Tilia applications.

It solves:
- shared caching of fetched objects
- query-level loading state
- offline-first reads through an optional local store tier
- a durable write outbox (dirty rows replayed across sessions)
- stale refresh behavior
- idle-query garbage collection
- object-driven invalidation from writes and live updates

It does **not** solve:
- transport concerns (HTTP, websocket, auth)
- storage concerns (IndexedDB/Dexie schemas, query glue)
- domain-specific query APIs (should be wrapped per feature)
- scheduler ownership (the app calls `tick()`)

## Current Public API

From `query/src/TiliaQuery.resi`:

```rescript
module Channel = {
  type state = Live | Cancelled
  type t<'a, 'issue> = {
    state: state,
    emit: 'a => unit,
    fail: 'issue => unit,
  }
}

type upsertIssue<'a> =
  | Offline
  | Conflict('a)
  | Rejected(string)

type remote<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  upsert: ('a, Channel.t<'a, upsertIssue<'a>>) => unit,
}

type store<'a, 'query> = {
  fetch: ('query, Channel.t<array<'a>, string>) => option<unit => unit>,
  save: ('a, bool) => unit,
  dirty: unit => promise<array<'a>>,
}

type t<'a, 'query> = {
  get: string => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: 'a => unit,
  sync: 'a => unit,
  tick: unit => unit,
}
```

Factory shape:

```rescript
let make: (
  ~id: 'a => string,
  ~remote: remote<'a, 'query>,
  ~local: store<'a, 'query>=?,
  ~stale: float=?,
  ~gc: float=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~invalidates: ('query, 'a) => bool=?,
  unit,
) => t<'a, 'query>
```

`remote` must be a tilia object (or contain a computed `online`): the core
watches `remote.online` reactively, and a plain record will never trigger
reconnect replay.

`local` is optional. Without it the core is purely in-memory. With it, the
core becomes offline-first: local answers every query and holds the durable
write outbox.

## Internal Model

In `query/src/TiliaQuery.res`, runtime state is built around:
- `cache`: object cache by id
- `queries`: loadable arrays of ids by query key
- `arrays` / `dicts`: memoized views per query key (computed; same proxy until the id list changes)
- `meta`: query metadata (filter, fetched timestamp, idle timestamp)
- `stale`: query keys marked for reload
- `upsert entries`: pending and in-flight writes keyed by object id

Keys are generated from query filters with `Json.sortedStringify` by default, so equivalent object filters map to the same cache key.

## Data Flow

### 1) Query read (`array` / `dict`) — two tiers

When first accessed:
1. build query key
2. store query metadata
3. mark query stale
4. create `Tilia.source(Loading, loader(...))`
5. loader runs `startFetch`, which always calls `local.fetch(query, channel)` and, only when `remote.online`, also calls `remote.fetch(query, channel)`
6. each tier pushes rows with `channel.emit(rows)` or failure with `channel.fail(message)`

A query opened offline resolves from the local store instead of hanging in `Loading`.

After each `emit(rows)`:
- objects are written to `cache`, **except** ids with a pending upsert (the optimistic value wins until the write settles)
- remote rows are additionally written through to `local.save(row, false)` (same pending-id exception)
- query result stores ids only; loadable state becomes `Loaded(ids)`
- remote emits (and remote `fail`) refresh `fetched`; local emits do not

Remote is authoritative because its emit lands after local. Adapters must
ensure `local.fetch` reflects prior `local.save` calls in order (IndexedDB
transactions or Dexie liveQuery give this naturally).

If channel state becomes `Cancelled`, `emit/fail` are no-op and late callbacks are ignored.
Transport may check `channel.state` proactively, but cancellation safety is enforced inside channel handlers.

### 2) Local write (`upsert`) — durable outbox

`upsert(item)`:
1. stores/replaces the pending entry by id (latest write wins per id)
2. saves the row dirty: `local.save(item, true)` — even offline; this is what makes writes durable
3. updates the object cache and runs the invalidation predicate
4. if `remote.online`, sends the write through `remote.upsert(item, channel)`
5. if offline, the entry stays queued for reconnect replay

`remote.upsert` is push-and-forget: it returns nothing and once a write is handed
to the transport it cannot be uncommitted. Cancelling the upsert channel is the
only disposal mechanism (late `emit`/`fail` become no-ops). Only fetch contracts
return a cleanup, since live subscriptions need teardown on query GC.

Write settlement (dirty lifecycle):

| Response | Entry | Local store |
| --- | --- | --- |
| `emit(saved)` | removed | `save(saved, false)` |
| `fail(Conflict(server))` | removed, server resolved into cache | `save(server, false)` |
| `fail(Rejected(_))` | removed | `save(value, false)` — stops boot retries; a later fetch restores server truth |
| `fail(Offline)` | kept queued for next reconnect | stays dirty |

### 2b) Boot replay

At `make`, the core loads `local.dirty()` (async) and feeds each row through
the normal upsert queue: optimistic cache, invalidation, and replay-when-online
all apply. Closing the app with unsynced writes and reopening it resumes the
sync where it left off.

### 3) Live/inbound update (`sync`)

`sync(item)`:
1. writes item to the memory cache using `id(item)`
2. runs the same invalidation logic
3. does **not** call remote `upsert` and does **not** touch the local store

This is intended for websocket events, delta-sync engines, or external state
pushes. A delta engine writes its changes to the local database itself, then
calls `sync(item)` per change; `local.save` is reserved for the core's own
write-through and outbox.

### 4) Reconnect ownership

Connectivity ownership lives in the core:
- `TiliaQuery` watches `remote.online`
- on `false -> true`, it marks live queries stale (re-running both tiers) and replays queued upsert entries
- on `true -> false`, active upsert channels are cancelled but entries are retained

Replay sends each queued entry once per reconnect; an entry that fails with
`Offline` stays queued for the next reconnect.

### 5) Lifecycle (`tick`)

`tick()` uses `Tilia._canopy(queries)` to split query keys:
- `live`: watched now
- `idle`: not currently watched

Then:
- live stale check: only while `remote.online`, if `now - fetched >= stale`, mark stale (an offline app does not re-read local every tick; reconnect replay refreshes instead)
- idle cleanup: if `now - idle >= gc`, evict query metadata, stale flag, and memoized views
- cancel cleanup callback for evicted active fetch channels
- post-eviction object purge: remove objects no longer referenced by remaining queries

## Usage Pattern

Recommended structure:
1. Build one query adapter per feature/domain.
2. Keep transport in service modules.
3. Expose domain-shaped helpers to app code.
4. Pass `invalidates` that expresses domain match rules between query filters and changed objects.

Tests in `query/test/TiliaQuery.feature` and `query/test/TiliaQueryTestHelpers.res` show this pattern with `Papabase` as an adapter example.

## Writing Adapters

The read contract is symmetric: `store.fetch` has the exact shape of
`remote.fetch`. Every `'query` value the app generates must be interpretable
by **both** sides — the local glue (e.g. Dexie where-clauses) and the remote
glue (e.g. Supabase filters). Either implement the interpretation twice or
share a query parser between the two adapters.

Dexie store sketch:

```typescript
const local = {
  fetch(filter, channel) {
    db.items.where(filter).toArray().then((rows) => channel.emit(rows));
    return undefined; // or a liveQuery unsubscribe
  },
  save(item, dirty) {
    db.items.put({ ...item, dirty: dirty ? 1 : 0 });
  },
  dirty: () => db.items.where("dirty").equals(1).toArray(),
};
```

Remote sketch (network signal must be reactive):

```typescript
const network = tilia({ online: navigator.onLine });
window.addEventListener("online", () => (network.online = true));
window.addEventListener("offline", () => (network.online = false));

const remote = tilia({
  online: computed(() => network.online),
  fetch(filter, channel) {
    api.list(filter).then((rows) => channel.emit(rows), (e) => channel.fail(String(e)));
    return undefined;
  },
  upsert(item, channel) {
    api.save(item).then(
      (saved) => channel.emit(saved),
      (e) => channel.fail(classify(e)), // 409 -> Conflict(server), 4xx -> Rejected, network -> Offline
    );
  },
});
```

## Delta-Sync Compatibility

The intended end state for most apps is a delta-sync engine (outside
TiliaQuery) that pulls access-scoped changes since a cursor and keeps the
local store complete; local queries become authoritative and the per-query
remote fetch is the fallback for heavy or uncovered datasets. This maps onto
the contracts as-is:
- inbound deltas: the engine writes the local database, then calls `sync(item)` per change
- covered queries: the remote adapter answers `channel.fail("covered")` without fetching — the core treats this as fresh (sets `fetched`, clears stale, keeps data)
- uncovered/partial queries: normal `remote.fetch` fallback with write-through; the adapter records new coverage
- outbound: the dirty outbox plus `remote.upsert` is the delta push side

## Current Shortcomings And Open Problems

- **Singleton and detail-style resources:** current model is list/query-key centric; singleton entities may need clearer first-class patterns.
- **Invalidation cost:** invalidation scans all stored query metadata; this is simple but can become expensive with many active filters.
- **Write observability:** rejected writes are dropped silently; there is no pending-writes or sync-status surface for UI.
- **Pagination/windowing:** current docs and API focus on full query-result arrays, not advanced page/window cache strategies.
- **Cross-query consistency rules:** complex relationships (derived aggregates, graph-like joins) still rely on feature-layer logic.
- **No TS docs/types package narrative yet:** types and onboarding guidance are still incomplete in user-facing docs.

## What This Should Enable

A contributor should be able to:
- understand where to add behavior (`make`, loader, invalidation, `tick`)
- reason about freshness and GC behavior
- add feature adapters safely
- identify which gaps are accepted for now versus next-step roadmap work
