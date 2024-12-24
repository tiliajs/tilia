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

### Changelog (for @tilia/core)

- 2024-12-24 **1.2.3** Rewrite tracking to fix notify and clear before ready.
- 2024-12-18 **1.2.2** Fix readonly tracking: should not proxy.
- 2024-12-18 **1.2.1** Fix bug to not track prototype methods.
- 2024-12-18 **1.2.0** Improve ownKeys watching, notify on key deletion.
- 2024-12-18 **1.1.1** Fix build issue (rescript was still required)
- 2024-12-17 **1.1.0** Add support to share tracking between branches.
- 2024-12-13 **1.0.0** Alpha release.
