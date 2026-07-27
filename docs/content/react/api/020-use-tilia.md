---
name: useTilia
slug: use-tilia
kind: hook
module: react
since: "2.0"
sort: 20
summary: Track reactive reads in a React component render.
tags: []
signature.ts: "function useTilia(): void"
signature.res: "let useTilia: unit => unit"
label: useTilia()
---

`useTilia` enables reactive tracking for the current component render. Call it at the top of the component.

Reads of Tilia proxies during render become dependencies. When one of those dependencies changes, the component re-renders. `useTilia` is the hook form; [leaf](api.html#leaf) is the preferred wrapper when possible.

See the [React overview](index.html) and related hook [useComputed](api.html#use-computed).

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
