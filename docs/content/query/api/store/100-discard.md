---
name: discard
slug: discard
kind: function
module: core
since: "0.1"
sort: 100
summary: Drop one rejection without retrying it.
tags: []
signature.ts: "discard: (rejection: Rejection<T>) => void"
signature.res: "discard: rejection<'a> => unit"
label: store.discard(rejection)
---

`discard` removes the exact [Rejection](api.html#rejection-type) without changing rows or queueing work. Remote truth already stands when a rejection is created.

It acts only when the same rejection record is still present. A record already cleared or replaced is a no-op.

```typescript
// The panel's other button. Remote truth already stands — a rejection is
// recorded after the revert — so "keep theirs" only drops the record.
for (const rejection of store.status.rejected) {
  panel.row(describe(rejection), { keepTheirs: () => store.discard(rejection) });
}
```

```rescript
// The panel's other button. Remote truth already stands — a rejection is
// recorded after the revert — so "keep theirs" only drops the record.
store.status.rejected->Array.forEach(rejection =>
  panel.row(describe(rejection), ~keepTheirs=() => store.discard(rejection))
)
```
