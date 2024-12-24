# Tilia Core

Tilia is a simple state management library for "FRP" style programming.

This package contains the core engine. If you need to use this library
with React, please use [@tilia/react](https://github.com/tiliajs/tilia) instead.

This package is compatible with _TypeScript_ and _ReScript_, you can find the examples for the latter at the end.

## Installation

```sh
npm install @tilia/core
```

## Usage

```ts
import { tilia, observe } from "@tilia/core";

// Create a tracked object or array:
const tree = tilia({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
});

// Observe and react to changes
observe(tree, () => {
  console.log("Evening Clouds", tree.clouds.evening);
});
```

The call to `tilia` creates a tracked object or array.

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

## Internals

To be used for binding to other frameworks/libraries:

```ts
// Create an observer by connecting a callback to a Tilia object
// or array and start recording viewed nodes.
export function _connect<a>(tree: a, callback: () => void): observer;
// Register the observer as ready. If a watched field changed during recording, notify
// if notifyIfChanged is true.
export function _ready(observer: observer, notifyIfChanged: boolean = true): void;
// Remove observer.
export function _clear(observer: observer): void;
```

# ReScript example

```res
open TiliaCore

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

The call to `TiliaCore.make` creates a tracked object or array.

And then we create an observer that will run if anything that it reads from the
tree changes. For example, the observer above watches "clouds" and "evening" inside the clouds
object but not "flowers" or "morning".

Now, changing the color of the evening clouds like this:

```res
tree.clouds.evening = "fiery blue"
```

Will trigger the logging of the cloud color.
