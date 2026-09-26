---
name: Store.make
slug: store-make
kind: function
module: core
since: "0.1"
sort: 150
summary: Build the shipped store from backend operations.
tags: []
signature.ts: "Store.make<T, Q>(config: StoreConfig<T, Q>): StoreFactory<T, Q, Store<T>>"
signature.res: "Store.make: Store.config<'query, 'a> => store<'query, 'a, Store.t<'a>>"
label: Store.make(config)
---

`Store.make` is the default high-level backend adapter. Its [StoreConfig](api.html#store-config-type) supplies one query operation and one operation for each write kind; the result is a [StoreFactory](api.html#store-factory-type) for the root [make](api.html#make).

Writes are issued one at a time in outbox order, each waiting for its [Outcome](api.html#outcome-type) or [Removal](api.html#removal-type). This preserves cascades and lets a `transient` response stop the batch before later operations are sent.

```typescript
// Three translations around an existing HTTP client. Ordering, batching and
// retry are the store's; this code only says what the backend answered.
const factory = Store.make<Card, DeckQuery>({
  find: (query, answer) =>
    api.get(`/decks/${query.deck}`).then(answer.fresh, (error: ApiError) => answer.fail(error.message)),
  upsert: (card, reply) =>
    api.put(`/cards/${card.id}`, card).then(
      (saved) => reply({ outcome: "saved", value: saved }),
      (error: ApiError) => {
        if (error.status === 409) reply({ outcome: "conflict", value: error.body });
        else if (error.status >= 500) reply("transient");
        else reply({ outcome: "rejected", message: error.message });
      },
    ),
  remove: (id, reply) =>
    api.delete(`/cards/${id}`).then(
      () => reply("removed"),
      (error: ApiError) => reply(error.status >= 500 ? "transient" : { outcome: "rejected", message: error.message }),
    ),
});
```

```rescript
// Three translations around an existing HTTP client. Ordering, batching and
// retry are the store's; this code only says what the backend answered.
let factory = Store.make({
  find: (query, answer) =>
    Api.get(`/decks/${query.deck}`)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(cards) => answer.fresh(cards)
      | Error(message) => answer.fail(message)
      }
    )
    ->ignore,
  upsert: (card, reply) =>
    Api.put(`/cards/${card.id}`, card)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(saved) => reply(Saved({value: saved}))
      | Error(Stale(theirs)) => reply(Conflict({value: theirs}))
      | Error(Refused(message)) => reply(Rejected({message: message}))
      | Error(Unavailable) => reply(Transient)
      }
    )
    ->ignore,
  remove: (id, reply) =>
    Api.delete(`/cards/${id}`)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok() => reply(Removed)
      | Error(Refused(message)) => reply(Rejected({message: message}))
      | Error(Stale(_)) => reply(Rejected({message: "changed on the server"}))
      | Error(Unavailable) => reply(Transient)
      }
    )
    ->ignore,
})
```
