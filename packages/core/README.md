# Tilia Core

Tilia is a simple state management library for "FRP" style programming.

This package contains the core engine. If you need to use this library
with React, please use [@tilia/react](https://github.com/tiliajs/tilia) instead.

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

## Internals

To be used for binding to other frameworks/libraries:

\*\*
export function make<a extends object>(tree: a): a;
export function \_connect<a>(tree: a, callback: () => void): observer;
export function \_flush(observer: observer): void;
export function \_clear(observer: observer): void;
export function observe<a>(tree: a, fn: (tree: a) => void): void;
