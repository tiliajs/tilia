---
name: sortedStringify
slug: sorted-stringify
kind: function
module: core
since: "0.1"
sort: 130
summary: Deterministic JSON serialization — the default query key.
signature:
  ts: "function sortedStringify(value: unknown): string"
  res: "let sortedStringify: 'a => string"
tags: []
---

`sortedStringify` serializes a value to JSON with sorted keys at every level, so two structurally equal queries produce the same string regardless of key order.

It is the default `key` in [make](api.html#make): the string identifies a query in memory and in the persisted query registry.

Only meaningful on plain data — no functions, no cycles. This is the same constraint the local purge puts on queries anyway: persisted records carry their query through a JSON round trip.

See guide chapter [A shape for queries](guide.html#a-shape-for-queries).

```typescript
import { sortedStringify } from "@tilia/query";

sortedStringify({ deck: "es", seen: false }) ===
  sortedStringify({ seen: false, deck: "es" }); // true
```

```rescript
open TiliaQuery

let same =
  sortedStringify({"deck": "es", "seen": false}) ===
  sortedStringify({"seen": false, "deck": "es"}) // true
```
