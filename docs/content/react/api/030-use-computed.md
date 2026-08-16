---
name: useComputed
slug: use-computed
kind: hook
module: react
since: "2.0"
sort: 30
summary: Compute a React value and re-render only when the result changes.
tags: []
signature.ts: "function useComputed<T>(fn: () => T): T"
signature.res: "let useComputed: (unit => 'a) => 'a"
label: useComputed(fn)
---

`useComputed` evaluates `fn` with reactive tracking and returns its result.

The hook compares successive computed results and re-renders when the result changes. This differs from plain render reads, which depend on every tracked key read during rendering.

Use it with [useTilia](api.html#use-tilia) or [leaf](api.html#leaf) in React components. See the [React overview](index.html).

```typescript
import { useComputed, useTilia } from "@tilia/react";

function TodoRow({ todo }: { todo: { id: string } }) {
  useTilia();
  const selected = useComputed(() => app.selectedId === todo.id);
  return <div className={selected ? "selected" : ""} />;
}
```

```rescript
open TiliaReact

@react.component
let make = (~todo) => {
  useTilia()
  let selected = useComputed(() => app.selectedId === todo.id)
  <div className={selected ? "selected" : ""} />
}
```
