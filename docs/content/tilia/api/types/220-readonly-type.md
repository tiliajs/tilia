---
name: Readonly
slug: readonly-type
kind: type
module: core
since: "2.0"
sort: 220
summary: Wrapper type exposing immutable data through a data field.
tags: []
signature.ts: "type Readonly<T> = { readonly data: T }"
signature.res: "type readonly<'a> = {data: 'a}"
label: Readonly
---

The `Readonly<T>`/`readonly<'a>` type is the wrapper produced by [readonly](api.html#readonly).

It exposes `data` and prevents replacing the `data` property itself.

The wrapped value is not proxied for nested tracking.

```typescript
import type { Readonly } from "tilia";

// A parameter typed `Readonly<DeckInfo[]>` says two things: this code pays no
// tracking for the catalogue, and nobody can replace `data` under it.
const search = (catalogue: Readonly<DeckInfo[]>, term: string) =>
  catalogue.data.filter((deck) => deck.name.includes(term));
```

```rescript
open Tilia

// A parameter typed `readonly<array<deckInfo>>` says two things: this code
// pays no tracking for the catalogue, and nobody can replace `data` under it.
let search = (catalogue: readonly<array<deckInfo>>, term) =>
  catalogue.data->Array.filter(deck => deck.name->String.includes(term))
```
