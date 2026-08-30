---
name: Remote
slug: remote-type
kind: type
module: core
since: "0.1"
sort: 240
summary: Connect Store.custom to an authoritative remote backend.
tags: []
signature.ts: |-
  type Remote<T, Q> = {
    online: Signal<boolean>,
    fetch: (query: Q, channel: ReadChannel<T>) => void,
    push: (ops: Op<T>[], channel: WriteChannel<T>) => void
  }
signature.res: |-
  type remote<'query, 'a> = {
    online: Tilia.signal<bool>,
    fetch: ('query, Channel.read<'a>) => unit,
    push: (array<op<'a>>, Channel.write<'a>) => unit,
  }
label: Remote
---

`Remote` is the advanced channel adapter consumed by [Store.custom](api.html#store-custom).

- `online` is an application-owned reactive connectivity signal. Pending operations push only while it is true.
- `fetch` answers one query through a [ReadChannel](api.html#read-channel-type), using `fresh` for a complete current answer or `live` when the source maintains it.
- `push` receives an ordered batch of pending [Op](api.html#op-type) values and answers through a [WriteChannel](api.html#write-channel-type).

```typescript
const remote: Remote<Card, Query> = {
  online,
  fetch: (query, channel) => api.find(query).then(channel.fresh, (error) => channel.fail(String(error))),
  push,
};
```

```rescript
let remote: TiliaQuery.remote<query, card> = {
  online,
  fetch: (query, channel) => api.find(query)->Promise.thenResolve(channel.fresh)->ignore,
  push,
}
```
