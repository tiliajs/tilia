---
name: StoreChannels
slug: store-channels-type
kind: type
module: core
since: "0.1"
sort: 320
summary: Configure Store.custom with advanced channels and storage.
tags: []
signature.ts: |-
  type StoreChannels<T, Q> = {
    remote: Remote<T, Q>,
    persist?: Kv,
    lookup?: (query: Q, channel: LocalChannel<T>) => void,
    merge?: (change: Change<T>, remote: T) => boolean,
    expiry?: StoreExpiry
  }
signature.res: |-
  type Store.channels<'query, 'a> = {
    remote: remote<'query, 'a>,
    persist?: Store.Kv.t,
    lookup?: ('query, Channel.local<'a>) => unit,
    merge?: (~change: change<'a>, ~remote: 'a) => bool,
    expiry?: Store.expiry,
  }
label: StoreChannels
---

`StoreChannels` configures [Store.custom](api.html#store-custom):

- `remote` supplies low-level fetch and push channels.
- `persist` is the string keyspace; omission uses [Store.memory](api.html#store-memory).
- `lookup` may answer an unregistered query from a custom index as `partial` or certified `local`.
- `merge` reconciles remote values with local state in place and returns whether it succeeded.
- `expiry` controls how long unheld query records remain in local retention.

```typescript
const channels: StoreChannels<Card, Query> = { remote, persist, lookup, merge };
```

```rescript
let channels: TiliaQuery.Store.channels<query, card> = {remote, persist, lookup, merge}
```
