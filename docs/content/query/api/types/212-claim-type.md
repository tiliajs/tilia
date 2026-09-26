---
name: Claim
slug: claim-type
kind: type
module: core
since: "0.1"
sort: 212
summary: State how complete and authoritative an answer is.
tags: []
signature.ts: 'type Claim = "partial" | "local" | "fresh"'
signature.res: |-
  type claim =
    | @as("partial") Partial
    | @as("local") Local
    | @as("fresh") Fresh
label: Claim
---

`Claim` describes an answer's strength:

- `partial` / `Partial` contains locally held rows without claiming they are the complete result.
- `local` / `Local` is a complete result according to local storage, but is not authoritative now.
- `fresh` / `Fresh` is complete and authoritative now. It may come from a synchronized local store; it does not mean “from the network.”

Remote answers raise a claim to `fresh`. Only [tick](api.html#tick) lowers a claim as data ages.

```typescript
// A badge under the deck: nothing for fresh, a word for what local storage
// could and could not promise.
const badge = (claim: Claim) =>
  claim === "fresh" ? "" : claim === "local" ? "as of last sync" : "some cards, maybe not all";
```

```rescript
// A badge under the deck: nothing for fresh, a word for what local storage
// could and could not promise.
let badge = claim =>
  switch claim {
  | Fresh => ""
  | Local => "as of last sync"
  | Partial => "some cards, maybe not all"
  }
```
