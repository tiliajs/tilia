# Tilia State Management

Simple and fast state management library.

The library supports **TypeScript** and **ReScript** (it is actually written in
ReScript for improved type safety and performance).

### Goals and Non-goals

**The goal** with Tilia is to be minimal and fast while staying as much as
possible out of the way. A special effort was made to keep the API as simple and
intuitive as possible, while still supporting best practices (type safety,
proper management of transitive states, etc).

**Non-goal**: Tilia is not a framework.

We haven't measured the performance yet, but everything was designed to make it
as fast and lightweight as possible. If someone wants to help us benchmarking,
we'd be happy to add it to the documentation.

# Documentation

**This is the documentation for the canary version (2.0.0)**

You can check the [todo app](./todo-app-ts/README.md) for a working example using TypeScript.

**install**

```sh
npm install tilia
```

### connect

Connect an object or array to the forest so that it can be observed.

```ts
// We use the default context (forest). If we want to have multiple contexts,
// we can create them with `make`.
import { connect } from "tilia";

const alice = connect({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: 10,
});
```

Now alice can be observed. Who knows what she will be doing ?

### observe

Observe and react to changes. Every time the callback is run, tilia registers
which values are read in the connected objects and arrays and will notify the
observer if any of these values changed. If a value changes during the `observe`
callback, it will be re-run (this is to support state machines).

```ts
import { observe } from "tilia";

observe(() => {
  console.log("Alice is now", alice.age, "years old !!");
});
```

Now every time alice's age changes, the callback will be called.

But I want to update her age automagically from today's date!

### signal

Use `signal` to represent a value that changes, such as a date, a number, a
variant or even the app as it goes through its life cycle.

```ts
import { signal } from "tilia";

const [now, setNow] = signal(dayjs());

setInterval(() => setNow(dayjs()), 1000 * 60);
```

We have a "now" signal. Let's use it to update alice's age. But before, I must
share a little secret: the `signal` function is just syntax sugar on top of
`connect`.

```ts
function signal<a>(value: a): Signal<a> {
  const s = connect({ value });
  const set = (v) => (s.value = v);
  return [s, set];
}
```

### computed

Compute a value from other connected objects.

```ts
import { computed } from "tilia";

const alice = connect({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: computed(() => now.diff(alice.birthday, "year")),
});
```

The computed is _not_ just syntax sugar. It is an important feature of the
library and only recomputes (or notifies) when needed. The rule goes like this:

1. If there are observers on "alice.age" and a dependency for the calculation changes, the computation is run.
2. If the result of a new computation is different from the previous one, the observers are notified.
3. Without observers, the computation is only run on first read (and then saved for next reads).

Let's try to print a message to wish a happy birthday to Alice when her age
changes:

```ts
import { observe } from "tilia";

observe(() => {
  console.log("Alice is now", alice.age, "years old !! Happy birthday Alice !");
});
```

This is nice but it will print the message when our app starts, printing a wish
that does not correspond to an age change. We need to use `update` to fix this.

### update

Update a value from the current value and other connected objects (other signals
or values). This helps to model state changes.

```ts
import { update } from "tilia";

update(alice.age, (previous, set) => {
  if (alice.age !== previous) {
    console.log("Alice is now", alice.age, "years old !!");
    console.log("*** 🥳🩷 Happy Birthday Alice !! 🩷🥳 **");
  }
  set(alice.age);
});
```

This `update` mechanism let's us create state machines that are very useful for initialisation or other complex states. Look at `app.ts` in the [todo app](../todo-app-ts/src/app.ts) for an example.

Just as `signal` is syntactic sugar on top of `connect`, `update` is syntactic sugar on top of `observe` and `signal`:

```ts
export function update<a>(init: a, fn: (p: a) => a): Signal<a> {
  const [s, set] = signal(init);
  observe(() => set(fn(s.value)));
  return s;
}
```

Now we want to allow Alice to use social media if and only if she is old enough. Let's derive a signal from alice's age.

### derived

Derive a signal from other connected objects (other signals or values).

```ts
import { derive } from "tilia";

const socialMediaAllowed_ = derived(() => alice.age > 18);
```

As you may have guessed, `derived` is syntactic sugar on top of `computed`:

```ts
function derived<a>(fn: () => a): Signal<a> {
  return connect({
    value: computed(fn),
  });
}
```

Now that we have a `socialMediaAllowed_` signal, we can use it to decide whether to show the social media content or not or our app.

### useTilia

Begin observing connected objects and automatically respond to their changes. When using this call, the render function of the React component will behave like the callback passed to the `observe` function.

**install**

```sh
npm install @tilia/react
```

```ts
import { useTilia } from "@tilia/react";

function App() {
  useTilia();

  if (socialMediaAllowed_.value === true) {
    return <SocialMedia />;
  } else {
    return <NormalApp />;
  }
}
```

## Main features

- Zero dependencies
- Single proxy tracking
- Compatible with ReScript and TypeScript
- Inserted objects are not cloned.
- Tracking follows moved or copied objects.
- Respects `readonly` or classes (these elements are not proxied).
- Leaf-tracking (observe read values only).
- Computed values (cached calculations, recomputed on read when changed).
- Forest mode: tracking across multiple instances.

## Internals

To be used for binding to other frameworks/libraries:

```ts
// Create an observer by connecting a callback to a Tilia object
// or array and start recording viewed nodes.
export function _observe<a>(tree: a, callback: () => void): observer;
// Register the observer as ready. If a watched field changed during recording, notify
// if notifyIfChanged is true.
export function _ready(
  observer: observer,
  notifyIfChanged: boolean = true
): void;
// Remove observer.
export function clear(observer: observer): void;
```

# ReScript example

```res
open Tilia

type clouds = {
  mutable morning: string,
  mutable evening: string,
}
type state = {
  mutable flowers: string,
  mutable clouds: clouds,
}

// Create a tracked object or array:
let tilia = make()

let tree = tilia.connect({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
})

// Observe and react to changes
tilia.observe(() => {
  Js.log2("Evening Clouds", tree.clouds.evening)
})
```

The call to `Tilia.make` creates a tilia context with `connect` and `observe` functions.

We then create an observer that will run if anything that it reads from the
tree changes. For example, the observer above watches "clouds" and "evening" inside the clouds
object but not "flowers" or "morning".

Now, changing the color of the evening clouds like this:

```res
tree.clouds.evening = "fiery blue"
```

Will trigger the logging of the cloud color.

## Main Features

- Zero dependencies
- Single proxy tracking (should be fast)
- Compatible with ReScript and TypeScript
- Inserted objects are not cloned.
- Tracking follows moved objects and objects in arrays or other objects.
- Simple API for reactive programming.
- Respects readonly properties and classes.
- Leaf-tracking: observes only what is read.
- Supports computed values (cached calculations).
- Supports forest mode: tracking across multiple instances.
- Supports context isolation for SSR or other environments.

### Changelog (for tilia)

- 2025-05-09 **2.0.0** (not yet release: canary version)
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
