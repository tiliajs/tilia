# Tilia State Management

Simple and fast state management library.

The library supports **TypeScript** and **ReScript** (it is actually written in ReScript for improved type safety and performance).

<a href="https://tiliajs.com">
  <img width="834" height="705" alt="image" src="https://github.com/user-attachments/assets/56dd163a-65a0-4900-9280-aab2a0d7d92a" />
</a>

Check the [**website**](https://tiliajs.com) for documentation and examples.

Simple documentation on the [README](./tilia/README.md).

### Changelog

- 2025-09-09 **3.0.0**
  - Rename `unwrap` for `lift`, change syntax for `signal` to expose setter.
  - Protect tilia from exceptions in computed: the exception is caught, logged to `console.error` and re-thrown at the end of the next flush.
  - Add `leaf` to @tilia/react: a higher order component to close the observing phase at the exact end of the render.
  - Simplify `useComputed` in @tilia/react to return the value directly.
- 2025-08-08 **2.2.0**
  - Add `unwrap` to ease inserting a signal into a tilia object.
- 2025-08-08 **2.1.1**
  - Fix `source` type: ignore return value for easier async support.
- 2025-08-03 **2.1.0**
  - Add `derived` to compute a signal from other tilia values.
  - Add `watch` to separate the capture phase and the effect phase of observe.
- 2025-07-24 **2.0.1**
  - Fix package.json configuration in @tilia/react publish script.
- 2025-07-21 **2.0.0**
  - Add tests and examples with Gherkin for todo app.
  - Moved core to npm "tilia" package.
  - Changed `make` signature to build tilia context (provides the full API running in a separate context).
  - Enable **forest mode** to observve across separated objects.
  - Add `computed` to compute values in branches (moved into `tilia` context).
  - Moved `observe` into `tilia` context.
  - `observe` _will be called_ for its own mutations (this is to allow state machines).
  - Removed re-exports in @tilia/react.
  - Removed `compute` (replaced by `computed`).
  - Removed `track` as this cannot scale to multiple instances and computed.
  - Renamed internal `_connect` to `_observe`.
  - Reworked API to ensure strong typing and avoid runtime errors.
  - Add `source`, `readonly` and `signal` for FRP style programming.
  - Add `carve` to support derivation (build domain features from objects).
  - Improved flush strategy to trigger immediately but not in an observing function.
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
