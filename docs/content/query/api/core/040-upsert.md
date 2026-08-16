---
name: upsert
slug: upsert
kind: function
module: core
since: "0.1"
sort: 40
summary: Write a value optimistically and queue it for the remote.
tags: []
signature.ts: "upsert: (value: T) => void"
signature.res: "upsert: 'a => unit"
label: upsert
---

`upsert` writes a value: it is applied locally and persisted, and its op is queued in the outbox for [Remote.push](api.html#remote-type). The write is optimistic — local state changes before the remote confirms.

What happens immediately:

- Memory and the local store receive the new value.
- The value joins every in-memory query result whose `matches` accepts it, and leaves every result it no longer matches — moving a card between decks updates both queries at once.
- Both changes reach the affected queries' persisted records. Records that exist only on disk are not scanned; they catch up on the query's next refresh.
- The op is appended to the outbox and counted in [status](api.html#status)`.pending`.

Edge cases:

- If no persisted query record lists the id after the join, a synthetic record keeps the row alive through the local purge. The next purge offers such a row to every persisted query; a match adopts it.
- Confirmation replaces the local value with the authoritative one from [WriteChannel](api.html#write-channel-type)`.set` — the server may have corrected it.
- A definitive push failure reverts the optimistic value to remote truth and adds context to `status.rejected`; resolve or ignore it, then [dismiss](api.html#dismiss) it.

`cards` below is the collection from [make](api.html#make). See guide chapter [Tunnels](guide.html#tunnels).

```typescript
cards.upsert({ id: "cat", deck: "es", english: "cat", translation: "gato" });
```

```rescript
cards.upsert({id: "cat", deck: "es", english: "cat", translation: "gato"})
```
