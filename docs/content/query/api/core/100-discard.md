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
const rejection = store.status.rejected[0];
if (rejection) store.discard(rejection);
```

```rescript
switch store.status.rejected[0] {
| Some(rejection) => store.discard(rejection)
| None => ()
}
```
