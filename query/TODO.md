# @tilia/query TODO

## Done

- Query cache stores fetched objects by id and query results as arrays of ids.
- Query keys use sorted JSON stringification by default.
- Write operations: `upsert(id, object)` updates the local cache and triggers the remote upsert.
- `tick()` uses `Tilia._canopy(queries)` to split live and idle queries.
- Idle queries expire after `gc` seconds and purge only objects not referenced by remaining queries.
- Live stale queries refresh in the background without clearing current data.
- Timing uses seconds: `stale`, `gc`, and `now`.
- Scheduling is owned by library users; `@tilia/query` exposes `tick()` but does not start timers.
- `~invalidate` predicate `('query, 'a) => bool` at construction time auto-invalidates cached queries on upsert.

## Next

## Later

- Add TypeScript types.
- Add ReScript and TypeScript tests in test apps (tests/app...).
- Create library documentation in query/README.md.
- Add library documentation on docs.md.
- Document the recommended feature-layer API: wrap `@tilia/query` and expose domain-shaped helpers.
- Update tilia docs to direct remote data fetching toward `@tilia/query` instead of ad hoc `watch`/`changing` patterns.
- Create llms.txt at the root of tilia/query with links to llms-rescript.md and llms-typescript.md.
