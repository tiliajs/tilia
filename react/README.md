# Tilia React

Tilia is a simple state management library.

This package contains the hook for React. It is compatible with _TypeScript_ and
_ReScript_, you can find the examples for the latter at the end.

## Installation

```sh
npm install @tilia/react
```

## Usage

```tsx
import { tilia, observe, useTilia } from "@tilia/react";

// Create a tracked object or array:
const state: MyState = tilia({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
});

// Observe 'evening' and update 'morning' with a calculation.
observe(state, () => {
  state.clouds.morning = state.clouds.evening + ", maybe";
});

function Clouds(props: { clouds: MyState["clouds"] }) {
  // Start observing the clouds props (must be a tilia object).
  const clouds = useTilia(props.clouds);
  function onChange(e) {
    // Write to a tilia object and trigger re-draw in
    // observers.
    clouds.evening = e.target.value;
  }

  // Will register this component as watching the "evening"
  // property inside clouds.
  return (
    <div>
      <input value={clouds.evening} onChange={onChange} />
    </div>
  );
}
```

Note that you can re-insert a tracked object inside the same tree and share
state and tracking.

## How tracking works

An observer registers itself whenever it **READS** a key inside a tracked object or array.

For example:

```ts
const groceries = tilia({
  fruits: {
    bananas: 5,
    apples: 10,
  },
  veggies: {
    salad: 2,
  },
});

observe(groceries, () => {
  console.log("⚠️⚠️", "Banana count is now", groceries.fruits.bananas);
});
```

What happens if someone does this ?

```ts
// A
groceries.fruits.apples = 12;
```

Does the banana observer get triggered ?

What about this ?

```ts
// B
groceries.fruits = {
  bananas: 5,
  apples: 10,
};
```

Or this ?

```ts
// C
Object.assign(groceries.fruits, { bananas: 8 });
```

In **A**, nothing happens because the "bananas observer" only read keys "fruits" and "bananas", and here
only the value for the "apples" key is changed.

In **B**, the "bananas observer" sees that there is a write to the "fruits" key that it watches and gets triggered, even though the content of the object is the same because tilia only checks for direct equality (`===`) to avoid triggering on same value write.

In **C**, the "bananas" key gets written and triggers the observer.

## "Index observer"

What about this observer ?

```ts
// D
observe(groceries, () => {
  console.log("I like these fruits:", Object.keys(groceries.fruits).join(", "));
});
```

When is this triggered ?

```ts
// A
groceries.fruits.bananas = 15;
```

Or this ?

```ts
// B
groceries.fruits.oranges = 2;
```

The "index observer" watches changes to the keys (adding or removing keys), but not to the
values that the keys contain. This means that the observer, is not triggered with **A** but
is triggered with **B**.

That's it !

# ReScript example

```res
open JsxEvent.Form

type clouds = {
  mutable morning: string,
  mutable evening: string,
}
type state = {
  mutable flowers: string,
  mutable clouds: clouds,
}

// Create a tracked object or array:
let tree = Tilia.make({
  flowers: "are beautiful",
  clouds: { morning: "can be pink", evening: "can be orange" },
})

// Observe 'evening' and update 'morning' with a calculation.
Tilia.observe(state, () => {
  state.clouds.morning = state.clouds.evening ++ ", maybe"
})

@react.component
let make(~clouds: clouds) {
  // Start observing the clouds props (must be a tilia object).
  let clouds = Tilia.use(clouds)
  let onChange = (e) => {
    // Write to a tilia object and trigger re-draw in
    // observers.
    clouds.evening = target(e)["value"]
  }

  // Will register this component as watching the "evening"
  // property inside clouds.
  <div>
    <input value={clouds.evening} onChange />
  </div>
}
```

Please check the documentation for [@tilia/core](../core/README.md) for technical details on how tracking is done.

## Little sandbox examples

- [An input field](https://codesandbox.io/p/sandbox/react-ts)

### Changelog

See [core/changelog](https://github.com/tiliajs/tilia)
