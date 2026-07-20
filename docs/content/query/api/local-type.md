---
name: Local
slug: local-type
kind: type
module: core
since: "0.1"
sort: 250
summary: Local adaptor — durable typed values plus a bookkeeping KV.
signature:
  ts: |-
    type Local<T, Q> = {
      fetch: (query: Q, channel: LocalChannel<T>) => void,
      push: (ops: Op<T>[]) => void,
      set: (tag: string, key: string, value: string | undefined) => void,
      get: (tag: string, key: string | undefined, set: (values: string[]) => void) => void,
      ids: (set: (ids: string[]) => void) => void
    }
  res: |-
    type local<'query, 'a> = {
      fetch: ('query, Channel.local<'a>) => unit,
      push: array<op<'a>> => unit,
      set: (~tag: string, ~key: string, option<string>) => unit,
      get: (~tag: string, ~key: string=?, ~set: array<string> => unit) => unit,
      ids: (~set: array<string> => unit) => unit,
    }
tags: []
---

`Local` wires durable storage into [make](api.html#make). It is two stores in one adaptor: a typed values table (`fetch`, `push`) and a string KV for engine bookkeeping (`set`, `get`). Values reach the adaptor typed, so it can store them natively and index them.

Local persistence is **command-only** — there is no write channel. Confirmation, retry and rejection are remote concepts; a local storage error is the adaptor's own business (log, retry, surface in app state). The library never sees it.

- `fetch` — answer a query from the values table through a [LocalChannel](api.html#local-channel-type): `set` with results, or `unknown` when the store cannot answer.
- `push` — apply value changes in order: `Upsert` writes or replaces the row, `Remove` drops it.
- `set` — store a bookkeeping entry under a tag and key; `None` / `undefined` deletes it.
- `get` — read one entry by key, or every entry for the tag when the key is omitted. Reply through the given `set` — synchronously or later, like everything else.
- `ids` — reply with the id of every row in the values table. The purge sweep enumerates rows through this.

See guide chapter [A week at Nora's](guide.html#a-week-at-noras).

```typescript
import type { Local } from "@tilia/query";

const local: Local<Card, Query> = {
  fetch: (query, channel) =>
    db.cards
      .where("deck")
      .equals(query.deck)
      .toArray()
      .then(channel.set),
  push: (ops) =>
    ops.forEach((op) =>
      op.op === "upsert" ? db.cards.put(op.value) : db.cards.delete(op.id)
    ),
  set: (tag, key, value) =>
    value === undefined
      ? db.kv.delete(`${tag}/${key}`)
      : db.kv.put({ key: `${tag}/${key}`, value }),
  get: (tag, key, set) =>
    key === undefined
      ? db.kv.byPrefix(`${tag}/`).then((rows) => set(rows.map((r) => r.value)))
      : db.kv.get(`${tag}/${key}`).then((row) => set(row ? [row.value] : [])),
  ids: (set) => db.cards.toCollection().primaryKeys().then(set),
};
```

```rescript
let kvKey = (~tag, ~key) => `${tag}/${key}`

let local: TiliaQuery.local<query, card> = {
  fetch: (query, channel) =>
    db.cards.filter(card => card.deck === query.deck)
    ->Promise.thenResolve(channel.set)
    ->ignore,
  push: ops =>
    ops->Array.forEach(op =>
      switch op {
      | Upsert({value}) => db.cards.put(value)->ignore
      | Remove({id}) => db.cards.delete(id)->ignore
      }
    ),
  set: (~tag, ~key, value) =>
    switch value {
    | Some(value) => db.kv.put({key: kvKey(~tag, ~key), value})->ignore
    | None => db.kv.delete(kvKey(~tag, ~key))->ignore
    },
  get: (~tag, ~key=?, ~set) =>
    switch key {
    | Some(key) =>
      db.kv.get(kvKey(~tag, ~key))
      ->Promise.thenResolve(row => set(row->Option.mapOr([], r => [r.value])))
      ->ignore
    | None =>
      db.kv.byPrefix(`${tag}/`)
      ->Promise.thenResolve(rows => set(rows->Array.map(r => r.value)))
      ->ignore
    },
  ids: (~set) => db.cards.primaryKeys()->Promise.thenResolve(set)->ignore,
}
```
