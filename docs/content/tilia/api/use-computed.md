---
name: useComputed
slug: use-computed
kind: hook
module: react
since: "2.0"
sort: 160
summary: Compute a React value and re-render only when the result changes.
signature:
  ts: "function useComputed<T>(fn: () => T): T"
  res: "let useComputed: (unit => 'a) => 'a"
tags: []
---

`useComputed` evaluates `fn` in reactive tracking and returns its result.

The hook compares computed results and re-renders when the result value changes. This differs from plain render reads, which depend on every tracked key read during render.

Use with [useTilia](api.html#use-tilia) or [leaf](api.html#leaf) in React components. See guide chapter [tilia in React](guide.html#tilia-in-react).

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
