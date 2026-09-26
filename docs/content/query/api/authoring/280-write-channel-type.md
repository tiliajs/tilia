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
// One request per operation, in outbox order, each answered by name. A 409
// hands back the server's row: the write rebases through `merge` and goes
// again on a later tick. An outage says nothing about the writes and ends the
// push; whatever was not answered goes again later. Any other refusal is this
// one write's, and the next one is still sent.
const push = (ops: Op<Card>[], channel: WriteChannel<Card>) => {
  const next = async (index: number): Promise<void> => {
    const op = ops[index];
    if (!op) return;
    try {
      if (op.op === "remove") {
        await api.delete(`/cards/${op.id}`);
        channel.removed(op.id);
      } else {
        channel.set(await api.put(`/cards/${op.value.id}`, op.value));
      }
    } catch (e) {
      const error = e as ApiError;
      if (error.status === 409 && op.op === "upsert") channel.conflict(error.body);
      else if (error.status >= 500) return channel.retry();
      else channel.reject(op.op === "remove" ? op.id : op.value.id, error.message);
    }
    return next(index + 1);
  };
  void next(0);
};
```

```rescript
// One request per operation, in outbox order, each answered by name. A
// conflict hands back the server's row: the write rebases through `merge` and
// goes again on a later tick. An outage says nothing about the writes and
// ends the push; whatever was not answered goes again later. Any other
// refusal is this one write's, and the next one is still sent.
let push = (ops, channel: Channel.write<card>) => {
  let rec next = index =>
    switch ops[index] {
    | None => ()
    | Some(Remove({id})) =>
      Api.delete(`/cards/${id}`)
      ->Promise.thenResolve(result =>
        switch result {
        | Ok() =>
          channel.removed(id)
          next(index + 1)
        | Error(Unavailable) => channel.retry()
        | Error(Refused(message)) =>
          channel.reject(id, message)
          next(index + 1)
        | Error(Stale(_)) =>
          channel.reject(id, "changed on the server")
          next(index + 1)
        }
      )
      ->ignore
    | Some(Upsert({value})) =>
      Api.put(`/cards/${value.id}`, value)
      ->Promise.thenResolve(result =>
        switch result {
        | Ok(saved) =>
          channel.set(saved)
          next(index + 1)
        | Error(Stale(theirs)) =>
          channel.conflict(theirs)
          next(index + 1)
        | Error(Unavailable) => channel.retry()
        | Error(Refused(message)) =>
          channel.reject(value.id, message)
          next(index + 1)
        }
      )
      ->ignore
    }
  next(0)
}
```
