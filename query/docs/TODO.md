# TiliaQuery Project TODO

This roadmap tracks TiliaQuery in sequential phases so contributors can see what is complete, what is in progress, and what comes next.

## Phase 1 - Foundation (Completed)

- [x] Define core query cache model: object cache by id + query results by ids.
- [x] Add stable default query keying via sorted JSON stringification.
- [x] Implement async query loading with `Loading` / `Loaded` / `NotFound` states.
- [x] Add local read APIs for single item, array, and dict views.
- [x] Keep scheduling external and expose `tick()` as explicit lifecycle control.

## Phase 2 - Freshness, GC, And Invalidation (Completed)

- [x] Implement stale refresh for live queries without clearing current data.
- [x] Implement idle query expiration using `gc` timing.
- [x] Purge unreferenced objects after query eviction.
- [x] Add object-driven invalidation predicate `('query, 'a) => bool`.
- [x] Invalidate matching queries from `upsert` writes.
- [x] Add `sync` for inbound/live updates without remote upsert.
- [x] Cover this behavior with focused tests in `query/test/TiliaQuery.feature`.

## Phase 3 - Institutional Contract (Completed)

- [x] TypeScript-clean boundary: named channel callbacks (`emit`/`offline`/`conflict`/`reject`, `fail`/`covered`), flag records (`{value, deleted}`), single config object for `make`, `@tag`-based loadable representation.
- [x] Delete support: `remove(item)` through the durable outbox with local tombstones, reconnect and restart replay, conflict resurrection, rejection convergence.
- [x] Write-failure visibility: reactive `status` (`pending`, `rejected`, `error`) and `dismiss()`.
- [x] Rejected writes mark matching queries stale so server truth converges.
- [x] Split delta-sync `covered()` from transport `fail(message)`; failures leave freshness untouched and retry on the next stale window.
- [x] Lifecycle teardown: `dispose()` (stoppable connectivity watcher) and `clear()` for logout / user switch.
- [x] Detail/singleton reads: `one(query)` resolves a single row through the normal two-tier flow.

## Phase 3b - Offline Retention (Completed)

- [x] Persisted query registry: `store.queries()` / `saveQuery` / `removeQuery` with `{key, ids, fetched}` records, loaded at boot.
- [x] Remote-emit reconciliation: rows that left a query result are pruned from the local store unless the outbox or another persisted query retains them (no ghost rows after offline restart).
- [x] `sync(item)` persists clean; new `syncRemove(item)` for inbound deletes; both are no-ops for ids with a pending optimistic write.
- [x] Retention GC: idle-query eviction drops the persisted record and purges rows no remaining record references.
- [x] Feature coverage: ghost-row pruning, overlap refcounting, live update/delete persistence and outbox precedence, GC release, covered-query neutrality.

## Phase 4 - Documentation Baseline (In Progress)

- [x] Add non-technical product overview in `query/docs/vision.md`.
- [x] Add implementation guide in `query/docs/technical.md`.
- [x] Create package-level `query/README.md` for npm/repo entry-point onboarding with REST and Dexie adapter recipes.
- [x] Add complete TypeScript type declarations (`src/index.d.ts`).
- [x] Create `query/llms.txt` for AI coding assistants.
- [ ] Ensure one canonical navigation path between root README, query docs, and published docs.

## Phase 5 - Adoption And Ecosystem Docs (Pending)

- [ ] Publish `0.1.0` to npm.
- [ ] Add ReScript app-level integration tests in `tests/app...`.
- [ ] Add TypeScript app-level integration tests in `tests/app...`.
- [ ] Validate documented usage pattern in at least one real feature module.
- [x] Add TiliaQuery documentation under `docs/content/query`.
- [ ] Document recommended feature-wrapper API (domain-shaped helpers over raw query object).
- [ ] Update broader Tilia docs to direct remote fetching toward TiliaQuery over ad hoc patterns.
- [ ] Publish a short migration note for teams currently using custom `watch` / `changing` flows.

## Cross-Cutting Technical Gaps (Track While Building)

- [ ] Improve invalidation performance for many cached query filters.
- [x] Clarify conflict resolution policy between optimistic writes and fetch responses (fetch rows skip ids with pending puts; pending deletes are filtered out of results).
- [ ] Define pagination/windowing strategy beyond full-array query results.
- [ ] Design `'query` as serializable data (field/range DSL) so local evaluation, remote compilation, coverage checks, and `invalidates` derive from one definition instead of per-adapter parsers.
- [x] Add a dedicated fetch signal for delta-sync covered queries (`covered()`) instead of overloading `fail(string)`.
- [x] Expose pending-writes / rejection observability for sync-status UI.
