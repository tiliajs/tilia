# Tilia

Tilia is a simple state management library for "FRP" style programming.

This package contains the core FRP engine.

To use this library with React, please use [@tilia/react](https://github.com/tiliajs/tilia).

This package is compatible with _TypeScript_ and _ReScript_, you can find the examples for the latter at the end.

## Installation

```sh
npm install tilia
```

## Usage

```ts
import { tilia, observe, track, clear } from "tilia";

// Create a tracked object or array:
const tree = tilia({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
});

// Observe and react to changes from what was seen in the
// callback (here key "clouds" in tree and key "evening" in clouds).
observe(tree, () => {
  console.log("Evening Clouds", tree.clouds.evening);
  // We can write to observed data in the callback (for computations for example)
  tree.clouds.evening = tree.clouds.evening + " are nice";
});

// Track and react to any change in the observed branch (here 'tree.clouds')
const observer = track(tree.clouds, () => {
  console.log("Something changed", tree.clouds);
  // We should be careful when we write to the tracked branch to avoid
  // infinite loops.
});

// Stop tracking.
clear(observer);

// NB: to stop tracking with `observe`, simply avoid reading anything in the callback.

// Compute value on the fly. The callback is called on read.  Note that if the
// computing function needs to start an async operation, it is their
// responsability to set a proper value before yielding. Something like a
// Loading state or a Promise. Without such a value, undefined will be returned
// and might not match the actual type of the value.
let observer = compute(tree.clouds, () => {
  // When something is changed on the observed values, the cached value is
  // cleared and will be recomputed on first read.
  tree.clouds.morning = tree.clouds.evening + " are not the same";
});

// Remove computed value.
clear(observer);
```

The call to `tilia` creates a proxy object or array.

And then we create an observer that will run if anything that it reads from the
tree changes. For example, the observer above watches "clouds" and "evening" inside the clouds
object but not "flowers" or "morning".

Now, changing the color of the evening clouds like this:

```ts
tree.clouds.evening = "fiery blue";
```

Will trigger the logging of the cloud color.

## Features

- Zero dependencies
- Single proxy tracking
- Compatible with ReScript and TypeScript
- Inserted objects are not cloned.
- Tracking follows moved or copied objects.
- Respects `readonly` properties.
- Leaf-tracking (observe read values).
- Tracking (observe a whole branch).
- Computed values (cached calculations, recomputed on read when changed).

## Internals

To be used for binding to other frameworks/libraries:

```ts
// Create an observer by connecting a callback to a Tilia object
// or array and start recording viewed nodes.
export function _connect<a>(tree: a, callback: () => void): observer;
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
let tree = make({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
})

// Observe and react to changes
observe(tree, (_) => {
  Js.log2("Evening Clouds", tree.clouds.evening)
})
```

The call to `Tilia.make` creates a tracked object or array.

And then we create an observer that will run if anything that it reads from the
tree changes. For example, the observer above watches "clouds" and "evening" inside the clouds
object but not "flowers" or "morning".

Now, changing the color of the evening clouds like this:

```res
tree.clouds.evening = "fiery blue"
```

Will trigger the logging of the cloud color.
