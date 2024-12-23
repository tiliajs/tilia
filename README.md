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
