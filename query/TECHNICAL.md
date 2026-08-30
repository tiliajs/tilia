# Query engine and store

`@tilia/query` is split into two connected halves:

- The **engine** owns reactive rows, query membership, read projection,
  freshness, observation, refresh, and memory eviction.
- A **store** owns where answers come from, optimistic writes, remote
  synchronization, persistence, the outbox, rejections, and local retention.

`make` resolves one shared schema and gives it, together with an already-live
engine binding, to the configured store factory:

```text
make(config)
  -> schema { id, matches, key, sort, now }
  -> store(schema, binding)
  <- [source, applicationStore]
  <- [query, applicationStore]
```

This construction prevents the halves from choosing different ids, keys,
clocks, or membership rules. The engine only knows the store's `Source`; the
store can only change engine rows through its `Binding`.

The package ships one full store with two constructors:

- `Store.make` describes a conventional backend with `find`, `upsert`, and
  `remove`. It is the default application-facing option.
- `Store.custom` describes the same store through remote read/write channels.
  It exists for push and live sources that need channel lifecycle control.

Another store can replace the shipped one by implementing the
`StoreFactory` contract. It may return any application-facing value beside
the query object.

## Shared schema and result shape

Rows are normalized by `id`. Query results hold ids and read the canonical
row object, so one row can belong to several results without creating several
live copies. `matches(query, row)` updates membership when a row changes.

A query must be plain data and describe a full result set:

- `matches` decides membership from one row.
- A fresh find answers with every matching row.
- `sort(query)(rows)` orders that full array.
- `key(query)` identifies the query and defaults to `sortedStringify`.

Limits, pagination, and aggregates cannot be maintained from a per-row
predicate and a replacing full-result delivery, so they are outside this
model.

The shipped store additionally requires rows and queries to survive a JSON
round trip. Rejections are snapshots even without durable persistence, and
rows, records, and outbox entries are JSON in its `Kv`. Values and queries
must not themselves be `null` or `undefined`, and a backend must preserve a
client-supplied id.

## Engine/store seam

The store receives this binding:

- `item(id)` returns the canonical live object, if present.
- `changed(values)` applies remote truth. A row stays in memory only if an
  in-memory query matches it.
- `removed(ids)` removes rows and their in-memory memberships.
- `place(value)` applies an optimistic value and keeps it even when no query
  currently lists it.

The engine receives this source:

- `online` is the connectivity signal.
- `find(query, channel)` may answer one find several times.
- `forget(query)` says memory eviction has released the query.
- `tick()` runs the store's half of the heartbeat.
- `dispose()` closes the store after the engine has closed its finds.

The engine calls its own half first in both lifecycles. On `tick`, claim aging
and memory eviction run before the store's retry and purge work; observed
finds remain active while that purge runs. On `dispose`, the engine closes
every find before it asks the source to shut the store down.

## Claims and no weakening

Every loaded answer has a claim:

```text
partial < local < fresh
```

- `partial` means the store has these matching rows but cannot certify that
  no others exist.
- `local` means the stored result is complete.
- `fresh` means authoritative as of now. It does not mean that the bytes had
  to cross a network; a synchronized store may make this claim.

A find can deliver several tiers in any asynchronous order. A weaker answer
never replaces a stronger one. The engine compares claims before publishing,
and the shipped store applies the same rule before rewriting its query
record. A late partial or local read therefore cannot undo a fresh snapshot
or restore ids that fresh truth removed.

Only `tick()` weakens an answer. When fresh data ages, the engine changes its
claim from `fresh` to `local` and keeps the data. Typical progressions are:

```text
partial -> fresh
local   -> fresh
fresh   -> local -> fresh
```

An empty partial answer has special projection. It proves only that the
store currently holds nothing:

```text
online  -> "loading"
offline -> { state: "noData", reason: "offline" }
```

A complete empty answer is still data for `array`:

```text
{ state: "loaded", claim: "local" | "fresh", data: [] }
```

`one` alone projects that empty array into:

```text
{ state: "noData", reason: { reason: "noMatch", claim } }
```

The claim on `noMatch` matters because an absence ages exactly like a
non-empty answer.

## Find lifecycle

The first read of a query creates one engine entry and asks the source to
find it. The shipped store starts its local read first and starts the remote
read when online:

1. A registered query record names its row ids. Reading those rows can claim
   `local`.
2. An unregistered query normally scans held rows through `matches` and can
   claim only `partial`.
3. An optional `lookup` may use an application-owned index. It may claim
   `local` only when it can certify completeness.
4. The remote answer is reconciled with pending writes, recorded, persisted,
   and delivered as `fresh` or `live`.

The engine does not know which of these tiers exists. It sees one source and
one claim-bearing channel.

Starting a newer non-live find closes the older one. Closing makes every
late callback a no-op and runs the registered teardown once. Finds also close
on `end`, memory eviction, and `dispose`.

## Failure retention

A find failure does not automatically replace useful data:

- With no data to show, failure becomes
  `{ state: "noData", reason: { reason: "failed", message } }`.
- With loaded data, the result and its claim stay visible and
  `onError(query, message)` receives the failure.

The decision uses the projected result. In particular, an empty partial
answer while online still counts as no data, so a failed first remote read is
shown at the read site.

A failed non-live query remains eligible for refresh. `fetchedAt` throttles
attempts, and a hung attempt frees its slot after one refresh interval.

Failure does not close a live find. If it had data, that data remains and
`onError` runs; otherwise the failure is shown. The source may later recover
with another `live` delivery, or call `end` to return the query to periodic
refresh.

## Observation, refresh, and memory

Observation comes from Tilia's dependency graph. Reading a result inside an
observer puts its key in the result dictionary's live canopy; there is no
separate retain API.

On each heartbeat the engine:

1. stamps observed queries with the current time;
2. refreshes eligible observed, online, non-live queries;
3. lowers expired fresh claims to local;
4. evicts queries unseen for `expiry.memory`;
5. calls the store's heartbeat.

The default engine expiry is:

```text
refresh = 30 seconds
memory  = 5 minutes
```

An online fresh result gets an additional `refresh / 8` aging buffer, giving
an in-flight refresh time to arrive without a brief claim change. Offline,
there is no buffer.

Eviction closes the find, calls `source.forget(query)`, drops the in-memory
result and ids, and removes rows no other in-memory query references unless
an optimistic placement still holds them. It does not delete persisted data.

## Live sources and `Store.custom`

`Store.custom` takes a `Remote` whose `fetch` receives a read channel:

- `fresh(values)` replaces the result with a complete authoritative snapshot.
- `live(values)` does the same and marks the find self-maintaining.
- `fail(message)` reports a failure without closing.
- `end()` closes the find and returns a live query to normal refresh.
- `finally(fn)` installs the teardown.

The teardown is a single slot: the last registration wins. It runs exactly
once when the find closes. Registering after closure runs the function
immediately, and every other late callback is ignored.

While a query is live, engine refresh is skipped. Going offline does not end
it because the engine cannot know whether its transport survived. The
adaptor must pause, reconnect, or end its own subscription. On reconnect the
engine restarts non-live finds; a still-live source remains responsible for
itself.

Inbound push facts do not go through a query channel:

```text
store.receive.changed(values)
store.receive.removed(ids)
```

Changed rows are reconciled with pending writes, then join or leave every
matching in-memory query. Removed ids confirm pending removes; against a
pending create or update they record a conflict and preserve the server
deletion. These deliveries do not change query freshness.

## One `Kv` keyspace

The shipped store asks persistence for one string keyspace:

```typescript
type Kv = {
  get(tag, keys, set): void;
  keys(tag, set): void;
  set(tag, key, value): void;
};
```

It keeps all durable state in that keyspace under tags:

- `row` — one JSON row per id; this public tag is `Store.rowTag`
- `query` — query registry records
- `outbox` — ordered optimistic operations

A `Kv` does not interpret any of them. Omitting `persist` selects
`Store.memory()`, an in-process keyspace using the identical store path.
`@tilia/query/indexeddb` supplies a durable implementation with one object
store and compound key `[tag, key]`.

Persistence is command-only. Its errors cannot be returned through the query
or store protocols. The IndexedDB keyspace reports open and transaction
failures to its own `onError`; reads still answer with nothing and writes are
dropped.

## Query registry

A query record contains:

```text
key, query, ids, lastSeen
```

The query itself is retained so `matches` can run for records that are only
on disk. `lastSeen` is dated by the find that requested an answer, not by a
late delivery, so a slow reply cannot extend an abandoned query's lifetime.

The running store keeps a write-through registry mirror. During purge,
persisted records fill only keys absent from that mirror; an older persisted
copy cannot overwrite newer in-process truth.

For each held query, membership changes update its record immediately.
Records belonging only to earlier sessions are repaired later by refresh or
purge rather than scanned on every write.

An optimistic row that no real record lists receives a synthetic
`__id:<id>` record. This roots the row temporarily. During purge, a known row
is offered to every real record; matching records adopt it and the synthetic
record is removed. A row not loaded by the current engine keeps its synthetic
root until a later pass can inspect it or local expiry removes it.

## Outbox and optimistic placement

`store.upsert(value)`:

1. clears an existing rejection for that id;
2. computes a `created` or `updated` change from the current base;
3. places the value in engine memory;
4. updates held query memberships and records;
5. writes the row to the keyspace;
6. enqueues and persists an upsert.

`store.remove(id)` similarly clears a rejection, removes the row and its held
memberships immediately, deletes the persisted row, and enqueues a remove
when remote work remains.

The outbox is ordered by a monotonic sequence. Multiple pending edits to one
id coalesce into its existing position and retain their original base.
Entries in flight are excluded from concurrent pushes. On boot, persisted
entries are parsed, sorted by sequence, reflected in `status.pending`, and
pushed when online.

A remote snapshot receives the pending outbox overlay before display:
matching upserts replace or join rows, moved rows leave old results, and
pending removes filter ids out. This prevents optimistic state from
disappearing while a fetch catches up.

## `Store.make`: sequential outcomes

`Store.make` converts three ordinary backend functions into the custom
channel protocol:

```text
find(query, { fresh, fail })
upsert(value, reply)
remove(id, reply)
```

It issues outbox operations one at a time, in order, and waits for one reply
before calling the next backend function. A second reply for the same call is
ignored.

Upsert outcomes:

- `saved(value)` maps to channel `set(value)` and confirms the operation.
- `conflict(value)` maps to `conflict(value)`. The operation is answered but
  remains pending while merge attempts to rebase it.
- `rejected(message)` maps to `reject(id, message)`, refusing only that
  operation; the sequence continues.
- `transient` maps to `retry()`, stops the sequence, and leaves that operation
  and everything later pending.

Remove outcomes are deliberately separate:

- `removed` confirms the remove.
- `rejected(message)` refuses only that remove, then the sequence continues.
- `transient` stops before any later operation is sent.

The separate removal type prevents a saved row from being used to answer a
remove. Such a value would match no remove operation and leave it hanging.

## Channel write protocol

The lower-level `Store.custom` write channel sends an ordered batch and
allows these replies:

- `set(value)` confirms one upsert by `id(value)`.
- `removed(id)` confirms one remove.
- `conflict(value)` answers one operation with current remote truth but does
  not settle that operation.
- `reject(id, message)` definitively refuses one operation.
- `retry()` ends the batch and frees every unanswered operation for a later
  attempt.
- `fail(message)` ends the batch and definitively refuses every unanswered
  operation.

The first terminal `retry` or `fail` wins. All later callbacks are ignored.
Per-operation outcomes received before it stand; if a backend later rolls
back an acknowledged write, it must send that fact through `receive`.

A conflict is not a rejection by itself. With a successful `merge`, the
local edit is mutated in place, rebased on the remote row, persisted, and
left pending for the next heartbeat. It is not immediately pushed again,
which prevents a permanently conflicting backend from spinning.

If merge declines, the operation leaves the outbox, remote truth is placed,
and a conflict rejection is recorded. `reject` or `fail` also removes the
operation, but restores its base (or forgets a rejected create) and records a
failed rejection carrying the message. An unknown-id remove has no local
change or base to preserve, so refusing it clears the operation without
creating a rejection.

## Rejection records

Rejections are contextual history, not queued operations or overlays. Their
variants preserve the local story:

```text
createConflict { edited }
createFailed   { edited, message }
updateConflict { base, edited }
updateFailed   { base, edited, message }
removeConflict { base }
removeFailed   { base, message }
```

At the refusal boundary the whole record is deep-copied through JSON.
Subsequent edits to a live row cannot change the rejection's `base` or
`edited` snapshots.

`status.rejected` is kept in outbox sequence order regardless of reply order.
This makes a refused cascade appear cause-first. There is at most one
rejection per id; a newer one replaces the existing record in its existing
position. Any new write to that id clears its rejection.

Both resolution methods require the exact record object currently in the
array:

- `retry(rejection)` removes it and reapplies a copy of its edited upsert or
  remove through the ordinary optimistic path. The new change is computed
  against the value that stands now.
- `discard(rejection)` removes only the context.

A stale reference to a replaced or cleared rejection is a no-op. Rejections
are not persisted across restarts.

## Local purge

The store owns `expiry.local`, defaulting to 30 days. Purge runs on the first
heartbeat after construction and then at most once per `local / 8`. Engine
refresh and memory work still run on every heartbeat.

Purge is mark-and-sweep over the one keyspace:

1. Load query records absent from the current registry mirror.
2. Offer known synthetic rows to real query records and remove adopted
   synthetic roots.
3. Keep records for queries the engine still holds.
4. Delete unheld records older than `expiry.local`.
5. Mark ids listed by surviving records.
6. Mark ids of pending outbox operations, because boot replay still needs
   them.
7. Ask `Kv.keys(Store.rowTag)` for every persisted row id.
8. Delete each unmarked row.

Remote write-through never infers row deletion merely because a fresh query
omits an id. It rewrites the query record immediately; purge later deletes
the row only after no retained record or pending operation reaches it.

## Complexity

The implementation chooses linear scans over indexes:

- a changed row is offered to every in-memory query;
- held registry records are scanned for membership changes;
- a remote result reapplies every pending outbox operation;
- purge walks records and row keys.

This is deliberate for a client cache with dozens of active queries and a
normally short outbox. Hundreds of active queries or a large outbox overlaid
onto frequent live snapshots would need id-to-query and id-to-operation
indexes.

## Runtime output

The compiled root module imports `tilia` and no ReScript runtime helper.
Bundle rewriting points the generated Tilia import at the package root so the
application and query engine share one Tilia instance and reactive context.
