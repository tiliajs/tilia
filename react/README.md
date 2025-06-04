# React hook for Tilia

This provides the react hook `useTilia` for tilia state management. For
documentation, please see the [monorepo](https://github.com/tiliajs/tilia/blob/main/README.md).

Check the [**website**](https://tiliajs.com) for documentation and examples.

## API (in case the website is not available)

### ReScript

```res
open Tilia
let useTilia: unit => unit
/** Create a useTilia hook from (_observe, _ready, _clear) */
let makeUseTilia: (
  (unit => unit) => observer,
  (observer, bool) => unit,
  observer => unit,
) => unit => unit
```

### TypeScript

```ts
import type { Tilia } from "tilia";
export const useTilia: () => void;
export const makeUseTilia: (ctx: Tilia) => () => void;
```

## Example

```tsx
import { connect } from "tilia";
import { useTilia } from "@tilia/react";

const alice = connect({
  name: "Alice",
  age: 10,
});

// If alice.name or alice.age changes, this will re-rendered.
function ShowPerson() {
  useTilia();

  return (
    <div>
      <p>Name: {alice.name}</p>
      <p>Age: {alice.age}</p>
    </div>
  );
}
```
