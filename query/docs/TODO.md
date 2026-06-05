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
- [x] Cover this behavior with focused tests in `query/test/TiliaQuery_test.res`.

## Phase 3 - Documentation Baseline (In Progress)

- [x] Add non-technical product overview in `query/docs/vision.md`.
- [x] Add implementation guide in `query/docs/technical.md`.
- [ ] Create package-level `query/README.md` for npm/repo entry-point onboarding.
- [ ] Ensure one canonical navigation path between root README, query docs, and website docs.

## Phase 4 - Type Surface And App-Level Validation (Pending)

- [ ] Add complete TypeScript type documentation and examples.
- [ ] Add ReScript app-level integration tests in `tests/app...`.
- [ ] Add TypeScript app-level integration tests in `tests/app...`.
- [ ] Validate documented usage pattern in at least one real feature module.

## Phase 5 - Adoption And Ecosystem Docs (Pending)

- [ ] Add TiliaQuery section to `website/src/pages/docs.md`.
- [ ] Document recommended feature-wrapper API (domain-shaped helpers over raw query object).
- [ ] Update broader Tilia docs to direct remote fetching toward TiliaQuery over ad hoc patterns.
- [ ] Create `query/llms.txt` linking to ReScript and TypeScript LLM guidance.
- [ ] Publish a short migration note for teams currently using custom `watch` / `changing` flows.

## Cross-Cutting Technical Gaps (Track While Building)

- [ ] Define a first-class strategy for singleton/detail resources.
- [ ] Improve invalidation performance for many cached query filters.
- [ ] Clarify conflict resolution policy between optimistic writes and fetch responses.
- [ ] Define pagination/windowing strategy beyond full-array query results.
