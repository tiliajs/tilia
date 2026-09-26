---
name: readonly
slug: readonly
kind: function
module: core
since: "2.0"
sort: 120
summary: Wrap data in a non-writable holder to avoid nested tracking.
tags: []
signature.ts: "function readonly<T>(data: T): Readonly<T>"
signature.res: "let readonly: 'a => readonly<'a>"
label: readonly(data)
---

`readonly` returns an object with a non-writable `data` property. The wrapped value is returned as-is and is not proxied for nested tracking.

Use `readonly` to insert large immutable data blocks into a reactive tree while preventing accidental replacement of the wrapped `data` field.

See [tilia](api.html#tilia) and the guide chapter [A small vocabulary](guide.html#a-small-vocabulary).

```typescript
import { readonly, tilia } from "tilia";

// The deck catalogue Alice browses: hundreds of decks, never updated. Wrapped
// in `readonly`, it rides inside the reactive app without being tracked or
// proxied, and `data` cannot be swapped out from under a reader.
const app = tilia({
  current: "spanish",
  catalogue: readonly(allDecks),
});

const names = app.catalogue.data.map((deck) => deck.name); // plain array, plain objects
```

```rescript
open Tilia

// The deck catalogue Alice browses: hundreds of decks, never updated. Wrapped
// in `readonly`, it rides inside the reactive app without being tracked or
// proxied, and `data` cannot be swapped out from under a reader.
let app = tilia({
  current: "spanish",
  catalogue: readonly(allDecks),
})

let names = app.catalogue.data->Array.map(deck => deck.name) // plain array, plain records
```
