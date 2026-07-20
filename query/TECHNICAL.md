# Query storage and synchronization

`TiliaQuery` can coordinate query data across three layers:

- **Memory** holds the results used by the running application.
- **Local storage** is optional. When configured, it provides durable data
  while the network is unavailable.
- **Remote storage** is the authoritative shared data source.

A **query** selects and orders a set of rows. Its result is stored as row ids,
while each row value is stored separately by id. This separation lets one row
belong to several queries without duplicating its value in memory.

A query must be a pure predicate over one row. `matches(query, value)` decides
membership by looking at a single row, and a fetch answers with the query's
full result set. Limits, pagination and aggregates do not fit this shape: a
written row joins a result through `matches` alone, and a full-result `set`
replaces whatever a partial window would try to keep.

The application calls **`tick`** to perform time-based maintenance. A tick may
refresh open queries, release closed queries from memory, or purge expired
local data.

## Data flow

### Reading a query

Opening a query starts both the local and remote reads when those sources are
available. A local result can therefore make data visible before the remote
request finishes.

For example, opening the Spanish deck can produce this sequence:

```text
local result  -> Loaded({data: [cat, dog], fresh: false})
remote result -> Loaded({data: [cat, dog], fresh: true})
```

The `fresh` field describes whether the remote is known to be current. It does
not describe where the rows are physically stored.

When the remote result arrives, it becomes the visible result. If local storage
is configured, the rows are also upserted there so a later offline read can
reuse them.

If the app is offline and local storage cannot answer, the query settles as
`NotLocal`. This is an answer rather than a progress state. While online,
`unknown` leaves the query `Loading` until the remote responds. A known empty
answer is `set([])`: `array` returns a loaded empty array and `one` returns
`NotFound`.

### Connectivity transitions

The application owns `remote.online` and updates its value as connectivity
changes. Going offline settles queries still waiting without a local answer as
`NotLocal`. It does not cancel an in-flight fetch; a remote response that still
arrives is accepted, and later ticks correct its freshness.

Going online pushes pending outbox operations. Going offline does not end a
live query because the engine cannot know whether its transport survived; the
adaptor ends that source through its read channel.

### Writing a row

Every write follows an **optimistic** flow: local state changes before the
remote confirms the operation.

The flow is:

1. Update memory and configured local storage.
2. Append the operation to the outbox.
3. Send queued operations when the remote is online.
4. Remove confirmed operations from the outbox.

The **outbox** is an ordered queue that connects optimistic local writes to
eventual remote confirmation. Its detailed behavior is described below.

A remote query result is reconciled with pending local changes before display.
For each row with a pending operation, `merge` receives the local `Change` and
remote value. A successful merge rebases the pending operation on remote truth;
a rejected merge clears the operation, shows remote truth, and records a
conflict. Pending upserts then join matching results and pending removes filter
rows out, preventing optimistic changes from briefly disappearing.

## Cache lifecycle

Separate expiry periods control network freshness, memory use, and disk
retention. Expiring one layer does not imply that another layer must expire.

- **Refresh expiry — 30 seconds by default.** An open remote result becomes
  eligible for refresh. A live result is excluded: its source keeps it fresh.
- **Memory expiry — 5 minutes by default.** A closed query can be removed from
  memory.
- **Local expiry — 30 days by default.** An unused persisted query can be
  removed from local storage.

**Open** means observed. The engine asks Tilia's observer graph which query
results something is currently watching (`_canopy` over the shared results
dict). There is no registration API: reading a result inside an observer is
what keeps a query open.

An open query updates its last-seen time on every tick. This prevents active
queries from expiring from memory.

A closed query no longer updates its last-seen time. After the refresh period,
it stops triggering remote refreshes. After the memory period, its in-memory
entry can be removed.

Last-seen time records observation rather than delivery. A remote response that
arrives after a query has been closed does not extend that query's retention.

Removing an entry from memory does not remove its local data. Reopening the
query can still return the persisted result before requesting fresh remote
data.

### Freshness source

A remote result is marked stale when no replacement arrives within the refresh
period. The data stays visible; only its freshness changes.

```text
before expiry -> Loaded({data: [cat, dog], fresh: true})
after expiry  -> Loaded({data: [cat, dog], fresh: false})
```

While offline, this change happens at the refresh expiry. While online, the
system waits an additional `expiry.refresh / 8`. This buffer gives an in-flight
refresh time to finish without briefly changing the result to local.

### Remote write-through

Remote query results are written to local storage with upserts. The
write-through path inserts or replaces returned rows, but it does not infer
deletions from missing rows.

Suppose a previous remote result contained `cat` and `dog`, while the next
result contains only `dog`:

```text
visible query ids -> [dog]
local row ids     -> [cat, dog]
```

The query record no longer references `cat`, but its local row remains until a
purge proves that no retained query references it.

### Inbound remote deliveries

`receive.changed` and `receive.removed` describe facts pushed by the remote,
such as websocket deliveries. A changed value is matched against every
in-memory query: it joins results whose `matches` accepts it and leaves results
that no longer match. A removed id leaves every result and its local row is
deleted.

A changed delivery reconciles with a pending create, update, or remove through
`merge`. A successful merge keeps and rebases the pending change; a rejected
merge clears it, shows remote truth, and records a conflict. A removed delivery
confirms a pending remove. Against a pending create or update it clears the
operation, records a conflict, and keeps the server deletion visible.

A changed value stays in memory only while an in-memory query matches it, and
is persisted only while a query record lists it. A value matching nothing is
dropped. Inbound deliveries do not affect freshness; freshness and refresh
scheduling belong to each query's read channel.

## Failed fetches

A remote `fail` replaces the visible result with `Failed`. The error appears
at the read site, where the value is used; there is no global error slot.

A failed query is not stuck. On every tick, a failed non-live query re-enters
the refresh check. Once the refresh window has passed since the failed
attempt, it is refetched. A successful refetch replaces `Failed` with the new
result.

A live query is the exception: the engine never refetches it on its own.
Recovery is the source's job, described below.

## Live queries

A remote adaptor can keep a query fresh on its own, for example through a
server subscription. Such an adaptor answers through `channel.live` instead of
`channel.set`, and calls it again on every update. The refresh expiry skips a
live query: no periodic refetch is scheduled while the source keeps
delivering.

The subscription belongs to the adaptor; running its teardown belongs to the
engine:

- The adaptor registers its teardown with `channel.finally`. The slot holds
  one function; a later registration replaces the earlier one.
- The engine runs the teardown exactly once, when the fetch closes. A fetch
  closes on `end`, when a newer fetch supersedes it, when the query is
  evicted from memory, or on `dispose`.
- Registering a teardown on a fetch that is already closed runs it
  immediately. A source that dies synchronously inside `remote.fetch` is
  still torn down.

`channel.end` says the stream is over. The teardown runs, and the query
returns to the normal refresh cycle: the next tick past the refresh window
refetches it. Ending is the adaptor's call — going offline does not end a
live query, because the engine cannot know whether the transport survived.

Every callback on a closed fetch is ignored. Late replies from ended,
superseded, or evicted fetches cannot corrupt the visible result, and
adaptors do not need to guard against this themselves.

A failure does not close a live fetch. `channel.fail` shows `Failed` at the
read site, but the source stays connected: a later delivery replaces the
failure, and `end` hands the query back to periodic refresh.

## Local purge

The local purge is garbage collection for persisted query data. It removes
rows that are no longer reachable from any retained query.

The **query registry** is the source of reachability information. Each
persisted record contains a query key, the query itself, its latest row ids,
and the time that query was last seen.

Storing the query lets `matches` run against records whose query is not in
memory. This requires queries to be plain data that survives a JSON round
trip — the same assumption the default `sortedStringify` key already makes.

The running application keeps an in-memory mirror of records it has written.
During a purge, records from earlier sessions are merged only when the mirror
does not already contain the key, because the write-through mirror is at least
as fresh as its persisted copy.

Purging requires asynchronous local I/O. To limit that cost, purge runs on the
first tick after boot and then at most once per `expiry.local / 8`. With the
default local expiry, the interval is 3.75 days.

This gate applies only to local purge. Refresh checks, last-seen updates, and
memory expiry still run on every tick.

The purge uses **mark and sweep**, the same reachability pattern used by a
garbage collector:

1. Load the persisted query registry.
2. Offer each synthetic `__id:` row to every real record's query. A match
   adopts the id into that record and deletes the synthetic record — the real
   query now roots the row. A synthetic row whose value is not in memory is
   skipped and kept.
3. Remove closed query records unseen for longer than `expiry.local`.
4. Mark every row id listed by the surviving records.
5. Enumerate the rows in local storage.
6. Remove every unmarked row.

Pending operations are additional roots. They survive a restart and replay, so
their optimistic rows must survive too — even after every query record listing
them has expired. Their ids come from the in-memory outbox, which mirrors the
persisted entries, so marking them costs no extra I/O. Rejections are not
operations, are not persisted, and do not root rows.

For example:

```text
query records before purge -> Spanish: [dog]
local rows before purge    -> [cat, dog]

marked ids                 -> [dog]
local rows after purge     -> [dog]
```

This delayed sweep is what eventually removes rows omitted by later remote
results.

## Outbox

The outbox keeps writes ordered across disconnection. Every upsert or remove
receives a sequence number before remote confirmation.

When local storage is configured, each outbox operation is also persisted.
This makes pending writes durable across application restarts.

`status.pending` is the number of operations currently in the outbox. An
offline write increases it immediately because no remote request is attempted
while the connection is offline.

At boot, persisted operations are loaded in sequence order. If the remote is
online, replay starts after loading. Reconnecting triggers the same replay.

### Batching

A push selects every pending operation that is not already **in flight**. An
in-flight operation has been sent but has not yet received a confirmation.

The selected operations are sent as one ordered batch. Marking them in flight
prevents another push from sending the same operations concurrently.

If the remote asks for a retry, the batch returns to the pending state. A later
push can then send it again.

The write channel accepts individual confirmations until `retry` or `fail`
settles the batch. The first terminal call wins; every later callback on that
channel is ignored.

### Definitive failures

A definitive failure removes every unconfirmed operation in the batch from the
outbox and deletes its persisted entry. A created value is forgotten; an update
or remove restores its base value. Each local `Change` becomes a contextual
rejection in `status.rejected`. Rejections are keyed by row id, so a newer
rejection replaces an older one for the same row. Operations confirmed before
the failure have already left the outbox and are not rejected.

Remote truth is visible immediately after the revert. The rejection preserves
the local side of the story: `edited`, `base`, and the remote message where
applicable. It is not part of the optimistic overlay and is not persisted.

Keeping the local version is an ordinary `upsert`, creating a new operation.
Keeping remote truth requires no data change. Once the application has
resolved or intentionally ignored the context, `dismiss(rejection)` removes
that exact object from `status.rejected`; dismissing an absent object is a
noop.

### Upsert trace

An **upsert** inserts a missing row or replaces an existing row with the same
id. The optimistic update changes the in-memory value and local row before
enqueueing the operation.

The row also joins every matching query currently in memory, and leaves every
in-memory query the new value no longer matches — moving a card between decks
updates both results at once. Both changes are persisted in the affected query
records. Query records that exist only on disk are not scanned; they catch up
when the query next refreshes.

If no query record lists the row, a synthetic record named `__id:<id>` keeps it
reachable during local purge. The next purge offers the row to every persisted
query — including queries that exist only on disk, since records carry their
query. A match adopts the row and drops the synthetic record. A row no query
ever adopts keeps its synthetic record, which is never refreshed, so normal
local expiry eventually removes it.

```text
before:
  memory         -> cat.seen = 0
  local          -> cat.seen = 0
  outbox         -> []

after offline upsert:
  memory         -> cat.seen = 1
  local          -> cat.seen = 1
  outbox         -> [Upsert(cat.seen = 1)]
  status.pending -> 1
```

A remote `set` confirmation is matched to an in-flight upsert by row id. The
confirmed value is authoritative because the server may have corrected it. It
is reconciled through `merge` when configured, then written to memory and local
storage.

After confirmation, the matching operation is deleted from the persisted
outbox. `status.pending` then decreases.

### Remove trace

A remove deletes the row from memory before remote confirmation. It also
removes the id from loaded query results and deletes the local row.

```text
before:
  Spanish ids    -> [cat, dog]
  local rows     -> [cat, dog]

after remove:
  Spanish ids    -> [dog]
  local rows     -> [dog]
  outbox         -> [Remove(cat)]
```

A query record left on disk by an earlier session may still list `cat`.
Removing the row updates records loaded in the current session, but it does not
scan every historical query record.

This stale id is safe during purge. The mark phase may mark `cat`, but the
sweep only examines rows that still exist in local storage. Because the local
`cat` row is already gone, there is nothing to retain or remove. Refreshing
that query later rewrites its persisted id list without `cat`.

A remote `removed` confirmation is matched to an in-flight remove by row id.
The local deletion is already complete, so confirmation only clears the
outbox operation.

## The linear-scan bet

The engine keeps no index from row ids to queries or operations. Every
membership question is answered by a scan:

- An upsert offers the value to every in-memory query, and scans every
  registry record to see whether some record already lists the row.
- A remove walks every in-memory id list and every registry record to drop
  the id.
- A remote delivery rebuilds the optimistic overlay from scratch: every
  pending outbox operation is re-applied over the delivered rows.
- A tick visits every in-memory query. A purge marks every id of every
  record.

This is a bet on scale, and it is deliberate rather than an oversight. The
intended load is a client cache: dozens of in-memory queries, registry
records in the same range, and an outbox that drains on reconnect. At that
scale a scan costs less than an index. There is no structure to update on
every write, and nothing that can drift from the truth it summarizes.

The bet loses when the counts stop being small — hundreds of active queries,
or a large outbox overlaid onto frequent deliveries. The fix at that point is
indexing (ids to queries, ids to operations), not tuning the scans.

## Rejection test fixture

Rejection scenarios need a deterministic definitive failure rather than a
transient retry. Papabase provides that failure through version checking.

Application writes normally omit a version. In a rejection scenario, the test
adds a forged version that differs from the stored row:

```text
stored version  -> current
upsert version  -> 5
result          -> definitive rejection
```

