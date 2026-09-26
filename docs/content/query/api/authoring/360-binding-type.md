---
name: Binding
slug: binding-type
kind: type
module: core
since: "0.1"
sort: 360
summary: Let a custom store update engine rows safely.
tags: []
signature.ts: |-
  type Binding<T> = {
    item: (id: string) => T | undefined,
    changed: (values: T[]) => void,
    removed: (ids: string[]) => void,
    place: (value: T) => void
  }
signature.res: |-
  type binding<'a> = {
    item: string => option<'a>,
    changed: array<'a> => unit,
    removed: array<string> => unit,
    place: 'a => unit,
  }
label: Binding
---

`Binding` is passed to a custom [StoreFactory](api.html#store-factory-type):

- `item(id)` returns the canonical live object when present. A merge may mutate that object in place; a store must not keep another canonical copy.
- `changed(values)` applies remote truth and retains rows only while an in-memory query matches.
- `removed(ids)` applies remote deletions.
- `place(value)` applies an optimistic value and keeps its row even when no current query lists it.

Insertions and deletions remain controlled by these methods rather than direct access to the row table.

```typescript
// A store of your own, fed by a socket. Rows arrive as facts: `changed` places
// remote truth and keeps a row only while some open deck wants it; `removed`
// drops it everywhere. A write goes through `place`, which keeps its row even
// before any deck lists it, and the server answers through the same socket.
// `item` reads the live object, so a partial update can start from it.
const factory: StoreFactory<Card, DeckQuery, { write: (card: Card) => void }> = (schema, binding) => {
  socket.on("cards:changed", (rows: Card[]) => binding.changed(rows));
  socket.on("cards:removed", (ids: string[]) => binding.removed(ids));
  socket.on("cards:seen", ({ id, seen }: { id: string; seen: number }) => {
    const card = binding.item(id);
    if (card) binding.changed([{ ...card, seen }]);
  });
  const write = (card: Card) => {
    binding.place(card);
    socket.send("cards:save", card);
  };
  return [source(schema, binding), { write }];
};
```

```rescript
// A store of your own, fed by a socket. Rows arrive as facts: `changed` places
// remote truth and keeps a row only while some open deck wants it; `removed`
// drops it everywhere. A write goes through `place`, which keeps its row even
// before any deck lists it, and the server answers through the same socket.
// `item` reads the live object, so a partial update can start from it.
let factory: store<deckQuery, card, writer> = (schema, binding) => {
  socket.on("cards:changed", rows => binding.changed(rows))
  socket.on("cards:removed", ids => binding.removed(ids))
  socket.on("cards:seen", (seen: seenEvent) =>
    switch binding.item(seen.id) {
    | Some(card) => binding.changed([{...card, seen: seen.seen}])
    | None => ()
    }
  )
  let write = card => {
    binding.place(card)
    socket.send("cards:save", card)
  }
  (source(schema, binding), {write: write})
}
```
