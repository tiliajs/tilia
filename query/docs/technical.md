# TiliaQuery Technical Overview

## Purpose And Boundary

TiliaQuery is a small offline-first query-state layer for collections in Tilia applications.

It solves:
- shared caching of fetched objects
- query-level loading state (lists via `array`/`dict`, detail views via `one`)
- offline-first reads through an optional local store tier
- a durable write outbox: puts and deletes replayed across sessions
- write-failure visibility (pending count, rejections, fetch errors)
- stale refresh behavior
- idle-query garbage collection
- object-driven membership from writes and live updates: changed objects move between query results in place, without refetching
- sorted, stable query results (views only change when membership changes)
- lifecycle teardown (`dispose`, `clear`)

It does **not** solve:
- transport concerns (HTTP, websocket, auth)
- storage concerns (IndexedDB/Dexie schemas, query glue)
- domain-specific query APIs (should be wrapped per feature)
- scheduler ownership (the app calls `tick()`)

## Current Public API

From `query/src/TiliaQuery.resi` (TypeScript mirror in `query/src/index.d.ts`):

```rescript
@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({data: 'a})
  | @as("notFound") NotFound

module Channel = {
  type state = | @as("live") Live | @as("cancelled") Cancelled

  // read path (local and remote fetch)
  type fetch<'a> = {
    state: state,
    emit: array<'a> => unit,   // rows
    fail: string => unit,      // transport error: freshness untouched
    covered: unit => unit,     // delta-sync engine owns this query: mark fresh
  }

  // write path (remote upsert and remove)
  type write<'a> = {
    state: state,
    emit: 'a => unit,          // saved: settle clean
    offline: unit => unit,     // transient: keep queued for next reconnect
    conflict: 'a => unit,      // server wins
    reject: string => unit,    // permanent refusal: drop, surface on status
  }
}

// An unsynced operation: a put, or a delete when `deleted` is true.
type write<'a> = {value: 'a, deleted: bool}

type rejection<'a> = {value: 'a, deleted: bool, message: string}
type fetchError = {key: string, message: string}
type status<'a> = {
  mutable pending: int,
  mutable rejected: array<rejection<'a>>,
  mutable error: option<fetchError>,
}

type remote<'a, 'query> = {
  online: bool,
  fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
  upsert: ('a, Channel.write<'a>) => unit,
  remove: ('a, Channel.write<'a>) => unit,
}

type store<'a, 'query> = {
  fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
  save: ('a, bool) => unit,          // put; bool = dirty
  remove: ('a, bool) => unit,        // dirty: tombstone; clean: purge
  dirty: unit => promise<array<write<'a>>>,
}

type config<'a, 'query> = {
  id: 'a => string,
  remote: remote<'a, 'query>,
  local?: store<'a, 'query>,
  stale?: float,
  gc?: float,
  now?: unit => float,
  key?: 'query => string,
  matches?: ('query, 'a) => bool,
  sort?: ('a, 'a) => float,
}

type t<'a, 'query> = {
  get: string => loadable<'a>,
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  dict: 'query => loadable<dict<'a>>,
  upsert: 'a => unit,
  remove: 'a => unit,
  sync: 'a => unit,
  tick: unit => unit,
  status: status<'a>,
  dismiss: unit => unit,
  dispose: unit => unit,
  clear: unit => unit,
}

let make: config<'a, 'query> => t<'a, 'query>
```

### TypeScript boundary rules

The compiled JS never leaks ReScript variant internals:

- `loadable` compiles to `"loading" | "notFound" | {state: "loaded", data}` (via `@tag`/`@as`).
- All adapter outcomes are named channel callbacks (`channel.conflict(server)`), never constructed values.
- Adapter data is plain records with flags (`{value, deleted}`).
- `make` takes a single config record, which compiles to an options object.

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
- `ones` / `arrays` / `dicts`: memoized views per query key (computed; same proxy until the id list changes)
- `meta`: query metadata (filter, fetched timestamp, idle timestamp)
- `staleKeys`: query keys marked for reload
- `Outbox.entries`: pending and in-flight writes keyed by object id (`{write: {value, deleted}, cancel}`)
- `status`: reactive tilia object (`pending`, `rejected`, `error`)

Keys are generated from query filters with `Json.sortedStringify` by default, so equivalent object filters map to the same cache key.

## Data Flow

### 1) Query read (`one` / `array` / `dict`) — two tiers

When first accessed:
1. build query key
2. store query metadata
3. mark query stale
4. create `Tilia.source(Loading, loader(...))`
5. loader runs `startFetch`, which always calls `local.fetch(query, channel)` and, only when `remote.online`, also calls `remote.fetch(query, channel)`
6. each tier pushes rows with `channel.emit(rows)`; the remote tier may also `fail(message)` or `covered()`

A query opened offline resolves from the local store instead of hanging in `Loading`.

After each `emit(rows)`:
- rows are ordered with `sort` when configured, so both tiers produce the same order
- objects are written to `cache`, **except** ids with a pending put (the optimistic value wins until the write settles)
- ids with a pending **delete** are filtered out of the result, so a racing fetch cannot resurrect a deleted row
- remote rows are additionally written through to `local.save(row, false)` (same pending exceptions)
- query result stores ids only; loadable state becomes `Loaded({data: ids})`
- an id-list identical to the current one is dropped: the loadable and the memoized views keep their identity, so watchers do not re-render on no-op refetches
- remote emits refresh `fetched`; local emits do not

Remote fetch outcomes:
- `emit(rows)` — rows land, freshness refreshed, `status.error` cleared
- `covered()` — no rows; the query is marked fresh (a delta-sync engine keeps the local store complete, see below)
- `fail(message)` — freshness is **not** touched, so the next `tick` past the stale window retries; `{key, message}` is recorded on `status.error`

Local tier failures are ignored: a broken local store is an adapter bug, not a sync state.

If channel state becomes `Cancelled`, all callbacks are no-ops and late responses are ignored.
Transport may check `channel.state` proactively, but cancellation safety is enforced inside channel handlers.

**Ordering assumption (adapter requirement):** remote is authoritative because
its emit is expected to land after local. A one-shot `local.fetch` that
resolves *after* the remote emit can transiently overwrite fresher remote rows
in the cache. IndexedDB is virtually always faster than the network, but if
your local tier cannot guarantee this, use a live query (Dexie `liveQuery`):
remote rows are written through to the local store, so live local reads
converge to remote truth.

### 2) Local write (`upsert` / `remove`) — durable outbox

`upsert(item)` (a put) and `remove(item)` (a delete) share one flow, `send(write)`:
1. store/replace the outbox entry by id (latest write wins per id; an in-flight superseded entry has its channel cancelled first)
2. persist durably — even offline; this is what makes writes durable:
   - put: `local.save(item, true)` (dirty row)
   - delete: `local.remove(item, true)` (dirty tombstone)
3. apply optimistically to memory: put fills `cache`, delete evicts the id
4. update query membership in place through `matches`: the id enters results whose filter matches the new value (at its `sort` position) and leaves results that contain it but no longer match; deletes leave every result containing the id. No stale marking and no fetch — the changed object is already known
5. if `remote.online`, dispatch through `remote.upsert` / `remote.remove`; if offline, the entry stays queued for reconnect — no timer, no retry loop

`remote.upsert` / `remote.remove` are push-and-forget: they return nothing and
once a write is handed to the transport it cannot be uncommitted. Cancelling
the write channel is the only disposal mechanism (late callbacks become
no-ops). Only fetch contracts return a cleanup, since live subscriptions need
teardown on query GC.

Write settlement (dirty lifecycle):

| Response | Put entry | Delete entry |
| --- | --- | --- |
| `emit(saved)` | removed; `local.save(saved, false)`; resolved into cache | removed; `local.remove(value, false)` purges row + tombstone |
| `conflict(server)` | removed; server wins: resolved into cache, saved clean | removed; server resurrects the row: resolved into cache, saved clean |
| `reject(message)` | removed; saved clean (stops boot retries); rejection recorded on `status.rejected`; every query marked stale so the refetch restores server truth (the object may belong to lists it optimistically left) | removed; tombstone cleared; same rejection + stale convergence |
| `offline()` | kept queued; row stays dirty | kept queued; tombstone stays dirty |

`status.pending` always equals the outbox size; UI can show "N changes waiting
to sync". `status.rejected` accumulates refusals until the app calls
`dismiss()`.

### 2b) Boot replay

At `make`, the core loads `local.dirty()` (async) and feeds each `{value,
deleted}` record through the normal `send` flow: optimistic cache state (puts
fill the cache, tombstones keep the id out), membership updates, and
replay-when-online all apply. Closing the app with unsynced writes and
reopening it resumes the sync where it left off.

### 3) Live/inbound update (`sync`)

`sync(item)`:
1. writes item to the memory cache using `id(item)`
2. runs the same membership updates through `matches`
3. does **not** call the remote and does **not** touch the local store

This is intended for websocket events, delta-sync engines, or external state
pushes. A delta engine writes its changes to the local database itself, then
calls `sync(item)` per change; `local.save` is reserved for the core's own
write-through and outbox.

### 4) Reconnect ownership

Connectivity ownership lives in the core. The watcher is built on the internal
observer API (`Tilia._observe` / `_ready`) rather than `Tilia.watch`, so
`dispose()` can stop it:
- on `false -> true`, live queries are marked stale (re-running both tiers) and queued outbox entries replay
- on `true -> false`, active write channels are cancelled but entries are retained

Replay sends each queued entry once per reconnect; an entry that gets
`offline()` stays queued for the next reconnect.

### 5) Lifecycle (`tick`)

`tick()` uses `Tilia._canopy(queries)` to split query keys:
- `live`: watched now
- `idle`: not currently watched

Then:
- live stale check: only while `remote.online`, if `now - fetched >= stale`, mark stale (an offline app does not re-read local every tick; reconnect replay refreshes instead)
- idle cleanup: if `now - idle >= gc`, evict query metadata, stale flag, and memoized views (`ones`, `arrays`, `dicts`)
- cancel cleanup callback for evicted active fetch channels
- post-eviction object purge: remove objects no longer referenced by remaining queries

### 6) Teardown (`dispose` / `clear`)

- `dispose()` stops the connectivity watcher and cancels every open fetch and
  write channel. The instance stays readable (cache intact) but inert; the
  boot replay is also guarded against firing after disposal.
- `clear()` empties memory state: cache, queries, views, metadata, stale
  flags, and the outbox (in-flight channels cancelled first), and resets
  `status`. It does **not** touch the local database: wiping IndexedDB on
  logout / user switch is the adapter's job, and institutional apps **must**
  do it — the local store contains user-scoped data.

## Usage Pattern

Recommended structure:
1. Build one query adapter per feature/domain.
2. Keep transport in service modules.
3. Expose domain-shaped helpers to app code.
4. Pass `matches` that expresses domain membership rules between query filters and objects, and `sort` for stable result order.
5. Surface `status` in a global sync indicator (pending count, rejection toasts).

Tests in `query/test/TiliaQuery.feature` and `query/test/TiliaQueryTestHelpers.res` show this pattern with `Papabase` as an adapter example.

## Writing Adapters

The read contract is symmetric: `store.fetch` has the exact shape of
`remote.fetch`. Every `'query` value the app generates must be interpretable
by **both** sides — the local glue (e.g. Dexie where-clauses) and the remote
glue (e.g. REST query params or Supabase filters). Either implement the
interpretation twice or share a query parser.

See the README for copy-paste REST remote and Dexie local store recipes. The
recommended local storage layout is **in-row flags** — indexed `dirty: 0|1`
and `deleted: 0|1` columns on the collection table:

- `save(item, true)` — upsert row with `dirty: 1, deleted: 0`
- `remove(item, true)` — upsert row with `dirty: 1, deleted: 1` (tombstone; row content kept for replay)
- `save(item, false)` — upsert row clean
- `remove(item, false)` — physically delete the row
- `dirty()` — rows with `dirty == 1`, mapped to `{value: row, deleted: row.deleted == 1}`
- `fetch` — must exclude `deleted == 1` rows

The local store doubles as the optimistic read source, so the main table must
already reflect unsynced edits; flags keep that single-table property. A
separate outbox table is possible but forces double bookkeeping and is not the
recommended default.

## Delta-Sync Compatibility

The intended end state for most apps is a delta-sync engine (outside
TiliaQuery) that pulls access-scoped changes since a cursor and keeps the
local store complete; local queries become authoritative and the per-query
remote fetch is the fallback for heavy or uncovered datasets. This maps onto
the contracts as-is:
- inbound deltas: the engine writes the local database, then calls `sync(item)` per change
- covered queries: the remote adapter answers `channel.covered()` without fetching — the core marks the query fresh and keeps current data (this replaced the old `channel.fail("covered")` convention; `fail` is now strictly a transport error)
- uncovered/partial queries: normal `remote.fetch` fallback with write-through; the adapter records new coverage
- outbound: the dirty outbox plus `remote.upsert` / `remote.remove` is the delta push side

## Current Shortcomings And Open Problems

- **Membership cost:** every write scans all stored query metadata; this is simple but can become expensive with many active filters.
- **Pagination/windowing:** current docs and API focus on full query-result arrays, not advanced page/window cache strategies.
- **Cross-query consistency rules:** complex relationships (derived aggregates, graph-like joins) still rely on feature-layer logic.
- **Query DSL:** `'query` is opaque; a serializable field/range DSL would let local evaluation, remote compilation, coverage checks, and `matches` derive from one definition instead of per-adapter parsers.

## What This Should Enable

A contributor should be able to:
- understand where to add behavior (`make`, loader, outbox, membership, `tick`)
- reason about freshness, GC, and teardown behavior
- add feature adapters safely
- identify which gaps are accepted for now versus next-step roadmap work
