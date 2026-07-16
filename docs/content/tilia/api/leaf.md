---
name: leaf
slug: leaf
kind: function
module: react
since: "3.0"
sort: 140
summary: Wrap a React component with exact render dependency tracking.
signature:
  ts: "function leaf<T, U>(fn: (p: T) => U): (p: T) => U"
  res: "let leaf: ('a => 'b) => 'a => 'b"
tags: []
---

`leaf` wraps a component so reads of Tilia proxies during render are tracked with exact render boundaries.

When tracked keys change, the wrapped component re-renders. The API is equivalent to a higher-order component and is the preferred React integration over [useTilia](api.html#use-tilia).

See guide chapter [tilia in React](guide.html#tilia-in-react) and [useComputed](api.html#use-computed).

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
