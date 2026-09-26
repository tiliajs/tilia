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
// A find answers once: the complete deck as of now, or why not. The weaker
// claims are not offered here — what the store already holds is its own
// business, and it has answered from it before this call was made.
const find = (query: DeckQuery, answer: Answer<Card>) =>
  api.get(`/decks/${query.deck}`).then(answer.fresh, (error: ApiError) => answer.fail(error.message));
```

```rescript
// A find answers once: the complete deck as of now, or why not. The weaker
// claims are not offered here — what the store already holds is its own
// business, and it has answered from it before this call was made.
let find = (query, answer: Store.answer<card>) =>
  Api.get(`/decks/${query.deck}`)
  ->Promise.thenResolve(result =>
    switch result {
    | Ok(cards) => answer.fresh(cards)
    | Error(message) => answer.fail(message)
    }
  )
  ->ignore
```
