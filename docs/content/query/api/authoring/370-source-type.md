---
name: Source
slug: source-type
kind: type
module: core
since: "0.1"
sort: 370
summary: Define the store side of the engine-store seam.
tags: []
signature.ts: |-
  type Source<T, Q> = {
    online: Signal<boolean>,
    find: (query: Q, channel: ReadChannel<T> & LocalChannel<T>) => void,
    forget: (query: Q) => void,
    tick: () => void,
    dispose: () => void
  }
signature.res: |-
  type source<'query, 'a> = {
    online: Tilia.signal<bool>,
    find: ('query, Channel.find<'a>) => unit,
    forget: 'query => unit,
    tick: unit => unit,
    dispose: unit => unit,
  }
label: Source
---

`Source` is what a custom store returns to the engine:

- `online` states whether a remote answer is possible.
- `find` receives the combined [Channel.find](api.html#find-channel-type).
  There is one find per query regardless of how many storage tiers answer it,
  and another on each refresh.
- `forget` is called only when an idle query is evicted from memory.
- `tick` runs the store heartbeat after the engine heartbeat.
- `dispose` shuts the store down after the engine has closed all finds.

```typescript
// What the engine asks of a store, for one that keeps rows in memory and
// nothing else. It answers a find from the rows it placed, through the live
// objects; it has nothing to forget per query, nothing to do on a tick, and
// only the socket to close.
const source = (schema: Schema<Card, DeckQuery>, binding: Binding<Card>): Source<Card, DeckQuery> => ({
  online: Store.online(),
  find: (query, channel) =>
    channel.local(held.flatMap((id) => binding.item(id) ?? []).filter((card) => schema.matches(query, card))),
  forget: () => {},
  tick: () => {},
  dispose: () => socket.close(),
});
```

```rescript
// What the engine asks of a store, for one that keeps rows in memory and
// nothing else. It answers a find from the rows it placed, through the live
// objects; it has nothing to forget per query, nothing to do on a tick, and
// only the socket to close.
let source = (schema: schema<deckQuery, card>, binding: binding<card>): source<deckQuery, card> => {
  online: Store.online(),
  find: (query, channel) =>
    channel.local(
      held->Array.filterMap(id => binding.item(id))->Array.filter(card => schema.matches(query, card)),
    ),
  forget: _query => (),
  tick: () => (),
  dispose: () => socket.close(),
}
```
