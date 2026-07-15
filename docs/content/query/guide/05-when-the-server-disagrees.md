---
title: When the server disagrees
slug: when-the-server-disagrees
sort: 5
refs: [write-channel-type, status, retry, discard, rejection-type, receive-changed, receive-removed]
---

Optimistic writes make a promise the server hasn't confirmed. Most of the time it simply agrees. This chapter is about the other times — and about the fourth kind of update, the one that arrives without being asked for.

### Two verdicts on a batch

The remote settles a pushed batch through a channel with four callbacks, but the real vocabulary is smaller: confirmations, and two ways to not confirm.

- **Confirmation, operation by operation** — `set(value)` for an upsert, with the authoritative value: echoed back, or corrected by the server. `removed(id)` for a remove. A batch where everything confirms simply ends. `set` is also where quiet corrections live: a server that resolves a concurrent edit itself answers with the resolved value, and that value replaces the device's copy without ceremony.
- `retry()` — **no verdict.** Something transient: a timeout, a gateway mid-restart. Every unconfirmed operation stays pending and rides the next push. This is the write path's counterpart of the read channel's narrow `fail` — the refusal to confuse "no" with "not now".
- `fail(message)` — **a verdict.** Every operation of the batch not yet confirmed becomes a *rejection*. Operations confirmed before the failure have already left the outbox; they are not dragged into it.

The first definitive call wins; everything on the channel after it is a noop.

### A rejection is a visible debt

A rejected operation moves from the outbox to `status.rejected` — the operation, its id, the server's message. At most one rejection per id: a newer one replaces an older.

What a rejection does *not* do is silently revert. The refused edit keeps overlaying remote deliveries exactly like a pending one, so the screen keeps saying what the user said. The library's position is that undoing someone's work behind their back is worse than showing them a debt. The UI shows the rejection; the user chooses the exit:

- `retry(rejection)` re-queues the operation — under its **original** sequence number, so an edit made after the rejection still pushes later and still wins. Online, the push happens immediately.
- `discard(rejection)` drops it for good. The optimistic write replaced both the in-memory value and the local row, so the client cannot reconstruct remote truth on its own — discard refetches the queries that held the value, and the remote's answer restores it. A rejected *new* row disappears the same way: the answer simply doesn't contain it.

A rejection even survives restarts, by construction rather than bookkeeping: its persisted operation reloads as pending, is pushed again, fails again — and the rejection resurfaces on its own.

::: story
Nora's wifi, first evening. The week's outbox drains in one ordered batch — every review confirms except one: a card Alice edited in a deck Nora had locked. Her phone still shows her version, with a badge and the server's reason. She reads it, shrugs, taps discard; the card snaps back to the deck's version. The other forty-one operations are already on the server.
:::

### Truth that arrives unasked

Not every change starts on this device. A WebSocket pushes a row; a sync feed applies a batch. For these there is `receive` — two doors, deliberately in the past tense, because they report facts about the server, not commands to it: `receive.changed(values)` and `receive.removed(ids)`.

A delivered change behaves like an upsert with the optimism removed. Each changed value joins the in-memory results it `matches` and leaves the ones it no longer does; a removed id leaves every result and its local row is deleted. Two rules give `receive` its character:

- **The outbox outranks the socket.** An id with a pending or rejected operation is skipped entirely — the optimistic value stays until the operation confirms or is discarded. An edit Alice hasn't managed to send cannot be overwritten by a push that raced it.
- **Deliveries never touch freshness.** The `fresh` flag and the refresh schedule belong to the per-query read channel. One pushed row proves nothing about a whole query being current, so it isn't allowed to claim it.

Retention follows the same honesty: a delivered value is kept in memory only while some in-memory query matches it, and persisted only while some query record lists it. A value matching nothing is dropped, not hoarded.

::: story
Home again, phone on the couch. In the chat, Nora is still polishing the deck they built in Madrid — and the deck moves as she types: two new cards surface mid-conversation, a misspelled *ajedrés* vanishes. The card Alice is editing at that very moment doesn't budge. Her unsent version outranks the socket; the server will hear her out first.
:::

::: pro
The names keep the directions apart: outbound commands are imperative and take one item (`upsert`, `remove`); inbound events are past tense and take an array (`changed`, `removed`). Confusing `remove` with `removed` is a type error, not a production incident.
:::

Every behavior so far leaned on an adapter doing the right thing with a channel. Time to look at that boundary squarely: what an adapter is, and why the contract is shaped the way it is.
