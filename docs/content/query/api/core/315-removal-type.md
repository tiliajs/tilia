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
reply("removed");
```

```rescript
reply(Store.Removal.Removed)
```
