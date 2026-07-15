---
name: WriteChannel
slug: write-channel-type
kind: type
module: core
since: "0.1"
sort: 280
summary: Channel handed to remote.push — confirm, retry or fail a batch.
signature:
  ts: |-
    type WriteChannel<T> = {
      set: (value: T) => void,
      removed: (id: string) => void,
      retry: () => void,
      fail: (message: string) => void
    }
  res: |-
    type write<'a> = {
      set: 'a => unit,
      removed: string => unit,
      retry: unit => unit,
      fail: string => unit,
    }
tags: []
---

`WriteChannel` is handed to [Remote.push](api.html#remote-type) together with a batch of ops.

Per-op confirmations — call one per op, matched by the value's id:

- `set` — confirms an upsert. Pass the **authoritative** value: echo the input, or the server-corrected / conflict-resolved version. Whatever is set replaces the local value and drops the op from the outbox.
- `removed` — confirms a remove, by id.

Batch endings:

- Nothing — every op confirmed; the batch is done.
- `retry` — transient failure (offline, timeout). Every op not yet confirmed stays pending and is pushed again on a later [tick](api.html#tick) or when `remote.online` flips back to true.
- `fail` — definitive refusal. Every op not yet confirmed becomes a [Rejection](api.html#rejection-type) in [status](api.html#status)`.rejected`.

The first definitive call wins; everything on the channel is a noop afterwards. Ops confirmed before a `fail` have already left the outbox and are not rejected.

See guide chapter [Writing without waiting](guide.html#writing-without-waiting).

```typescript
// Confirm op by op; report the first server error as definitive.
const push = async (ops: Op<Card>[], channel: WriteChannel<Card>) => {
  for (const op of ops) {
    try {
      if (op.op === "upsert") channel.set(await api.upsert(op.value));
      else {
        await api.remove(op.id);
        channel.removed(op.id);
      }
    } catch (e) {
      return channel.fail(String(e));
    }
  }
};
```

```rescript
// Confirm op by op; report the first server error as definitive.
// After a `fail`, the remaining calls on the channel are noops.
let push = (ops, channel: TiliaQuery.Channel.write<card>) =>
  ops->Array.forEach(op =>
    switch op {
    | TiliaQuery.Upsert({value}) =>
      api.upsert(value)
      ->Promise.thenResolve(result =>
        switch result {
        | Ok(card) => channel.set(card)
        | Error(error) => channel.fail(error)
        }
      )
      ->ignore
    | TiliaQuery.Remove({id}) =>
      api.remove(id)
      ->Promise.thenResolve(result =>
        switch result {
        | Ok() => channel.removed(id)
        | Error(error) => channel.fail(error)
        }
      )
      ->ignore
    }
  )
```
