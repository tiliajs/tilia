---
name: .status
slug: status
kind: type
module: core
since: "0.1"
sort: 110
summary: Reactive sync state — pending writes, refused writes, last fetch error.
signature:
  ts: |-
    collection.status: Status<T>

    interface Status<T> {
      readonly pending: number,
      readonly rejected: readonly Rejection<T>[],
      readonly error: FetchError | undefined
    }
  res: |-
    collection.status: status<'a>

    type status<'a> = {
      mutable pending: int,
      mutable rejected: array<rejection<'a>>,
      mutable error: option<fetchError>,
    }
tags: []
---

`status` is a field on the collection — a tilia object, so reading it from render code subscribes like any reactive value.

`pending` counts the writes waiting in the outbox. `rejected` holds writes permanently refused by the remote — each a `Rejection` with the `value`, whether it was a `deleted` operation, and the server's `message` — until [dismiss](api.html#dismiss) clears the list. `error` is the last remote fetch failure as a `FetchError` (`key`, `message`), cleared by the next successful fetch. See guide chapter [When the server disagrees](docs.html#when-the-server-disagrees).

```typescript
observe(() => {
  badge.textContent =
    cards.status.pending > 0 ? `syncing ${cards.status.pending}…` : "";
});
```

```rescript
observe(() => {
  badge.textContent =
    cards.status.pending > 0 ? `syncing ${cards.status.pending->Int.toString}…` : ""
})
```
