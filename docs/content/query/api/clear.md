---
name: .clear
slug: clear
kind: function
module: core
since: "0.1"
sort: 130
summary: Empty memory state and the outbox, for logout or user switch.
signature:
  ts: "collection.clear(): void"
  res: "collection.clear: unit => unit"
tags: []
---

`clear` empties the object cache, every query, the outbox and [status](api.html#status), so the next user starts blank. The instance stays usable — new queries fetch as usual.

It deliberately does **not** touch the local database: the library never learned your storage, so wiping it belongs to the adapter that owns the schema. Pair `clear` with your store's own wipe on logout — forgetting the pairing is a privacy bug. See guide chapter [Onward](docs.html#onward).

```typescript
const logout = () => {
  cards.clear();
  localDb.wipe(); // the adapter's half of the job
};
```

```rescript
let logout = () => {
  cards.clear()
  LocalDb.wipe() // the adapter's half of the job
}
```
