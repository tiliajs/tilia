# claims-app-ts

Offline-first insurance claims demo for [`@tilia/query`](../query/README.md).

Two field adjusters — **Ana** (cyan) and **Ben** (pink) — work on the same
claims from separate devices. Each pane is a full app instance with its own
in-memory cache, device storage, and network switch, and opens on its own
**Mine** list (`{adjuster: name}`), so the two clients watch different
queries. The bottom pane is the server: cards blink in the acting adjuster's
color on writes and pulse on query fetches, so you can watch every sync
decision `@tilia/query` makes.

The server has two transport modes:

- **Polling** (default): one-shot fetches; watched queries refresh when they
  go stale (15 s, driven by the app's `tick()` scheduler).
- **Live**: `remote.fetch` registers the query on the server and keeps the
  channel open (the cleanup it returns unsubscribes on GC). On every accepted
  write the server re-evaluates the registered queries and pushes the new
  result to each client whose result changed. Registered queries appear as
  chips in the server header and pulse when a push goes out.

Switching modes reconnects every online client, so open queries re-run
against the new transport immediately.

```
pnpm install
pnpm dev        # open the printed URL
pnpm test       # business scenarios (Gherkin + vitest-bdd)
```

## What it demonstrates

| `@tilia/query` behavior | Where to see it |
| --- | --- |
| Two-tier reads (local store + remote) | Lists render instantly from device storage, then refresh from the server |
| Optimistic writes + durable outbox | Edit offline: the list updates, a "N to sync" badge appears |
| Reconnect replay | Toggle back online: queued writes reach the server, cards blink |
| Boot replay | Reload the app (circular arrow) while offline edits are pending: they survive and sync later |
| Conflicts (server wins) | Both adjusters edit the same claim: the second write is answered with the server row |
| Rejections | Estimates above CHF 50'000 are refused by the server and surfaced with a banner |
| Object-driven invalidation | A write refetches the claim lists; watch the server cards pulse |
| Stale refresh | In polling mode, the other adjuster's pane catches up within ~15 s (`tick()` every 2 s) |
| Live subscriptions | In live mode, a colleague's write lands instantly by push — no polling; offline clients catch up on reconnect |

## Walkthroughs

**1. Offline inspection, reconnect replay.**
Turn Ana's switch off. Open a claim assigned to her, set status to
*inspected*, enter an estimate and notes, save. Her list updates immediately
and "1 to sync" appears; the server keeps the old row. Turn the switch back
on: the outbox replays, the server card blinks rose, the version bumps.

**2. Conflict — the office wins.**
Ana takes a *new* claim (row action "Take"). Ben's pane still shows the old
row. Have Ben take the same claim: the server answers `conflict` with its
current row, and Ben's pane resolves to Ana's assignment. Versions on the
server cards make the race visible.

**3. Restart with unsynced work.**
Turn Ben offline and record an inspection. Click his reload button: the app
instance is rebuilt from device storage (boot replay) — the edit is still
there, still pending. Reconnect to sync it.

**4. Refused write.**
Record an inspection with an estimate above 50'000. The server rejects it,
a banner shows the reason, and the refetch restores the office value.

**5. Latency.**
Raise the server latency slider and repeat any flow: reads stay instant
(local store answers first), and the remote refresh lands visibly later.

**6. Live push.**
Switch the server to *Live*. The registered queries appear as chips — each
adjuster subscribes to different ones (their *Mine* list, or whatever tab is
open). Have Ana take a *new* claim: Ben's matching list updates immediately,
the chip pulses, and no read pulses appear on the cards. Toggle Ben offline
first and his pane stays frozen until reconnect, where the re-subscription
snapshot catches him up.

## Architecture

The app follows the recommended tilia + `@tilia/query` shape: a repo layer
owns the data collections, features are `carve` branches over it, components
only render, and every dependency is passed as a function argument.

```
src/
  app/
    claim.ts               domain row, query type, shared match/clone
    adapters.ts            remote adapter (per user) + in-memory local store
    repo.ts                repo layer: the TiliaQuery claims collection
    features/claims/
      type.ts              public contract of the feature
      actions.ts           curried actions: (deps) => (self) => (args)
      computed.ts          pure projections over loadables
      index.ts             glue only: carve the branch
    createApp.ts           wire the graph from injected deps
  server/                  simulated backend: latency, versions, conflicts
  world.ts                 one server + two panes (network, storage, app)
  ui/                      React components (render only, useTilia)
test/
  claims.feature           business scenarios in domain language
  claims.feature.ts        step definitions scoped inside Given (vitest-bdd)
```

The Gherkin tests drive the same headless graph the UI renders
(`createApp` with the simulated server), so they test business behavior —
assignments, offline inspections, conflicts, refusals — not implementation
details.
