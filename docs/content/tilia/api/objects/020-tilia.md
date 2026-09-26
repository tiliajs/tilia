---
name: tilia
slug: tilia
kind: function
module: core
since: "2.0"
sort: 20
summary: Wrap an object or array in a reactive proxy.
tags: []
signature.ts: "function tilia<T>(branch: T): T"
signature.res: "let tilia: 'a => 'a"
label: tilia(branch)
---

`tilia` converts a plain object or array into a proxy that tracks property reads and writes. The return value keeps the same shape and type as the input.

Nested plain objects and arrays are proxied lazily when read. Values with non-plain prototypes (for example, class instances) are returned as-is. Calling `tilia` on a value that is not an object or array throws. Calling `tilia` on an already proxied value returns the same proxy.

Writing the same value (or the same underlying target object) does not notify observers. See also [observe](api.html#observe), [computed](api.html#computed), and the guide chapter [A Living Object](guide.html#a-living-object).

```typescript
import { tilia } from "tilia";

// A card is a plain object until it is wrapped, and still one afterwards:
// same shape, same type. What changes is that reads inside `observe` or
// `computed` are recorded per key, and a write notifies only those readers.
const card = tilia({
  front: "gato",
  back: "cat",
  interval: 3,
  lastReview: "2026-07-12",
});

// A review writes two fields. Whatever reads `interval` or `lastReview`
// follows; whatever reads only `front` is left alone.
card.interval = 6;
card.lastReview = "2026-07-15";

// Nested objects and arrays are wrapped on first read, so a deck is one call.
const deck = tilia({ name: "spanish", cards: [card] });
```

```rescript
open Tilia

// A card is a plain record until it is wrapped, and still one afterwards:
// same shape, same type. What changes is that reads inside `observe` or
// `computed` are recorded per key, and a write notifies only those readers.
let card = tilia({
  front: "gato",
  back: "cat",
  interval: 3,
  lastReview: "2026-07-12",
})

// A review writes two fields. Whatever reads `interval` or `lastReview`
// follows; whatever reads only `front` is left alone.
card.interval = 6
card.lastReview = "2026-07-15"

// Nested records and arrays are wrapped on first read, so a deck is one call.
let deck = tilia({name: "spanish", cards: [card]})
```
