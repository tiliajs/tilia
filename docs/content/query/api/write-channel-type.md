---
name: WriteChannel
slug: write-channel-type
kind: type
module: core
since: "0.1"
sort: 250
summary: Write-path channel handed to remote upsert and remove.
signature:
  ts: |-
    interface WriteChannel<T> {
      readonly state: "live" | "cancelled",
      saved(value: T): void,
      offline(): void,
      conflict(server: T): void,
      rejected(message: string): void
    }
  res: |-
    type write<'a> = {
      state: state, // Live | Cancelled
      saved: 'a => unit,
      offline: unit => unit,
      conflict: 'a => unit,
      rejected: string => unit,
    }
tags: []
---

Each callback encodes a different relationship between the device's claim and the server's. `saved(value)` is agreement: the write settles clean with the server's (possibly enriched) value. `offline()` is no verdict: the write stays queued and dirty for the next reconnect. `conflict(server)` means the server wins and says with what — resolved into cache and store, no retry. `rejected(message)` is permanent refusal: the write is dropped, surfaced on [status](api.html#status), and queries refetch to converge; a rejected or conflicted delete resurrects the row.

`conflict` discards the local edit, so it is the right verdict only when losing it is acceptable. If conflicts are expected in your domain, keep the *original* (last server-confirmed) value on the row: the adapter can then 3-way merge and settle `saved` with the result, or settle `saved` with the local value and a conflict flag carrying the server and original values for user resolution. The pattern is worked through in [When the server disagrees](docs.html#when-the-server-disagrees).

Channels are cancelled when a newer write to the same id takes over — latest write wins, including the right to hear the server's reply. A cancelled channel ignores every callback. See guide chapter [When the server disagrees](docs.html#when-the-server-disagrees).

```typescript
upsert(card: Card, channel: WriteChannel<Card>) {
  api.save(card).then(channel.saved, (err) =>
    err.status === 409
      ? channel.conflict(err.serverValue)
      : err.status === 403
        ? channel.rejected(err.message)
        : channel.offline()
  );
}
```

```rescript
let upsert = (card, channel: TiliaQuery.Channel.write<card>) =>
  Api.save(card)
  ->Promise.thenResolve(saved => channel.saved(saved))
  ->Promise.catch(err =>
    Promise.resolve(
      switch Api.status(err) {
      | 409 => channel.conflict(Api.serverValue(err))
      | 403 => channel.rejected(Error.message(err))
      | _ => channel.offline()
      },
    )
  )
  ->ignore
```
