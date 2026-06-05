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
- Real-time or inbound updates that should refresh matching queries.
- Multi-view experiences where shared objects should stay consistent.
- Fully offline-capable apps with two sync layers:
  - local database sync for immediate durable updates
  - remote database sync for slower network-dependent persistence
- In this model, TiliaQuery owns in-memory liveness:
  - keep actively viewed data hot in memory
  - purge memory data when it is no longer viewed
  - keep local database and memory view aligned as the fast source
  - treat remote as eventual persistence when network is available

## How It Works (High Level)

TiliaQuery keeps two connected caches:
- an object cache by id
- a query-result cache by filter

When data changes, matching queries are marked stale.  
Live queries refresh in the background.  
Idle queries can be cleaned up later.  
Objects still used by active queries stay available.

## Product Direction

TiliaQuery is meant to be the default remote-data base layer for Tilia projects.

Feature modules should wrap it with domain-specific helpers so application code stays clear, focused, and business-oriented.
