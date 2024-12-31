# Tilia State Management

Simple and fast state management for your app.

This is the root of the monorepo. Documentation for the projects are here:

- [**@tilia/react**](./packages/react/README.md)

Tilia for React. The library supports raw JS, TypeScript and ReScript.

- [**@tilia/core**](./packages/core/README.md)

Core engine for tilia. Most users will not import this directly.

## Features

- Zero dependencies
- Single proxy tracking
- Compatible with ReScript and TypeScript
- Inserted objects are not cloned.
- Tracking follows moved or copied objects.
- Respects `readonly` properties.

### Goals and Non-goals

The goal with Tilia is to be minimal and fast while staying as much as possible
out of the way.

### Changelog (for @tilia/core)

- 2024-12-31 **1.3.0**
  - Expose internals with \_meta.
  - Rewrite tracking to fix memory leaks when \_ready and \_clear are never called.
- 2024-12-27 **1.2.4** Add support for ready after clear.
- 2024-12-24 **1.2.3** Rewrite tracking to fix notify and clear before ready.
- 2024-12-18 **1.2.2** Fix readonly tracking: should not proxy.
- 2024-12-18 **1.2.1** Fix bug to not track prototype methods.
- 2024-12-18 **1.2.0** Improve ownKeys watching, notify on key deletion.
- 2024-12-18 **1.1.1** Fix build issue (rescript was still required)
- 2024-12-17 **1.1.0** Add support to share tracking between branches.
- 2024-12-13 **1.0.0** Alpha release.
