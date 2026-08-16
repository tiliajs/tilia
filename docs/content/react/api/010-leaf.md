---
name: leaf
slug: leaf
kind: function
module: react
since: "3.0"
sort: 10
summary: Wrap a React component with exact render dependency tracking.
tags: []
signature.ts: "function leaf<T, U>(fn: (p: T) => U): (p: T) => U"
signature.res: "let leaf: ('a => 'b) => 'a => 'b"
label: leaf(fn)
---

`leaf` wraps a component and uses exact render boundaries to track reads of Tilia proxies during rendering.

When tracked keys change, the wrapped component re-renders. The API is equivalent to a higher-order component and is preferred over [useTilia](api.html#use-tilia) for React integration.

See the [React overview](index.html) and [useComputed](api.html#use-computed).

```typescript
import { leaf } from "@tilia/react";

const Counter = leaf(() => {
  return <p>{app.count}</p>;
});
```

```rescript
open TiliaReact

@react.component
let make = leaf(() => {
  <p> {app.count->React.int} </p>
})
```
