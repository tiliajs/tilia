---
name: TiliaQuery
slug: tilia-query-type
kind: type
module: core
since: "0.1"
sort: 200
summary: The collection object returned by make.
signature:
  ts: |-
    type TiliaQuery<T, Q> = {
      one: (query: Q) => Loadable<T>,
      array: (query: Q) => Loadable<T[]>,
      upsert: (value: T) => void,
      remove: (id: string) => void,
      receive: Receive<T>,
      status: Status<T>,
      dismiss: (rejection: Rejection<T>) => void,
      tick: () => void,
      dispose: () => void,
      _canopy: () => Canopy
    }
  res: |-
    type t<'query, 'a> = {
      one: 'query => loadable<'a>,
      array: 'query => loadable<array<'a>>,
      upsert: 'a => unit,
      remove: string => unit,
      receive: receive<'a>,
      status: status<'a>,
      dismiss: rejection<'a> => unit,
      tick: unit => unit,
      dispose: unit => unit,
      _canopy: unit => canopy,
    }
tags: []
---

`TiliaQuery<T, Q>`/`t<'query, 'a>` is the collection object returned by [make](api.html#make): one value per collection, holding everything the application touches.

- Reads: [one](api.html#one), [array](api.html#array) — reactive, answering a [Loadable](api.html#loadable-type).
- Writes: [upsert](api.html#upsert), [remove](api.html#remove) — optimistic, queued in the outbox.
- Inbound push: [receive.changed](api.html#receive-changed), [receive.removed](api.html#receive-removed).
- Sync state: [status](api.html#status), with [dismiss](api.html#dismiss) for resolved or ignored rejections.
- Lifecycle: [tick](api.html#tick), [dispose](api.html#dispose).
- Tooling: [_canopy](api.html#canopy).

Feature modules typically wrap this object in domain-specific helpers rather than exposing it raw, so application code keeps reading in the language of the business.

```typescript
import type { TiliaQuery } from "@tilia/query";

const openDeck = (cards: TiliaQuery<Card, Query>, deck: string) =>
  cards.array({ deck });
```

```rescript
let openDeck = (cards: TiliaQuery.t<query, card>, deck: string) =>
  cards.array({deck: deck})
```
