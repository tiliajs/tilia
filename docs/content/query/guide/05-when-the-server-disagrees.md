---
title: When the server disagrees
slug: when-the-server-disagrees
sort: 5
refs: [changed, removed, status, dismiss, write-channel-type, remote-type]
---

Optimistic writes make a promise the server hasn't confirmed. Most of the time it simply agrees. This chapter is about the other times — and about the fourth kind of update, the one that arrives without being asked for.

### Four answers to a write

The remote adapter settles each write through a channel with four named callbacks. Each one encodes a different relationship between the device's claim and the server's:

- `saved(value)` — agreement. The write settles clean: the saved value (which the server may have enriched — timestamps, versions) replaces the optimistic one in cache and local store.
- `offline()` — no verdict. The write stays queued and dirty, and the next reconnect retries it. This is the transient-failure exit, the write path's counterpart of `fail`.
- `conflict(server)` — the server wins, and says with what. The server's value is resolved into the cache and saved clean; the optimistic value is gone. The write is settled — there is no retry, because there is nothing left to say.
- `rejected(message)` — permanent refusal. The write is dropped, and the refusal is surfaced.

The first three resolve silently, because they end in a consistent state the UI already knows how to render. Only `rejected` creates a situation the *user* may need to know about: something they did was undone. Note that `conflict` also undoes the user's edit — silently. If conflicts are an accident in your domain, that is fine; if they are expected, the adapter should resolve them instead of reporting them, and a section below shows how.

### Rejection restores truth, then reports

A rejected write leaves an uncomfortable hole: the optimistic value was applied everywhere, and it turned out to be false. The library responds in two moves. The rejection is appended to `status.rejected` — value, whether it was a delete, and the server's message — where the UI can show it until `dismiss()` clears the list. And the caches converge back to server truth: queries refetch, because a value that optimistically moved between lists may have left lists it still belongs to.

Deletes get the symmetric treatment: a rejected or conflicted delete *resurrects the row* — the server said it still exists, so it comes back to the cache and the local store, clean.

::: story
Alice's laptop, on wifi at home, edited *gato* an hour ago. Her phone's tunnel edit arrives second and the server declines it in favor of the laptop's. The card on her phone quietly becomes the laptop's version — same card, same lists, newer truth.
:::

### When conflicts are expected: keep the original

`conflict(server)` is honest but blunt: the local edit is discarded without a trace. When concurrent edits are a rare accident, that is the right verdict — convergence beats ceremony. But if your domain *expects* them — several devices, several people, long offline stretches — a write should never reach that verdict. Give `remote.upsert` what it needs to resolve the conflict itself: the **original**, the last server-confirmed value the edit was based on.

Store it on the row. Anything that lives inside the value rides the outbox and survives boot replay for free, because the outbox *is* the value:

- when the user edits, keep the current clean row under `original` before applying changes (and keep the *earliest* one across successive edits);
- on a successful PUT, the adapter settles `saved` with the value, `original` removed — the row is server truth again;
- on a version conflict, the adapter holds all three sides: `original` (base), the local value (ours), and the server's reply (theirs).

With three sides in hand, both exits preserve the user's work:

- **3-way merge** — merge in the adapter, or better on the server where it applies atomically against the authoritative version; retry the push and settle `saved(merged)`. The write settles clean and nobody lost anything.
- **User-based resolution** — when the merge cannot decide, settle `saved` with the local value and a **conflict flag** carrying the server and original values. The write settles, so the flagged row is saved clean and even survives a restart; the UI notices the flag, shows both versions, and the user's choice becomes a plain `upsert` with the flag cleared.

```typescript
type Card = {
  id: string;
  front: string;
  back: string;
  // last server-confirmed value, present while edits are unsynced
  original?: Card;
  // set by the adapter on an undecidable conflict, cleared by the user
  conflict?: { server: Card; original?: Card };
};

// editing: keep the base (the earliest one, across successive edits)
cards.upsert({ ...gato, back: "cat", original: gato.original ?? gato });
```

```rescript
type rec card = {
  id: string,
  front: string,
  back: string,
  // last server-confirmed value, present while edits are unsynced
  original?: card,
  // set by the adapter on an undecidable conflict, cleared by the user
  conflict?: conflict,
}
and conflict = {server: card, original?: card}

// editing: keep the base (the earliest one, across successive edits)
cards.upsert({...gato, back: "cat", original: gato.original->Option.getOr(gato)})
```

The adapter strips `original` from the payload, merges on a version conflict, and falls back to the flag when the merge has no answer:

```typescript
upsert(card, channel) {
  const { original, conflict, ...payload } = card;
  api.saveCard(payload).then(
    (saved) => channel.saved(saved), // original gone: server truth again
    (err) => {
      if (err.status === 403) return channel.rejected(err.message);
      if (err.status !== 409) return channel.offline();
      const merged = merge3(original, card, err.serverValue);
      if (merged) {
        api.saveCard(merged).then(channel.saved, () => channel.offline());
      } else {
        // undecidable: settle with a flag and let the user resolve
        channel.saved({ ...card, conflict: { server: err.serverValue, original } });
      }
    }
  );
}
```

```rescript
let upsert = (card, channel: TiliaQuery.Channel.write<card>) =>
  Api.saveCard(strip(card))
  ->Promise.thenResolve(saved => channel.saved(saved)) // original gone: server truth again
  ->Promise.catch(err =>
    Promise.resolve(
      switch Api.status(err) {
      | 403 => channel.rejected(Error.message(err))
      | 409 =>
        switch merge3(card.original, card, Api.serverValue(err)) {
        | Some(merged) => Api.saveCard(merged)->Promise.thenResolve(channel.saved)->ignore
        | None =>
          // undecidable: settle with a flag and let the user resolve
          channel.saved({
            ...card,
            conflict: {server: Api.serverValue(err), original: ?card.original},
          })
        }
      | _ => channel.offline()
      },
    )
  )
  ->ignore
```

Resolution is just another write: the user picks (or edits) a version, and the chosen value goes out with the flag cleared and the server's version as the new base:

```typescript
cards.upsert({ ...chosen, conflict: undefined, original: card.conflict.server });
```

```rescript
cards.upsert({...chosen, conflict: ?None, original: conflict.server})
```

::: pro
A merged retry can conflict again if the row is hot — bound the loop: after a second refusal, fall back to the flag rather than spinning. And `channel.conflict` keeps its role as the true last resort, for adapters and domains where losing the local edit is acceptable.
:::

### status: sync state as plain values

Everything the UI might want to say about synchronization lives on one reactive object:

```typescript
const { pending, rejected, error } = cards.status;
// pending: writes waiting to sync
// rejected: refusals to show, until dismiss()
// error: last remote fetch failure, cleared on next success
```

```rescript
let {pending, rejected, error} = cards.status
// pending: writes waiting to sync
// rejected: refusals to show, until dismiss()
// error: last remote fetch failure, cleared on next success
```

`status` is a tilia object: read `status.pending` in a component and the badge updates itself. There is no event to subscribe to, because sync state is just state.

### changed: updates that arrive on their own

Not every change starts on this device. A WebSocket pushes a row; a delta-sync engine applies a batch. For these there is `changed(items)`: it takes an array — a push of one is a batch of one — and applies it as a single reactive transaction. Each item updates the object cache, adjusts query membership, and is saved *clean* to the local store — so a change pushed while the app was open is still there after an offline restart. What it never does is call the remote: the change *came* from the remote, and echoing it back would be a lie about authorship. It is the inbound half of the [`covered()`](#reads-answer-twice) story: external machinery owns the data flow, and `changed` is how it keeps this device's picture aligned. (An engine that already wrote its own database loses nothing — the extra clean save is idempotent.)

Deletes have their own inbound path, `removed(items)`, and it earns its keep on disk: it evicts the ids from the cache and every list, *purges the clean local rows*, and drops the ids from the persisted query records of [chapter 3](#reads-answer-twice). Dropping the rows from memory alone would be a trap — gone from the screen, waiting on disk, back at the next offline start as ghosts.

Both paths yield to the outbox: an id with a pending optimistic write is left alone until the write settles. Alice's tunnel edit is not overwritten by a push that raced it — the conflict machinery above decides, not arrival order.

::: story
Alice's laptop retires *perro* for good. The server tells her phone over the socket; `removed` walks it out of the deck, the lists, and the local database. Three tunnels later, the app restarts offline — and *perro* stays retired.
:::

::: pro
Resist the urge to call `upsert` for inbound updates because it "also works". It would echo the server's own change back to it and dirty the local store on the way. `changed` and `removed` exist precisely so that inbound data has a path with no side effects pointing outward — and the names keep the directions apart: outbound commands are imperative and take one item (`upsert`, `remove`), inbound events are past tense and take an array, so confusing `remove` with `removed` is a type error.
:::

Every behavior so far leaned on an adapter doing the right thing with a channel. Time to look at that boundary squarely: what an adapter is, and why the contract is shaped the way it is.
