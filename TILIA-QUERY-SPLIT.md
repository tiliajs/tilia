# Splitting `@tilia/query`

Decisions from 2026-08-28 / 08-29. The shape is
`query/src/croquis/TiliaQuerySplit.res`; the ledger is
`query/test/TiliaQuery.feature`.

## Boundary

**A** — reactive query engine: `matches`/`sort`/`key`, `itemById`/`idsByKey`,
reactive results, freshness, memory expiry, canopy.
**B+C** — store: optimistic writes, outbox, three-way merge, durable rows,
query registry, local expiry, remote sync.

The boundary is **A | B+C**. B+C wraps the remote before A sees it, so
`reconcile` and `applyPending` stay out of the engine. `@lapa/db` replaces B+C
whole — never just `Kv`, which would leave two outboxes pushing to two places.

**Store** names the role, not the implementation. The one shipped here is a
write-through cache with an outbox; `@lapa/db` is a database; `Query` cannot
tell and must not.

## Read model

```rescript
type claim = Partial | Local | Fresh

type reason =
  | Failed({message: string})
  | Offline
  | NoMatch({claim: claim})

type loadable<'a> =
  | Loading
  | Loaded({claim: claim, data: 'a})
  | NoData({reason: reason})
```

- `claim` replaces `fresh: bool`. Completeness and freshness are one axis.
- Three arms: a read site waits, renders, or explains. Rendering is one arm —
  `claim` is a field so the common case does not grow a `switch`.
- `reason` is a value, not a sentence: each is a different affordance. Only
  `Failed` carries prose, and it is the adaptor's.
- `NoMatch` says the answer set was empty, never that the row does not exist.
- `NotFound` and `NotLocal` are gone.

Phases of a first read; after that a query keeps answering and cycles
`Fresh -> Local -> Fresh`:

```
registered:    Loading -> Loaded(Local)   -> Loaded(Fresh)
unregistered:  Loading -> Loaded(Partial) -> Loaded(Fresh)
```

**An empty `Partial` is not a result.** From `partial([])` or from losing the
last row: `Loading` while a remote answer is still possible, `NoData(Offline)`
otherwise. The rule lives in `one`/`array`, not at the four sites that mutate
`idsByKey`. A failed find needs no third case — an empty `Partial` does not
project to `Loaded`, so the failure rule below already gives `NoData(Failed)`.

**`one`** projects: a hit is `Loaded`, an empty complete result is
`NoData(NoMatch({claim}))`, an empty partial one matches `array`. `array` on a
certified-empty query stays `Loaded({data: []})` — an empty list is data.

## Channel contract

Four members, three claims. Origin-neutral: `fresh` means "the authoritative
answer to this query as of now", not "from the network" — a synchronized
`@lapa/db` answers locally and is entitled to say it.

| member | claim | means |
| --- | --- | --- |
| `partial` | `Partial` | rows I hold; membership unproven |
| `local` | `Local` | complete when stored |
| `fresh` | `Fresh` | complete now |
| `live` | `Fresh` | complete now and kept so |

`live` adds maintenance, not strength, which is why `tick` demotes a `fresh`
entry and never a live one. `matches` never manufactures `local` or `fresh`.

`Remote.Channel.read` is this minus the two weaker claims. `Query.config`'s
`answer` is `{fresh, fail}`. Same words at every level.

## Writes

`Channel.write` gains two per-operation members. Per-operation callbacks
answer one operation; `retry` and `fail` apply to every operation in the push
that has not been answered. Answering is not settling — `conflict` and `retry`
leave the operation pending.

| member | scope |
| --- | --- |
| `set`, `removed`, `conflict`, `reject` | one operation |
| `retry`, `fail` | every operation in the push not yet answered |

- `conflict(value)` rebases one operation and keeps it pending.
- `reject(id, message)` refuses one. Order does not imply dependency —
  reverting unrelated writes records rejections that are false.
- `fail` rejects every operation in the current push that has not yet
  received an outcome. Earlier outcomes remain unchanged: a server that
  acknowledged an operation and then rolled it back has to say so through
  `receive`, not through `fail`.

A cascade the server produced is information; a cascade `fail` invents is not.

**A batch stops at the first `Transient`.** The store issues no further
operation and calls `retry()`. An operation already answered keeps its
answer; everything unanswered is pushed again on a later tick.

**Rejection recovery.** `dismiss` becomes `retry` + `discard`:

- `retry(rejection)` queues the work as if written now. No special path: the
  local value is back at `base`, so the change context recomputes.
- `discard(rejection)` drops the record; the revert already happened.
- `upsert` or `remove` clears an existing rejection for the same id.
- `status.rejected` is in **outbox order** — a cascade is refused cause-first,
  so working down the list retries the cause before the consequence. Insert by
  the operation's sequence number, not by reply arrival: a custom `push` may
  answer out of order. A second refusal for a listed id replaces it in place.
- A rejection holds **snapshots**, not the live object: it is history, and the
  live value has already reverted to `base`. `retry` promotes the snapshot into
  a new optimistic write. This is where the no-second-copy rule stops.

Today it is reversed because `fail` reverts and records in one backwards pass
(`query/src/TiliaQuery.res:742`). Nothing requires that: `enqueue` replaces a
pending entry in place (`:768`), so the outbox holds **at most one operation
per id** and reverts are independent. Split the two jobs.

## Failure

A failure replaces the result only when there is no data to show. Otherwise
the current result stays visible and the message goes to `onError`. The
discriminator is what `array` currently answers — the projected result, not
which find failed:

- answers `Loaded` (a certified empty list included): the answer stays, the
  message goes to `onError`.
- anything else: `NoData({Failed})`.

Some data beats an error in place of a list; a list blinking data → error →
data is worse than either. Product policy, not a technical claim.

```rescript
onError?: (~query: 'query, ~message: string) => unit
```

Only failures a read site will not show. No error field on `Loaded` — an
adaptor can log everything itself; what it cannot know is whether the engine
had rows to keep.

## Contract of the built-in store

Two requirements of **`Store`'s protocol**, not of `Schema` and not of the
engine. Another store persists differently and reconciles ids differently;
`@lapa/db` is not bound by either.

- `'a` and `'query` **survive a JSON round trip unchanged**. `Kv.t` stores
  strings, nothing here encodes them, and a registry record persists the query
  itself for purge — a query that round-trips into a different shape makes
  purge silently wrong.
- The backend **preserves the id the client sent**. `set(value)` and
  `conflict(value)` find the pending operation by `id(value)`, so a
  backend-assigned id leaves that operation pending forever.

## Public API

**One constructor.** What varies is the value in `store`, not the shape of the
config. ReScript cannot express "exactly one of these fields", but it has no
trouble with a union in a *value* — so the union goes there.

```rescript
Query.make({id, matches, store: Store.make({find, upsert, remove, persist: IndexedDb.make("students")})})
Query.make({id, matches, store: Store.make({find, upsert, remove})})   // persist defaults to memory
Query.make({id, matches, store: Store.custom({remote})})               // channels
Query.make({id, matches, store: Lapa.store(~db, ~collection="students")})
```

The fields split on the seam with nothing left over. `id`, `matches`, `key`,
`now`, `sort`, `expiry: {refresh, memory}`, `onError` are the engine's;
`find`, `upsert`, `remove`, `persist`, `lookup`, `merge`, `expiry: {local}`
are the store's. The `expiry` record stops mixing two halves.

- **Store vocabulary.** `find`, `upsert`, `remove` — `fetch` belongs to a
  cache, and would name the wire in a design that is origin-neutral
  everywhere else. `Remote.t.fetch` keeps the word; that one really is remote.
- **An external store is not a third entry point**, it is the same field with
  a different value. `Store` is simply the adaptor we ship.
- **A weaker answer cannot replace a stronger one while a find is open.**
  `Partial` cannot replace `Local` or `Fresh`, `Local` cannot replace `Fresh`;
  only `tick` lowers a claim. A refresh asks the store again and the store answers from local
  storage first, which must not pull a fresh result back down.
- **`Store.make` / `Store.custom`** is the one remaining exactly-one-of pair,
  now at the level where the difference actually is: how you describe your
  backend, not which constructor you call.
- **Callbacks, not promises.** `makeGetEntry` writes `Loading`, calls the
  source, returns — a source that answers at once is read as `Loaded` on the
  first read. A promise defers a microtask and lands outside `Tilia.batch`.
- **Not named for a protocol.** REST, Supabase, PostgREST, RPC, GraphQL and a
  test double are one shape; it never sees a URL.
- **The status-code table does not ship.** The application returns an
  `outcome`; the package supplies the protocol, never the judgement.
- **Two outcome types.** A shared one would let `Removed` answer an upsert,
  which maps to `channel.removed`, matches nothing, and hangs the operation.
- **No `subscribe`.** A shallow one cannot close the gap while becoming live
  is itself asynchronous, and a readiness handshake puts a step in the simple
  constructor whose omission stops the query ever running. One rule:
  `Store.make` is for backends that answer when asked; anything that pushes
  uses `Store.custom`.
- `Store.online()` is one signal per process, always online where there is no
  `addEventListener`.

## Storage

- `persist` absent means an in-memory keyspace, and it is the **default**.
  Storeless is not a second behavioral mode; the bundle cost is a dict and a
  prefix scan.
- Registered query → `local(ids -> rows)` from the registry, which already
  holds `{key, query, ids, lastSeen}`.
- Unregistered query → scan the row prefix through `matches`, answer
  `partial`. Not optional: without it the built-in store can never produce
  `Partial`, and the classroom case exists only for applications with a second
  query layer. **This is a new bet** — `TECHNICAL.md`'s linear-scan bet covers
  in-memory counts, not persisted rows. Bounded by the local cache.
- `lookup?` is an optimization for persistence with an index, and may answer
  `Local` only when it can certify the snapshot. A scan never can. It took its
  name from the old `find?`, which yielded the word to the store trio.
- `Kv.t` and `lookup` have nothing to do with `@lapa/db`.

## Interface between the halves

Two seams, and they are the same relationship mirrored — which is the whole
difficulty. Everything else in the design is a plain port: one implementer,
one caller, no return path.

| seam | implemented by | called by |
| --- | --- | --- |
| `Engine.source` — `online`, `find`, `forget` | B+C | A |
| `Engine.binding` — `item`, `changed`, `removed`, `place` | A | B+C |

**The cycle is real** — a cache that answers queries and accepts writes is
bidirectional by nature. It is tied once, inside `Query.make`, as a type:

```rescript
connect: binding<'a> => (source<'query, 'a>, 'store)
// Engine.make : config<'query, 'a, 'store> => (t<'query, 'a>, 'store)
```

The engine builds its binding, calls `connect` during `make`, and hands the
store straight back to the caller. `'store` is opaque — A stays ignorant of
B+C. No `ref`, no `option`, no throwing stub, no half-built state, and no
ordering rule an adaptor author can get wrong, because there is no moment at
which either half exists unconnected. `bind` is gone with it: the binding is
built before `connect` and passed to it. Outbox replay belongs in the store's
own constructor.

```rescript
type binding<'a> = {item: string => option<'a>, changed, removed, place}
```

- `item` is a getter, not the `itemById` dict. It gives the same identity
  access — the object returned *is* the live one, so merging in place works —
  while making a key insert or delete unexpressible rather than merely
  forbidden, so `idsByKey` cannot fall out of step. Handing the dict over cost
  the engine nothing reactively (its result lists read `itemById` from inside
  `Engine`, never through the binding) and bought only a rule written in prose.
- Mutate the object in place; write only through `changed`/`removed`/`place`.
- One live object per id: the store must never retain a second **canonical**
  copy. Transient ones are fine and unavoidable — a remote value in flight, a
  row decoded from persistence, a rejection snapshot. This is the real
  `@lapa/db` constraint: a store that materializes its own rows must hand those
  very objects across, because interop is promised at the level of object
  identity, not record shape.
- With `item` in hand the store merges in place itself, so `merge` means
  only *accepted or conflicted*. It is no longer also the identity mechanism.
- Not `view` (it mutates; view means the materialized results), not `access`
  (`@lapa/db` uses it for permissions).
- **Dispose engine first**, then store, so no find is in flight against a
  stopped store. `dispose` writes nothing on either side.
- `store.dispose()` does not close `persist`. `Kv.t` has no lifecycle, and one
  keyspace can back more than one store, so closing belongs to whoever created
  it.
- `source.forget(query)` on eviction, and **not** on dispose. A query in
  memory is retained unconditionally and its `lastSeen` is stamped there; a
  live query is found once, so opens cannot date it, and `finally` cannot
  distinguish eviction from supersede. Dating on the way out was a rule here
  and is not any more: `tick` re-dates an observed record at most one refresh
  window apart (`query/src/TiliaQuery.res:1042`), so a clean shutdown is at
  worst 30 seconds stale against a 30-day expiry, and an early purge heals on
  the next find.
- `Schema.t` is resolved once by `Query.make` and passed to both halves.
  `store` is a **factory**, not a built store, so the two cannot disagree.
- `applyPending` needs `matches` — a pending upsert that moved a row out of a
  query must be filtered from *that* query's result.
- `_canopy` survives the split (`query/test/TiliaQuerySteps.res:335`).
- A's entry state machine needs a `Partial` state between `Pristine` and
  `LoadedLocal`, or a partial answer is either overwritten by a later decline
  or claims a completeness it lacks.

## Packaging

One npm package. A and B+C are tightly coupled and share nominal types;
separate packages create versioning problems with no independent consumer.
`Store.memory()` on core, IndexedDB behind `@tilia/query/indexeddb` — this
package ships CJS as well as ESM, so a CJS consumer takes the whole module.

## Still to fix

- ~~`Channel.write.set` with `merge` rebases, persists, then confirms away~~ —
  fixed in 2c. `set` confirms and places the authoritative value; rebasing is
  what `conflict` does, and it keeps the operation pending so the heartbeat
  pushes the merged value.
- ~~`tick` never called `pushPending`~~ — fixed, with *a transient push
  failure is retried on the next tick* and a `Push` wrapper in the harness.

## Unspecified

**Is `Store.make` enough?** `claims-app-ts` is the test — its adaptor should
mostly disappear. Answerable only by writing it.

## Invariant

Every scenario in `query/test/TiliaQuery.feature` passes unchanged except
those rewritten below. The four registry-id scenarios stay as they are —
*remove a card while online*, *an upserted card joins matching open queries
immediately*, *moving a card updates matching queries in memory*, *a new card
joins matching queries stored locally*: immediate registry maintenance is the
behavior being kept.

Step vocabulary: `"remote"` becomes `"fresh"`, `"local"` keeps its name,
`"partial"` is new; `not local` becomes `no data because offline`; `failed
with "boom"` becomes `no data because failed with "boom"`.

## Next actions

The sequenced plan and its progress live in `SESSION.md`; the scenarios that
land with each phase, one per rule above, are in `TILIA-QUERY-SCENARIOS.md`.
Kept here so this file stays the ledger of *what* and those stay the record of
*when*.

One demand the plan makes on the test harness, because the scenario that
depends on it cannot fail without: a store that **replays its outbox
synchronously in its own constructor**. The built-in store replays
asynchronously (`TiliaQuery.res:908`), so nothing else exercises the binding
being usable while `connect` is still running.
