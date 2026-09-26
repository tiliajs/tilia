---
name: Removal
slug: removal-type
kind: type
module: core
since: "0.1"
sort: 315
summary: Classify one Store.make remove result.
tags: []
signature.ts: |-
  type Removal =
    | "removed"
    | { outcome: "rejected", message: string }
    | "transient"
signature.res: |-
  type Store.Removal.t =
    | @as("removed") Removed
    | @as("rejected") Rejected({message: string})
    | @as("transient") Transient
label: Removal
---

`Removal` is returned through `StoreConfig.remove`'s reply:

- `removed` / `Removed` confirms the deletion.
- `rejected` / `Rejected` definitively refuses it and records the message
  when the store has a base value for the remove. An unknown-id remove is
  cleared without a rejection because `removeFailed` requires that base.
- `transient` / `Transient` leaves it unanswered, stops processing, and retries it later.

It is separate from [Outcome](api.html#outcome-type), preventing an upsert-only result from answering a remove.

```typescript
// What became of one remove. `removed` confirms it; a refusal brings the card
// back with a rejection holding the removed value; `transient` stops the batch
// and the remove goes again later. There is no `saved` to answer a remove
// with by mistake: this is its own type.
const remove = (id: string, reply: (outcome: Removal) => void) =>
  api.delete(`/cards/${id}`).then(
    () => reply("removed"),
    (error: ApiError) => reply(error.status >= 500 ? "transient" : { outcome: "rejected", message: error.message }),
  );
```

```rescript
// What became of one remove. `Removed` confirms it; a refusal brings the card
// back with a rejection holding the removed value; `Transient` stops the batch
// and the remove goes again later. There is no `Saved` to answer a remove
// with by mistake: this is its own type.
let remove = (id, reply: Store.Removal.t => unit) =>
  Api.delete(`/cards/${id}`)
  ->Promise.thenResolve(result =>
    switch result {
    | Ok() => reply(Removed)
    | Error(Unavailable) => reply(Transient)
    | Error(Refused(message)) => reply(Rejected({message: message}))
    | Error(Stale(_)) => reply(Rejected({message: "changed on the server"}))
    }
  )
  ->ignore
```
