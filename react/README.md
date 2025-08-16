# React hooks for tilia

Check the [**website**](https://tiliajs.com) for documentation and examples.

## API (in case the website is not available)

(TypeScript version below)

### ReScript

```res
open Tilia
type tilia_react = {
  useTilia: unit => unit,
  useComputed: 'a. (unit => 'a) => signal<'a>,
  leaf: 'a 'b. ('a => 'b) => 'a => 'b,
}

let useTilia: unit => unit
let useComputed: (unit => 'a) => signal<'a>
let leaf: ('a => 'b) => 'a => 'b

/**
 * Create api from a tilia context.
 */
let make: tilia => tilia_react
```

### TypeScript

```ts
import type { Tilia } from "tilia";
export interface TiliaReact {
  useTilia: () => void;
  useComputed: <T>(fn: () => T) => signal<A>;
}

export function useTilia(): void;
export function useComputed<T>(fn: () => T): signal<T>;

/**
 * Create api from a tilia context.
 */
export function make(tilia: Tilia): TiliaReact;
```

## Example

```tsx
import { tilia } from "tilia";
import { useTilia, useComputed } from "@tilia/react";

const alice = tilia({
  name: "Alice",
  age: 10,
});

// If alice.name or alice.age changes, this will re-rendered.
function ShowPerson({ person }: { person: Person }) {
  useTilia();

  const selected = useComputed(() => app.selected.id === person.id);

  return (
    <div className={selected ? "selected" : ""}>
      <p>Name: {person.name}</p>
      <p>Age: {person.age}</p>
    </div>
  );
}

// Or using the `leaf` HOC:
const ShowPerson = leaf({ person }: { person: Person }) => {
  const selected = useComputed(() => app.selected.id === person.id);

  return (
    <div className={selected ? "selected" : ""}>
      <p>Name: {person.name}</p>
      <p>Age: {person.age}</p>
    </div>
  );
});
```

The HOC has a better observing feature because we can close the observing phase
at the exact end of the render function (unlike `useTilia` which waits for the
next `useTilia` call).
