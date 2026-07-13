# Query storage and synchronization

`TiliaQuery` can coordinate query data across three layers:

- **Memory** holds the results used by the running application.
- **Local storage** is optional. When configured, it provides durable data
  while the network is unavailable.
- **Remote storage** is the authoritative shared data source.

A **query** selects and orders a set of rows. Its result is stored as row ids,
while each row value is stored separately by id. This separation lets one row
belong to several queries without duplicating its value in memory.

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
local result  -> Loaded({data: [cat, dog], local: true})
remote result -> Loaded({data: [cat, dog], local: false})
```

The `local` field describes the source freshness. It does not describe where
the rows are physically stored.

When the remote result arrives, it becomes the visible result. If local storage
is configured, the rows are also upserted there so a later offline read can
reuse them.

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

## Cache lifecycle

Separate expiry periods control network freshness, memory use, and disk
retention. Expiring one layer does not imply that another layer must expire.

- **Refresh expiry — 30 seconds by default.** An open remote result becomes
  eligible for refresh.
- **Memory expiry — 5 minutes by default.** A closed query can be removed from
  memory.
- **Local expiry — 30 days by default.** An unused persisted query can be
  removed from local storage.

An open query updates its last-seen time on every tick. This prevents active
queries from expiring from memory.

A closed query no longer updates its last-seen time. After the refresh period,
it stops triggering remote refreshes. After the memory period, its in-memory
entry can be removed.

Removing an entry from memory does not remove its local data. Reopening the
query can still return the persisted result before requesting fresh remote
data.

### Freshness source

A remote result is marked local when no replacement arrives within the refresh
period. The data stays visible; only its freshness source changes.

```text
before expiry -> Loaded({data: [cat, dog], local: false})
after expiry  -> Loaded({data: [cat, dog], local: true})
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

## Local purge

The local purge is garbage collection for persisted query data. It removes
rows that are no longer reachable from any retained query.

The **query registry** is the source of reachability information. Each
persisted record contains a query key, its latest row ids, and the time that
query was last seen.

Purging requires asynchronous local I/O. To limit that cost, purge runs on the
first tick after boot and then at most once per `expiry.local / 8`. With the
default local expiry, the interval is 3.75 days.

This gate applies only to local purge. Refresh checks, last-seen updates, and
memory expiry still run on every tick.

The purge uses **mark and sweep**, the same reachability pattern used by a
garbage collector:

1. Load the persisted query registry.
2. Remove closed query records unseen for longer than `expiry.local`.
3. Mark every row id listed by the surviving records.
4. Enumerate the rows in local storage.
5. Remove every unmarked row.

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

### Upsert trace

An **upsert** inserts a missing row or replaces an existing row with the same
id. The optimistic update changes the in-memory value and local row before
enqueueing the operation.

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
confirmed value is authoritative because the server may have corrected it.
Memory and local storage are replaced with that value.

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

The unfinished rejection and recovery behavior is tracked in
[`TODO.md`](./TODO.md).

