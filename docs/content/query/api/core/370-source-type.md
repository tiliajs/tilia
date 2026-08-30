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
const forget = <T, Q>(source: Source<T, Q>, query: Q) => source.forget(query);
```

```rescript
let forget = (source: TiliaQuery.source<'query, 'a>, query) => source.forget(query)
```
