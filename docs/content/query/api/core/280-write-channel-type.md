---
name: WriteChannel
slug: write-channel-type
kind: type
module: core
since: "0.1"
sort: 280
summary: Answer operations in a Remote.push batch.
tags: []
signature.ts: |-
  type WriteChannel<T> = {
    set: (value: T) => void,
    removed: (id: string) => void,
    conflict: (value: T) => void,
    reject: (id: string, message: string) => void,
    retry: () => void,
    fail: (message: string) => void
  }
signature.res: |-
  type Channel.write<'a> = {
    set: 'a => unit,
    removed: string => unit,
    conflict: 'a => unit,
    reject: (string, string) => unit,
    retry: unit => unit,
    fail: string => unit,
  }
label: WriteChannel
---

`WriteChannel` answers the ordered operations passed to [Remote.push](api.html#remote-type).

- `set(value)` confirms one upsert with its authoritative value.
- `removed(id)` confirms one remove.
- `conflict(value)` supplies the server row. If `merge` accepts it, the
  operation is rebased and stays pending; otherwise remote truth is placed,
  the operation leaves the outbox, and a conflict rejection is recorded.
- `reject(id, message)` definitively refuses one operation.
- `retry()` ends the push without deciding any unanswered operation; they remain pending.
- `fail(message)` definitively rejects every unanswered operation. Earlier answers stand.

`set` and `conflict` match operations by `id(value)`, so the backend must
preserve client ids. Per-operation callbacks answer only their matching
operation; a successfully merged conflict leaves that operation unsettled
for a later push.

The first `retry()` or `fail()` closes the push. Every later callback on that
channel, including a delayed per-operation answer, is ignored.

```typescript
const answer = (value: Card, channel: WriteChannel<Card>) =>
  value.version > 1 ? channel.conflict(value) : channel.set(value);
```

```rescript
let answer = (value, channel: TiliaQuery.Channel.write<card>) =>
  value.version > 1 ? channel.conflict(value) : channel.set(value)
```
