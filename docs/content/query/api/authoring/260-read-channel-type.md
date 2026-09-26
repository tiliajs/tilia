---
name: ReadChannel
slug: read-channel-type
kind: type
module: core
since: "0.1"
sort: 260
summary: Answer and manage one remote find.
tags: []
signature.ts: |-
  type ReadChannel<T> = {
    fresh: (values: T[]) => void,
    live: (values: T[]) => void,
    fail: (message: string) => void,
    end: () => void,
    finally: (teardown: () => void) => void
  }
signature.res: |-
  type Channel.read<'a> = {
    fresh: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }
label: ReadChannel
---

`ReadChannel` is passed to [Remote.fetch](api.html#remote-type). Every value delivery is the complete query result and replaces its previous result.

- `fresh(values)` publishes an authoritative answer that the engine refreshes periodically.
- `live(values)` publishes the same `fresh` claim and declares that the source maintains it, so periodic refresh is skipped.
- `fail(message)` reports a failure without closing the find; a live source may recover.
- `end()` closes the find and returns a live query to periodic refresh.
- `finally(teardown)` registers cleanup run once when the find closes by
  ending, replacement, eviction, or disposal. The last registration wins;
  registering after the find already closed runs the teardown immediately.

Every other callback on a closed find is ignored.

```typescript
// One fetch, two kinds of server. A server that answers when asked gets
// `fresh`, and the engine refreshes on its own clock. A server that streams
// gets `live`: the find stays open, `fail` reports a hiccup without closing
// it, `end` hands the query back to periodic refresh, and `finally` is where
// the stream is closed — on eviction, on a superseding fetch, on dispose.
const fetch = (query: DeckQuery, channel: ReadChannel<Card>) => {
  if (!server.live) {
    server.fetch(query).then(channel.fresh, (error: Error) => channel.fail(error.message));
    return;
  }
  const feed = server.subscribe(query, channel.live);
  feed.onError((error) => channel.fail(error.message));
  feed.onClose(channel.end);
  channel.finally(feed.close);
};
```

```rescript
// One fetch, two kinds of server. A server that answers when asked gets
// `fresh`, and the engine refreshes on its own clock. A server that streams
// gets `live`: the find stays open, `fail` reports a hiccup without closing
// it, `end` hands the query back to periodic refresh, and `finally` is where
// the stream is closed — on eviction, on a superseding fetch, on dispose.
let fetch = (query, channel: Channel.read<card>) =>
  if !server.live {
    server.fetch(query)
    ->Promise.thenResolve(result =>
      switch result {
      | Ok(cards) => channel.fresh(cards)
      | Error(message) => channel.fail(message)
      }
    )
    ->ignore
  } else {
    let feed = server.subscribe(query, channel.live)
    feed.onError(message => channel.fail(message))
    feed.onClose(channel.end)
    channel.finally(feed.close)
  }
```
