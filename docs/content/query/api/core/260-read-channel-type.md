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
fetch: (query, channel) => {
  const feed = subscribe(query, channel.live);
  channel.finally(() => feed.close());
}
```

```rescript
fetch: (query, channel) => {
  let feed = subscribe(query, channel.live)
  channel.finally(() => feed.close())
}
```
