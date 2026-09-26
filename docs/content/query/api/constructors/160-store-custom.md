---
name: Store.custom
slug: store-custom
kind: function
module: core
since: "0.1"
sort: 160
summary: Build the shipped store from advanced channels.
tags: []
signature.ts: "Store.custom<T, Q>(channels: StoreChannels<T, Q>): StoreFactory<T, Q, Store<T>>"
signature.res: "Store.custom: Store.channels<'query, 'a> => store<'query, 'a, Store.t<'a>>"
label: Store.custom(channels)
---

`Store.custom` is the lower-level adapter for a backend already expressed as [Remote](api.html#remote-type) read and write channels. It adds the shipped store's cache, outbox, merge, query registry, persistence, and application [Store](api.html#store-type) handle.

Use [Store.make](api.html#store-make) when the backend is more naturally described as individual `find`, `upsert`, and `remove` operations.

```typescript
// `custom` is for a backend that pushes. This fetch subscribes and keeps the
// result fresh itself; `finally` is where the subscription ends, whether the
// query was evicted, superseded or the app disposed.
const factory = Store.custom<Card, DeckQuery>({
  remote: {
    online: Store.online(),
    fetch: (query, channel) => {
      const feed = socket.subscribe(query, channel.live);
      channel.finally(feed.close);
    },
    push,
  },
  persist: indexeddb({ name: "flashcards" }),
});
```

```rescript
// `custom` is for a backend that pushes. This fetch subscribes and keeps the
// result fresh itself; `finally` is where the subscription ends, whether the
// query was evicted, superseded or the app disposed.
let factory = Store.custom({
  remote: {
    online: Store.online(),
    fetch: (query, channel) => {
      let feed = socket.subscribe(query, channel.live)
      channel.finally(feed.close)
    },
    push,
  },
  persist: TiliaQueryIndexedDb.make({name: "flashcards"}),
})
```
