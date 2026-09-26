---
name: Outcome
slug: outcome-type
kind: type
module: core
since: "0.1"
sort: 310
summary: Classify one Store.make upsert result.
tags: []
signature.ts: |-
  type Outcome<T> =
    | { outcome: "saved", value: T }
    | { outcome: "conflict", value: T }
    | { outcome: "rejected", message: string }
    | "transient"
signature.res: |-
  type Store.Outcome.t<'a> =
    | @as("saved") Saved({value: 'a})
    | @as("conflict") Conflict({value: 'a})
    | @as("rejected") Rejected({message: string})
    | @as("transient") Transient
label: Outcome
---

`Outcome` is returned through `StoreConfig.upsert`'s reply:

- `saved` / `Saved` confirms the operation with the authoritative value.
- `conflict` / `Conflict` supplies the backend value. An accepted `merge`
  rebases the operation and keeps it pending; a declined or missing merge
  places remote truth and records a conflict rejection.
- `rejected` / `Rejected` definitively refuses only this operation and records the message.
- `transient` / `Transient` says nothing about the write. Processing stops and this and later operations retry.

```typescript
// What became of one write, in the backend's terms. A 409 carries the row the
// server holds: `conflict` keeps the write pending, so it rebases through
// `merge` and goes again. An outage is `transient`: nothing is said about the
// write, and the batch stops here. Anything else refuses this write alone.
const upsert = (card: Card, reply: (outcome: Outcome<Card>) => void) =>
  api.put(`/cards/${card.id}`, card).then(
    (saved) => reply({ outcome: "saved", value: saved }),
    (error: ApiError) => {
      if (error.status === 409) reply({ outcome: "conflict", value: error.body });
      else if (error.status >= 500) reply("transient");
      else reply({ outcome: "rejected", message: error.message });
    },
  );
```

```rescript
// What became of one write, in the backend's terms. A conflict carries the row
// the server holds: `Conflict` keeps the write pending, so it rebases through
// `merge` and goes again. An outage is `Transient`: nothing is said about the
// write, and the batch stops here. Anything else refuses this write alone.
let upsert = (card, reply: Store.Outcome.t<card> => unit) =>
  Api.put(`/cards/${card.id}`, card)
  ->Promise.thenResolve(result =>
    switch result {
    | Ok(saved) => reply(Saved({value: saved}))
    | Error(Stale(theirs)) => reply(Conflict({value: theirs}))
    | Error(Unavailable) => reply(Transient)
    | Error(Refused(message)) => reply(Rejected({message: message}))
    }
  )
  ->ignore
```
