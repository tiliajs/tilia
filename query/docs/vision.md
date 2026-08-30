# TiliaQuery Vision

## Why TiliaQuery Exists

TiliaQuery exists to make remote data feel predictable in Tilia apps.

Without it, each feature often reinvents the same flow:
- load list data
- cache it locally
- refresh stale data
- merge live updates
- avoid unnecessary refetches

TiliaQuery provides one shared way to handle this lifecycle.

## Intentions

- Keep remote data handling simple and explicit.
- Separate feature logic from data-fetching mechanics.
- Preserve responsiveness with local-first reads.
- Refresh in the background instead of clearing useful data.
- Let teams choose their own scheduling and orchestration strategy.

## Main Use Cases

- Feature screens that read filtered lists and related items.
- Apps that need both cached reads and occasional refetch.
- Systems with local writes plus remote persistence.
- Real-time or inbound updates that should update matching queries in place.
- Multi-view experiences where shared objects should stay consistent.
- Fully offline-capable apps where the shipped store combines:
  - a local `Kv` for cached rows, query records, and queued writes
  - a remote backend for authoritative reads and write outcomes
- In this model:
  - the query engine owns reactive in-memory results, freshness, and eviction
  - the connected store owns persistence, synchronization, and local retention
  - the application owns the heartbeat and its backend integration

## How It Works (High Level)

The query engine keeps two connected in-memory indexes:
- an object cache by id
- query results as lists of ids

A store factory connects the engine to its source and returns any write or
status API the application needs. The shipped store is the default:
`Store.make` accepts ordinary `find`, `upsert`, and `remove` functions and
adds a write-through cache and outbox. Channel-backed integrations can use
`Store.custom` when they need live or pushed results.

When data changes, `matches` updates in-memory query membership immediately.
Observed non-live queries refresh on the application's `tick`; subscription
sources can declare themselves live and keep their own results fresh.
Idle queries leave memory after their expiry, while the store may retain
local data for later offline reads.

## Product Direction

TiliaQuery is meant to be the default remote-data base layer for Tilia projects.

Feature modules should wrap it with domain-specific helpers so application code stays clear, focused, and business-oriented.
