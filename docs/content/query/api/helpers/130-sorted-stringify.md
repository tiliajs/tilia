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
// Two views ask for the same deck with the keys in a different order. The
// default key sees one question: one find, one cached list, one identity.
const same = sortedStringify({ deck: "spanish", due: true }) === sortedStringify({ due: true, deck: "spanish" }); // true

// The same rule inside a custom `key`, for a query that carries a field the
// engine should not distinguish on.
const key = ({ label: _label, ...query }: DeckQuery & { label: string }) => sortedStringify(query);
```

```rescript
// Two views ask for the same deck with the keys in a different order. The
// default key sees one question: one find, one cached list, one identity.
let same = sortedStringify({"deck": "spanish", "due": true}) === sortedStringify({"due": true, "deck": "spanish"}) // true

// The same rule inside a custom `key`, for a query that carries a field the
// engine should not distinguish on.
let key = (query: labelledQuery) => sortedStringify({deck: query.deck})
```
