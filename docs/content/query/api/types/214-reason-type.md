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
// The empty state is not one message. Offline invites waiting; a failure
// carries the store's words; no match means the deck is done — with the same
// claim its rows would have had.
const explain = (reason: Reason) => {
  if (reason === "offline") return "No connection yet. Cards will appear when it returns.";
  if (reason.reason === "failed") return reason.message;
  return reason.claim === "fresh" ? "Deck complete." : "Nothing here as of last sync.";
};
```

```rescript
// The empty state is not one message. Offline invites waiting; a failure
// carries the store's words; no match means the deck is done — with the same
// claim its rows would have had.
let explain = reason =>
  switch reason {
  | Offline => "No connection yet. Cards will appear when it returns."
  | Failed({message}) => message
  | NoMatch({claim: Fresh}) => "Deck complete."
  | NoMatch(_) => "Nothing here as of last sync."
  }
```
