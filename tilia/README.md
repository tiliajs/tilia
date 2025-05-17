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
import { make, computed, clear } from "tilia";

// Create a tilia context:
const { connect, observe } = make();

// Add an object to the "forest" so that it can be observed.
const tree = connect({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
});

// Observe and react to changes from what was seen in the
// callback (here key "clouds" in tree and key "evening" in clouds).
// Note that the observe function will see changes from trees in
// the same forest (tilia context).
observe(() => {
  console.log("Evening Clouds", tree.clouds.evening);
  // We can write to observed data in the callback (for computations for example)
  tree.clouds.evening = tree.clouds.evening + " are nice";
});

// NB: to stop tracking with `observe`, simply avoid reading anything in the callback.

const mimic = connect({
  clouds: {
    morning: computed(() => tree.clouds.morning),
    evening: "can be orange",
  },
});

// Todo example
type Auth = {
  user?: { id: number };
};

const auth: Auth = connect({
  user: undefined,
});

async function fetchTodos(authUser: Auth["user"], todos: Todos) {
  const response = await fetch(`https://jsonplaceholder.typicode.com/todos`);
  todos.data = (await response.json()).filter(
    (todo) => todo.userId === owner.id
  );
  todos.state = "loaded";
}

const todos = connect({
  state: "locked",
  data: computed(() => {
    if (auth.user) {
      todos.state = "loading";
      fetchTodos(auth.user, todos);
    } else {
      todos.state = "locked";
    }
    return []; // Temporary data while loading
  }),
  selectedId: undefined,
  selected: computed(() => data.find((todo) => todo.id === todos.selectedId)),
});
```

The call to `make` creates a tiia context. We can then create a proxy object or array by using the `connect` function from this context.

And then we create observers that will run if anything that it reads from the
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
