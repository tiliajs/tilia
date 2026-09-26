---
name: IndexedDB make
slug: indexeddb-make
kind: function
module: core
since: "0.1"
sort: 400
summary: Create a Kv backed by IndexedDB.
tags: []
signature.ts: "function make(config: Config): Kv"
signature.res: "TiliaQueryIndexedDb.make: TiliaQueryIndexedDb.config => TiliaQueryStore.Kv.t"
label: IndexedDB make(config)
---

TypeScript exports `make` from `@tilia/query/indexeddb`; ReScript exposes it as `TiliaQueryIndexedDb.make`. It creates a [Kv](api.html#kv-type) using one object store and compound `[tag, key]` keys, so each tag is an IndexedDB range.

Calls made before the database opens wait for it. Writes are batched into one transaction, and any queued writes are flushed before a read answers.

```typescript
import { Store } from "@tilia/query";
import { make as indexeddb } from "@tilia/query/indexeddb";

// One database for the app, opened on first use; a read or write made before
// it opens waits for it. `onError` is the only place a database that will not
// open makes itself known: reads answer empty and writes are dropped.
const persist = indexeddb({
  name: "flashcards",
  onError: (error) => console.error("persistence lost", error),
});

const factory = Store.make<Card, DeckQuery>({ find, upsert, remove, persist });
```

```rescript
// One database for the app, opened on first use; a read or write made before
// it opens waits for it. `onError` is the only place a database that will not
// open makes itself known: reads answer empty and writes are dropped.
let persist = TiliaQueryIndexedDb.make({
  name: "flashcards",
  onError: error => Console.error2("persistence lost", error),
})

let factory = Store.make({find, upsert, remove, persist})
```
