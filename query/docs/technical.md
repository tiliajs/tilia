# TiliaQuery Technical Overview

## Purpose And Boundary

TiliaQuery is a small query-state layer for remote collections in Tilia applications.

It solves:
- shared caching of fetched objects
- query-level loading state
- stale refresh behavior
- idle-query garbage collection
- object-driven invalidation from writes and live updates

It does **not** solve:
- transport concerns (HTTP, websocket, auth)
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
  upsert: ('a, Channel.t<'a, upsertIssue<'a>>) => option<unit => unit>,
}

type t<'a, 'query> = {
  get: string => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: 'a => option<unit => unit>,
  sync: 'a => unit,
  tick: unit => unit,
}
```

Factory shape:

```rescript
let make: (
  ~id: 'a => string,
  ~remote: remote<'a, 'query>,
  ~stale: float=?,
  ~gc: float=?,
  ~now: unit => float=?,
  ~key: 'query => string=?,
  ~invalidates: ('query, 'a) => bool=?,
  unit,
) => t<'a, 'query>
```

## Internal Model

In `query/src/TiliaQuery.res`, runtime state is built around:
- `cache`: object cache by id
- `queries`: loadable arrays of ids by query key
- `meta`: query metadata (filter, fetched timestamp, idle timestamp)
- `stale`: query keys marked for reload
- `upsert entries`: pending and in-flight writes keyed by object id

Keys are generated from query filters with `Json.sortedStringify` by default, so equivalent object filters map to the same cache key.

## Data Flow

### 1) Query read (`array` / `dict`) via channel emit/fail

When first accessed:
1. build query key
2. store query metadata
3. mark query stale
4. create `Tilia.source(Loading, loader(...))`
5. loader calls `fetch(query, channel)`
6. transport pushes rows with `channel.emit(rows)` or failure with `channel.fail(message)`

After each `emit(rows)`:
- objects are written to `cache`
- query result stores ids only
- loadable state becomes `Loaded(ids)`

On `fail(message)`, query freshness metadata is updated and stale flags are cleared for the current cycle (existing loaded data stays available).

If channel state becomes `Cancelled`, `emit/fail` are no-op and late callbacks are ignored.
Transport may check `channel.state` proactively, but cancellation safety is enforced inside channel handlers.

### 2) Local write (`upsert`)

`upsert(item)`:
1. updates local object cache immediately
2. runs invalidation predicate against cached query filters
3. marks matching queries stale
4. stores/replaces pending entry by id (latest write wins per id)
5. if `remote.online`, sends transport write through `remote.upsert(item, channel)`
6. if offline, entry remains queued for reconnect replay

Write issue handling:
- `Offline`: drop current entry
- `Conflict(serverObject)`: resolve into cache, then drop current entry
- `Rejected(message)`: drop current entry
- `emit(savedObject)`: resolve into cache and remove entry

### 3) Live/inbound update (`sync`)

`sync(item)`:
1. writes item to local cache using `id(item)`
2. runs the same invalidation logic
3. does **not** call remote `upsert`

This is intended for websocket events or external state pushes.

### 4) Reconnect ownership

Connectivity ownership lives in the core:
- `TiliaQuery` watches `remote.online`
- on `false -> true`, it triggers replay for both:
  - eligible fetch queries
  - queued upsert entries
- on `true -> false`, active upsert channels are cancelled but entries are retained

Replay sends each currently queued and idle upsert entry once; upsert channels are single-response and entries are removed on any response.

### 5) Lifecycle (`tick`)

`tick()` uses `Tilia._canopy(queries)` to split query keys:
- `live`: watched now
- `idle`: not currently watched

Then:
- live stale check: if `now - fetched >= stale`, mark stale
- idle cleanup: if `now - idle >= gc`, evict query metadata and stale flag
- cancel cleanup callback for evicted active fetch channel
- post-eviction object purge: remove objects no longer referenced by remaining queries

## Usage Pattern

Recommended structure:
1. Build one query adapter per feature/domain.
2. Keep transport in service modules.
3. Expose domain-shaped helpers to app code.
4. Pass `invalidates` that expresses domain match rules between query filters and changed objects.

Tests in `query/test/TiliaQuery.feature` and `query/test/TiliaQueryTestHelpers.res` show this pattern with `Papabase` as an adapter example.

## Current Shortcomings And Open Problems

- **Singleton and detail-style resources:** current model is list/query-key centric; singleton entities may need clearer first-class patterns.
- **Invalidation cost:** invalidation scans all stored query metadata; this is simple but can become expensive with many active filters.
- **Conflict handling:** optimistic/local updates and later remote fetch results can overwrite each other without explicit merge policy.
- **Pagination/windowing:** current docs and API focus on full query-result arrays, not advanced page/window cache strategies.
- **Cross-query consistency rules:** complex relationships (derived aggregates, graph-like joins) still rely on feature-layer logic.
- **No TS docs/types package narrative yet:** types and onboarding guidance are still incomplete in user-facing docs.

## What This Should Enable

A contributor should be able to:
- understand where to add behavior (`make`, loader, invalidation, `tick`)
- reason about freshness and GC behavior
- add feature adapters safely
- identify which gaps are accepted for now versus next-step roadmap work
