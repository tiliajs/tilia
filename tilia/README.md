# Tilia

Tilia is a simple state management library for "FRP" style programming.

This package contains the core FRP engine.

To use this library with React, please use [@tilia/react](https://github.com/tiliajs/tilia).

This package is compatible with _TypeScript_ and _ReScript_, you can find the examples for the latter at the end.

# WARNING: This is the documentation for the canary version (2.0.0)

You can check the [todo app](../todo-app-ts/README.md) for a working example using TypeScript or [todo app re](../todo-app-re/README.md) for a work in progress using ReScript.

## Installation

```sh
npm install tilia
```

## Usage

### connect

Connect an object to the forest so that it can be observed.

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

Observe and react to changes from what was seen in the callback.

```ts
import { observe } from "tilia";

observe(() => {
  console.log("Alice is now", alice.age, "years old !!");
});
```

Now every time alice's age changes, the callback will be called.

But I want to update her age automagically from today's date!

### signal

Use `signal` to represent a value that changes, such as a date.

```ts
import { signal } from "tilia";

const [now, setNow] = signal(dayjs());

setInterval(() => setNow(dayjs()), 1000 * 60);
```

Ok, we now have a "now" signal, let's use it to update alice's age. But before, I must share a little secret: the `signal` function is just syntax sugar on top of `connect`.

```ts
function signal<a>(value: a): Signal<a> {
  const s = connect({ value });
  const set = (v) => (s.value = v);
  return [s, set];
}
```

### computed

Compute a value from other connected objects (other signals or values).

```ts
import { computed } from "tilia";

const alice = connect({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  age: computed(() => now.diff(alice.birthday, "year")),
});
```

The computed is _not_ just syntax sugar. It is an important feature of the library and only recomputes (or notifies) when needed. The rule goes like this:

1. If there are observers on "alice.age" and a dependency for the calculation changes, the computation is run.
2. If the result of a new computation is different from the previous one, the observers are notified.
3. Without observers, the computation is only run on first read (and then saved for next reads).

With this in place, our message on Alice's age will only be printed when the age changes, so we can use it to wish Alice a happy birthday:

```ts
import { observe } from "tilia";

observe(() => {
  console.log("Alice is now", alice.age, "years old !! Happy birthday Alice !");
});
```

This is nice but it will print the message when our app starts, printing a wish that does not correspond to an age change.

### update

Update a value from the current value and other connected objects (other signals or values).

```ts
import { update } from "tilia";

update(alice.age, (previous) => {
  if (alice.age !== previous) {
    console.log("Alice is now", alice.age, "years old !!");
    console.log("*** 🥳🩷 Happy Birthday Alice !! 🩷🥳 **");
  }
  return alice.age;
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
