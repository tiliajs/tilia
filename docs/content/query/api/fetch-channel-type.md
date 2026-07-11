---
name: FetchChannel
slug: fetch-channel-type
kind: type
module: core
since: "0.1"
sort: 240
summary: Read-path channel handed to local and remote fetch.
signature:
  ts: |-
    interface FetchChannel<T> {
      readonly state: "live" | "cancelled",
      set(rows: T[]): void,
      fail(message: string): void,
      covered(): void
    }
  res: |-
    type fetch<'a> = {
      state: state, // Live | Cancelled
      set: array<'a> => unit,
      fail: string => unit,
      covered: unit => unit,
    }
tags: []
---

A fetch reports its outcome by calling one named callback — never by returning or constructing a result value, so the contract reads identically from TypeScript and ReScript.

`set(rows)` delivers the answer: each call replaces the query's result with these complete rows — never a delta. It may be called repeatedly (cached rows now, fresh rows later, live updates forever). `covered()` says a delta-sync engine owns this query: mark it fresh, keep current data, expect no rows — and never reconcile or prune its rows; the engine keeps sole ownership. `fail(message)` is strictly a transport error — freshness is untouched so the next [tick](api.html#tick) retries, and the failure surfaces on [status](api.html#status). "The server says there are none" is `set([])`, never `fail`.

The core cancels a channel when its query is refetched or evicted; a cancelled channel turns every callback into a no-op, so late answers are harmless and adapters never check whether they are still wanted. See guide chapter [Reads answer twice](docs.html#reads-answer-twice).

```typescript
fetch(query: DeckQuery, channel: FetchChannel<Card>) {
  api.list(query.deck).then(
    (rows) => channel.set(rows),
    (err) => channel.fail(err.message)
  );
}
```

```rescript
let fetch = (query, channel: TiliaQuery.Channel.fetch<card>) =>
  Api.list(query.deck)
  ->Promise.thenResolve(rows => channel.set(rows))
  ->Promise.catch(err => Promise.resolve(channel.fail(Error.message(err))))
  ->ignore
```
