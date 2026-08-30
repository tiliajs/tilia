---
name: sortedStringify
slug: sorted-stringify
kind: function
module: core
since: "0.1"
sort: 130
summary: Deterministically serialize plain JSON data.
tags: []
signature.ts: "function sortedStringify(value: unknown): string"
signature.res: "let sortedStringify: 'a => string"
label: sortedStringify(value)
---

`sortedStringify` serializes JSON with object keys sorted at every level. It is the default query key used by [make](api.html#make), so structurally equal plain-data queries share an entry regardless of property order.

It does not support functions or cycles.

```typescript
sortedStringify({ deck: "es", due: true }) ===
  sortedStringify({ due: true, deck: "es" }); // true
```

```rescript
sortedStringify({"deck": "es", "due": true}) ===
sortedStringify({"due": true, "deck": "es"}) // true
```
