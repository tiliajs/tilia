# @tilia/query TODO

## Done

- Query cache stores fetched objects by id and query results as arrays of ids.
- Query keys use sorted JSON stringification by default.
- Write operations: `upsert(item)` updates the local cache and triggers the remote upsert.
- Delete operations: `remove(item)` tombstones locally and triggers the remote remove.
- Durable outbox: dirty rows and delete tombstones replay on reconnect and after restart.
- `tick()` uses `Tilia._canopy(queries)` to split live and idle queries.
- Idle queries expire after `gc` seconds and purge only objects not referenced by remaining queries.
- Live stale queries refresh in the background without clearing current data.
- Timing uses seconds: `stale`, `gc`, and `now`.
- Scheduling is owned by library users; `@tilia/query` exposes `tick()` but does not start timers.
- Object-driven query invalidation handles writes and live objects with `('query, 'a) => bool`.
- TypeScript-clean boundary: named channel callbacks, flag records, config object, tagged loadable.
- Reactive sync status: `pending`, `rejected` (+ `dismiss()`), last fetch `error`.
- `covered()` fetch signal split from `fail(message)` transport errors.
- Detail views: `one(query)` resolves a single row through the normal query flow.
- Lifecycle: `dispose()` stops the connectivity watcher, `clear()` empties memory + outbox.
- TypeScript types in `src/index.d.ts`, shipped to `dist/` by the build.
- `llms.txt` at the package root.

## Later

- Publish `0.1.0` to npm.
- Add ReScript and TypeScript tests in test apps (tests/app...).
- Add library documentation on docs.md.
- Document the recommended feature-layer API: wrap `@tilia/query` and expose domain-shaped helpers.
- Update tilia docs to direct remote data fetching toward `@tilia/query` instead of ad hoc `watch`/`changing` patterns.
