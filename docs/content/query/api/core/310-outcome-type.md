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
reply({ outcome: "saved", value: saved });
```

```rescript
reply(Store.Outcome.Saved({value: saved}))
```
