# Tilia React

Tilia is a simple state management library for "FRP" style programming with
React.

This package contains the hook for React.

This package is compatible with _TypeScript_ and _ReScript_, you can find the
examples for the latter at the end.

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


# ReScript example

```res
open TiliaCore
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
let tree = make({
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
