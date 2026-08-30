---
name: Answer
slug: answer-type
kind: type
module: core
since: "0.1"
sort: 305
summary: Answer one Store.make backend find.
tags: []
signature.ts: |-
  type Answer<T> = {
    fresh: (values: T[]) => void,
    fail: (message: string) => void
  }
signature.res: |-
  type Store.answer<'a> = {
    fresh: array<'a> => unit,
    fail: string => unit,
  }
label: Answer
---

`Answer` is passed to `StoreConfig.find`. `fresh(values)` supplies the complete authoritative result set as of now; `fail(message)` reports a read failure.

The weaker `partial` and `local` claims are storage concerns and are not valid backend-find answers.

```typescript
const find = (query: Query, answer: Answer<Card>) =>
  api.find(query).then(answer.fresh, (error) => answer.fail(String(error)));
```

```rescript
let find = (query, answer: TiliaQuery.Store.answer<card>) =>
  api.find(query)->Promise.thenResolve(answer.fresh)->ignore
```
