# claims-app-ts

Offline-first insurance claims demo for
[`@tilia/query`](../query/README.md).

Two field adjusters — **Ana** (cyan) and **Ben** (pink) — work on the same
claims from separate clients. Each pane has its own query engine, network
signal, and local `Kv` keyspace, and opens on its own **Mine** query
(`{ adjuster: name }`). The bottom pane is the simulated server: cards mark
writes and reads so the query and synchronization decisions stay visible.

```sh
pnpm install
pnpm dev        # open the printed URL
pnpm test       # business scenarios (Gherkin + vitest-bdd)
```

## Storage and transport

The demo's persistence is one `Kv` keyspace per pane, implemented with nested
in-memory maps in `src/app/adapters.ts`. The shipped `@tilia/query` store
writes rows, query records, and outbox entries into it under separate tags.
The keyspace outlives a pane's app instance, so the circular-arrow restart
demonstrates local reconstruction and outbox replay.

This is an in-memory stand-in for a durable keyspace, not browser IndexedDB:
a full page reload creates a new world. A real app can pass
`make({ name: "claims" })` from `@tilia/query/indexeddb` as the same
`persist` value without changing the query/store boundary.

The simulated server has two read modes:

- **Polling** (default): one-shot fresh snapshots. Observed queries refresh
  after 30 seconds; the app calls `tick()` every 2 seconds.
- **Live**: a find subscribes to the server and publishes snapshots through
  `channel.live`. Accepted writes are re-evaluated against subscriptions and
  pushed when their result changes. `channel.finally` owns unsubscribe.

The app deliberately uses `Store.custom`, not the default `Store.make`,
because one simulated backend can push live query snapshots and reconnect
its subscriptions. Its remote adaptor therefore needs `live`, `finally`, and
the channel write protocol. Backends that only answer when asked would
normally use `Store.make({ find, upsert, remove })`.

Switching transport modes rebuilds each app while retaining its pane's `Kv`,
so open queries reconnect through the selected mode.

## What it demonstrates

- **Claimed local-first reads.** A recorded query can load with claim
  `local`, then the server replaces it with `fresh`. An unrecorded local scan
  is only `partial`.
- **Optimistic writes and an outbox.** Edit offline and the list changes
  immediately while the pending badge exposes the queued operation.
- **Reconnect and boot replay.** Reconnect pushes queued work; the
  circular-arrow restart rebuilds from the same `Kv` and reloads its outbox.
- **In-place membership.** Taking, closing, or removing a claim updates every
  matching in-memory list through `matches`; a local write does not trigger a
  query find.
- **Conflicts and merge.** The server returns its current row for stale
  versions. Non-overlapping edits merge and remain pending; overlapping
  fields restore remote truth and create an `updateConflict` snapshot for the
  resolver.
- **Definitive rejection.** Estimates above CHF 50'000 are rejected. The
  optimistic edit is reverted and the failed rejection remains until the
  user resolves or discards it.
- **Stale refresh.** In polling mode, another pane sees accepted changes on
  its next refresh after the 30-second window.
- **Live subscriptions.** In live mode, accepted server changes immediately
  push new snapshots to subscriptions whose results changed.
- **Split expiry.** The engine's refresh and memory clocks are separate from
  the store's 30-day local-retention clock. The server controls let scenarios
  advance the fake clock.

## Walkthroughs

### 1. Offline inspection and replay

Turn Ana's switch off. Open one of her claims, set its status to
*inspected*, enter an estimate and notes, and save. Her matching lists update
immediately and the pending badge appears; the server still holds the old
row.

Click the pending badge to inspect the serialized outbox entry. Turn the
switch back on: the adapter pushes the operation, the server confirms its
versioned value, and the pending count returns to zero.

### 2. Restart with queued work

Turn Ben offline and record an inspection. Click his circular-arrow button.
The app and query engine are disposed and rebuilt, but Ben's `Kv` keyspace
survives. The new store loads the persisted query data and outbox. Reconnect
to push the recovered operation.

### 3. Conflicting edits

Let Ana and Ben start from the same version and change the same field
differently. The first write is saved. The second receives
`channel.conflict(serverRow)`.

The app's three-way `merge` declines the overlapping edit, so the server row
becomes visible and an `updateConflict { base, edited }` snapshot appears.
Open **Resolve** to choose field values. Saving discards that exact historical
record and submits the chosen draft as a new optimistic write; cancelling
leaves the rejection available for later.

### 4. Refused write

Record an estimate above CHF 50'000. The server calls
`channel.reject(id, message)`. The store removes that operation from the
outbox, restores its base, and records an `updateFailed` or `createFailed`
snapshot. No query refetch is required for the revert.

### 5. Local then remote

Raise server latency and switch between previously opened tabs. A retained
query record can answer from the pane's `Kv` before the server's fresh
snapshot arrives. New queries may first show the rows held locally with a
`partial` claim.

### 6. Live push

Switch the server to **Live**. Registered queries appear as chips in the
server header. Have Ana take a new claim: each affected subscription receives
a new `channel.live` snapshot immediately, without a polling fetch.

Turn Ben offline first. His custom adaptor unsubscribes while keeping the
find's live lifecycle open. Reconnecting subscribes again and the initial
snapshot catches him up.

## Architecture

The app follows the tilia + `@tilia/query` shape: a repo owns the query and
store, features are `carve` branches over it, components render those
features, and dependencies are passed as arguments.

```text
src/
  app/
    claim.ts               row and query types, membership predicate
    adapters.ts            channel remote + in-memory Kv keyspace
    repo.ts                make(...) with Store.custom, returns query/store
    features/claims/
      type.ts              public feature contract
      actions.ts           optimistic writes and rejection resolution
      computed.ts          query selection
      index.ts             carve branch and heartbeat boundary
    createApp.ts           graph wiring from injected dependencies
  server/                  simulated backend and version outcomes
  world.ts                 one server, two networks, two keyspaces/apps
  ui/                      React components using @tilia/react
test/
  claims.feature           business scenarios
  claims.feature.ts        vitest-bdd step definitions
```

`src/app/repo.ts` is the important boundary:

```typescript
const [claims, store] = make({
  id: (claim) => claim.id,
  matches: match,
  store: Store.custom({ remote, persist, merge, expiry: { local } }),
  expiry: { refresh, memory },
});
```

Feature actions write through `store.upsert` and `store.remove`; reads use
`claims.array`. The feature projects `store.status.pending` and
`store.status.rejected` for the UI, while `claims.tick()` drives both the
engine and connected store heartbeat.

The Gherkin tests drive the same headless graph the UI renders, so they cover
assignments, offline inspections, conflicts, refusals, replay, and expiry as
business behavior.
