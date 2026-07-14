---
name: Remote
slug: remote-type
kind: type
module: core
since: "0.1"
sort: 240
summary: Remote adaptor — the authoritative store behind the network.
signature:
  ts: |-
    type Remote<T, Q> = {
      online: Signal<boolean>,
      fetch: (query: Q, channel: ReadChannel<T>) => void,
      push: (ops: Op<T>[], channel: WriteChannel<T>) => void
    }
  res: |-
    type remote<'a, 'query> = {
      online: Tilia.signal<bool>,
      fetch: ('query, Channel.read<'a>) => unit,
      push: (array<op<'a>>, Channel.write<'a>) => unit,
    }
tags: []
---

`Remote` wires the authoritative store into [make](api.html#make). The library owns the lifecycle; the adaptor owns the transport.

`online` is the connectivity signal, owned by the app: set `online.value` as connectivity changes. The engine reacts to transitions:

- Flipping to `false` settles queries still `Loading` to `NotLocal`. An in-flight remote response may still land and is taken as-is; its freshness self-corrects on later ticks.
- Flipping to `true` pushes pending ops.

`fetch` answers a query through a [ReadChannel](api.html#read-channel-type):

- `channel.set` with the complete result set (one-shot; the engine refreshes periodically).
- Or `channel.live` when the adaptor keeps the result fresh itself (a subscription): register the teardown with `channel.finally`, call `channel.end` when the source shuts down. Going offline does not end a live query — the engine cannot know whether the transport survived, so ending is the adaptor's call.

`push` receives one ordered batch of every pending op not already in flight, with a [WriteChannel](api.html#write-channel-type):

- Confirm each op individually via `channel.set` / `channel.removed`.
- End with nothing (all confirmed), `channel.retry` (transient failure) or `channel.fail` (definitive).

See guide chapter [The channel boundary](docs.html#the-channel-boundary).

```typescript
import { signal } from "tilia";
import type { Remote } from "@tilia/query";

const [online, setOnline] = signal(navigator.onLine);
window.addEventListener("online", () => setOnline(true));
window.addEventListener("offline", () => setOnline(false));

const remote: Remote<Card, Query> = {
  online,
  fetch: (query, channel) =>
    api.select(query).then(channel.set, (e) => channel.fail(String(e))),
  push: (ops, channel) =>
    ops.forEach((op) =>
      op.op === "upsert"
        ? api.upsert(op.value).then(channel.set, (e) => channel.fail(String(e)))
        : api.remove(op.id).then(() => channel.removed(op.id))
    ),
};
```

```rescript
let (online, setOnline) = Tilia.signal(true)

let remote: TiliaQuery.remote<card, query> = {
  online,
  fetch: (query, channel) =>
    api.select(query)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(cards) => channel.set(cards)
      | Error(error) => channel.fail(error)
      }
    )
    ->ignore,
  push: (ops, channel) =>
    ops->Array.forEach(op =>
      switch op {
      | Upsert({value}) =>
        api.upsert(value)
        ->Promise.thenResolve(result =>
          switch result {
          | Ok(card) => channel.set(card)
          | Error(error) => channel.fail(error)
          }
        )
        ->ignore
      | Remove({id}) =>
        api.remove(id)->Promise.thenResolve(() => channel.removed(id))->ignore
      }
    ),
}
```
