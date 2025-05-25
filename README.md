# Tilia State Management

Simple and fast state management library.

The library supports **TypeScript** and **ReScript** (it is actually written in
ReScript for improved type safety and performance).

Check the [**website**](https://tiliajs.com) for documentation and examples.

### Changelog

- 2025-05-24 **2.0.0** (not yet release: canary version)
  - Moved core to npm "tilia" package.
  - Changed `make` signature to build tilia context (provides the full API running in a separate context).
  - Enable **forest mode** to observve across separated objects.
  - Add `computed` to compute values in branches (moved into `tilia` context).
    Note: computed _will not be called_ for its own mutations.
  - Moved `observe` into `tilia` context.
  - `observe` _will be called_ for its own mutations (this is to allow state machines).
  - Removed re-exports in @tilia/react.
  - Removed `compute` (replaced by `computed`).
  - Removed `track` as this cannot scale to multiple instances and computed.
  - Renamed internal `_connect` to `_observe`.
  - Reworked API to ensure strong typing and avoid runtime errors.
  - Added `derived`, `signal`, and `update` for FRP style programming.
- 2025-05-05 **1.6.0**
  - Add `compute` method to cache values on read.
- 2025-01-17 **1.4.0**
  - Add `track` method to observe branches.
  - Add `flush` strategy for tracking notification.
- 2025-01-02 **1.3.2** Fix extension in built artifacts.
- 2024-12-31 **1.3.0**
  - Expose internals with \_meta.
  - Rewrite tracking to fix memory leaks when \_ready and clear are never called.
- 2024-12-27 **1.2.4** Add support for ready after clear.
- 2024-12-24 **1.2.3** Rewrite tracking to fix notify and clear before ready.
- 2024-12-18 **1.2.2** Fix readonly tracking: should not proxy.
- 2024-12-18 **1.2.1** Fix bug to not track prototype methods.
- 2024-12-18 **1.2.0** Improve ownKeys watching, notify on key deletion.
- 2024-12-18 **1.1.1** Fix build issue (rescript was still required)
- 2024-12-17 **1.1.0** Add support to share tracking between branches.
- 2024-12-13 **1.0.0** Alpha release.
