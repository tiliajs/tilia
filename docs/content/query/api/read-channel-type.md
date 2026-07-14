---
name: ReadChannel
slug: read-channel-type
kind: type
module: core
since: "0.1"
sort: 260
summary: Channel handed to remote.fetch — set, live, fail, end, finally.
signature:
  ts: |-
    type ReadChannel<T> = {
      set: (values: T[]) => void,
      live: (values: T[]) => void,
      fail: (message: string) => void,
      end: () => void,
      finally: (fn: () => void) => void
    }
  res: |-
    type read<'a> = {
      set: array<'a> => unit,
      live: array<'a> => unit,
      fail: string => unit,
      end: unit => unit,
      finally: (unit => unit) => unit,
    }
tags: []
---

`ReadChannel` is handed to [Remote.fetch](api.html#remote-type). Every delivery is the query's **complete** result set — each call replaces the previous results.

- `set` — publish results. The idiomatic "I am keeping this value fresh" call: invoke it again whenever fresher results arrive. A `set`-only query is refreshed periodically by the engine.
- `live` — publish results and declare that the adaptor keeps them fresh on its own (e.g. a server subscription). Call it again on every update; `expiry.refresh` skips a live query.
- `fail` — publish a failed result. It does **not** close the fetch: a live source may recover by delivering again. A failed non-live query re-enters the refresh loop and is retried once per refresh window.
- `end` — the stream is over. Valid after `set` or `live`; not a substitute for `fail`. It closes the fetch: the registered `finally` runs, and a live query becomes a normal remote result again, re-entering periodic refresh.
- `finally` — register the fetch's teardown (e.g. unsubscribe a socket). One slot, last write wins.

The teardown contract:

- The engine runs the registered `finally` exactly once, when the fetch closes: on `end`, when a newer fetch supersedes this one, when the query is evicted from memory, or on [dispose](api.html#dispose).
- Registering on an already closed fetch runs the function immediately — a source that ends synchronously inside `fetch` is still torn down.

Every callback on a closed fetch is a noop. The engine suppresses late replies from ended, superseded or evicted fetches — adaptors do not need to.

See guide chapter [The channel boundary](docs.html#the-channel-boundary).

```typescript
// A subscription source answering through `live`.
fetch: (query: Query, channel: ReadChannel<Card>) => {
  const feed = subscribe(query, {
    data: (rows: Card[]) => channel.live(rows),
    error: (e: unknown) => channel.fail(String(e)),
    closed: () => channel.end(),
  });
  channel.finally(() => feed.unsubscribe());
}
```

```rescript
// A subscription source answering through `live`.
let fetch = (query: query, channel: TiliaQuery.Channel.read<card>) => {
  let feed = subscribe(
    query,
    ~data=rows => channel.live(rows),
    ~error=message => channel.fail(message),
    ~closed=() => channel.end(),
  )
  channel.finally(() => feed.unsubscribe())
}
```
