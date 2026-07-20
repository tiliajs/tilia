---
name: dismiss
slug: dismiss
kind: function
module: core
since: "0.1"
sort: 90
summary: Remove a resolved or ignored rejection context.
signature:
  ts: "dismiss: (rejection: Rejection<T>) => void"
  res: "dismiss: rejection<'a> => unit"
tags: []
---

`dismiss` removes the given [Rejection](api.html#rejection-type) from [status](api.html#status)`.rejected`.

A rejected operation has already left the outbox and remote truth has already replaced the optimistic value. Dismissing only retires the context after the application has resolved or intentionally ignored it; it does not retry a write or change collection data.

Keeping the local version is an ordinary [upsert](api.html#upsert), followed by `dismiss`. Keeping remote truth only needs `dismiss`.

See guide chapter [When the world returns](guide.html#when-the-world-returns). `cards` is the collection from [make](api.html#make).

```typescript
const [rejection] = cards.status.rejected;
if (rejection) cards.dismiss(rejection);
```

```rescript
switch cards.status.rejected[0] {
| Some(rejection) => cards.dismiss(rejection)
| None => ()
}
```
