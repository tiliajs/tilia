---
name: Store
slug: store-type
kind: type
module: core
since: "0.1"
sort: 230
summary: Local store adapter — offline reads, the write outbox, and the query registry.
signature:
  ts: |-
    interface Store<T, Q> {
      fetch(query: Q, channel: FetchChannel<T>): void | (() => void),
      save(value: T, dirty: boolean): void,
      remove(value: T, dirty: boolean): void,
      dirty(): Promise<Write<T>[]>,
      queries(): Promise<QueryRecord[]>,
      saveQuery(record: QueryRecord): void,
      removeQuery(key: string): void
    }

    type QueryRecord = { key: string; ids: string[]; fetched: number };
  res: |-
    type store<'a, 'query> = {
      fetch: ('query, Channel.fetch<'a>) => option<unit => unit>,
      save: ('a, bool) => unit,
      remove: ('a, bool) => unit,
      dirty: unit => promise<array<write<'a>>>,
      queries: unit => promise<array<queryRecord>>,
      saveQuery: queryRecord => unit,
      removeQuery: string => unit,
    }

    type queryRecord = {key: string, ids: array<string>, fetched: float}
tags: []
---

The optional local store is the durable half of the lifecycle: it answers every query offline, persists the write outbox, and remembers which rows the server last vouched for. `fetch` uses the same [FetchChannel](api.html#fetch-channel-type) contract as the remote — its failures are ignored by design (an adapter bug, not a sync state).

The `dirty` flag on `save` and `remove` is the entire outbox mechanism: `save(value, true)` marks a row unsynced, `remove(value, true)` writes a delete tombstone, and the clean calls settle them once the remote confirms (`remove(value, false)` purges row and tombstone). `dirty()` returns the previous session's unsynced writes — each a `Write` carrying the `value` and a `deleted` flag — replayed at boot through the normal flow.

The query registry is what bounds retention. A `QueryRecord` is the id list the remote last returned for a query key: `saveQuery` upserts it on every authoritative answer, `removeQuery` drops it when [tick](api.html#tick) evicts the query, and `queries()` loads the registry at boot. Rows that leave a persisted result are purged unless another record still references them — so the store holds exactly the union of known query results plus unsynced writes, and a row deleted on the server cannot reappear as a ghost on the next offline start. Retention is driven by the server's own answers (the persisted id lists), never by re-evaluating `matches` — and dirty rows and tombstones are untouchable. A store that implements the three as no-ops opts out: the core becomes a pure write-through cache and nothing is ever pruned.

Two honest caveats. Pruning needs the row in the memory cache (it calls `remove(value, false)` with the cached value), so a row not in memory is skipped until a later answer sees it. And a query answered with `covered()` writes no record, so on a table that mixes covered and uncovered queries, an uncovered query's GC can transiently prune a row the covered dataset still holds — the engine converges it back, but if that matters, cover all queries on a table or none.

A full sync engine also fits this contract: answer fetches from its database, report `covered()`, and deliver inbound changes via [changed](api.html#changed) and [removed](api.html#removed). See guide chapter [The channel boundary](docs.html#the-channel-boundary).

```typescript
const local: Store<Card, DeckQuery> = {
  fetch: (q, channel) => void db.query(q).then(channel.set),
  save: (card, dirty) => db.put({ ...card, dirty }),
  remove: (card, dirty) =>
    dirty ? db.put({ ...card, dirty, deleted: true }) : db.delete(card.id),
  dirty: () => db.unsynced(),
  queries: () => db.queries.toArray(),
  saveQuery: (record) => db.queries.put(record),
  removeQuery: (key) => db.queries.delete(key),
};
```

```rescript
let local: TiliaQuery.store<card, deckQuery> = {
  fetch: (q, channel) => Db.query(q)->Promise.thenResolve(channel.set)->ignore->None,
  save: (card, dirty) => Db.put(card, ~dirty),
  remove: (card, dirty) => dirty ? Db.tombstone(card) : Db.delete(card.id),
  dirty: () => Db.unsynced(),
  queries: () => Db.queryRecords(),
  saveQuery: record => Db.putQueryRecord(record),
  removeQuery: key => Db.deleteQueryRecord(key),
}
```
