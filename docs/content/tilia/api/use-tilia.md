---
name: useTilia
slug: use-tilia
kind: hook
module: react
since: "2.0"
sort: 150
summary: Track reactive reads in a React component render.
signature:
  ts: "function useTilia(): void"
  res: "let useTilia: unit => unit"
tags: []
---

`useTilia` enables reactive tracking for the current component render. Call it at the top of the component.

Reads of Tilia proxies during render become dependencies. When one of those dependencies changes, the component re-renders. `useTilia` is the hook form; [leaf](api.html#leaf) is the preferred wrapper when possible.

See guide chapter [tilia in React](guide.html#tilia-in-react) and related hook [useComputed](api.html#use-computed).

```typescript
import { useTilia } from "@tilia/react";

function Counter() {
  useTilia();
  return <p>{app.count}</p>;
}
```

```rescript
open TiliaReact

@react.component
let make = () => {
  useTilia()
  <p> {app.count->React.int} </p>
}
```
