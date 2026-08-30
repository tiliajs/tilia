---
name: Reason
slug: reason-type
kind: type
module: core
since: "0.1"
sort: 214
summary: Explain why a read has no data.
tags: []
signature.ts: |-
  type Reason =
    | "offline"
    | { reason: "failed", message: string }
    | { reason: "noMatch", claim: Claim }
signature.res: |-
  @tag("reason")
  type reason =
    | @as("failed") Failed({message: string})
    | @as("offline") Offline
    | @as("noMatch") NoMatch({claim: claim})
label: Reason
---

`Reason` is the payload of `Loadable`'s `noData` state:

- `offline` / `Offline` means the store had no usable rows and no remote answer is currently possible.
- `failed` / `Failed` carries the store's read error message.
- `noMatch` / `NoMatch` means [one](api.html#one) received a complete empty answer. Its claim ages with the answer; it does not assert that a particular row does not exist.

```typescript
const message = (reason: Reason) =>
  reason === "offline" ? "offline" : reason.reason === "failed" ? reason.message : "no match";
```

```rescript
let message = reason =>
  switch reason {
  | Offline => "offline"
  | Failed({message}) => message
  | NoMatch(_) => "no match"
  }
```
