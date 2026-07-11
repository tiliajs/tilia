---
name: lift
slug: lift
kind: function
module: core
since: "3.0"
sort: 110
summary: Lift a signal into a computed value for object insertion.
signature:
  ts: "function lift<T>(s: Signal<T>): T"
  res: "let lift: signal<'a> => 'a"
tags: []
---

`lift` converts a signal into an inserted computed value by tracking `s.value`.

It is equivalent to `computed(() => s.value)`, and is used when an object should expose a signal as a read-only field while keeping mutation through the signal setter.

See [signal](api.html#signal), [computed](api.html#computed), and guide chapter [A small vocabulary](docs.html#a-small-vocabulary).

```typescript
import { lift, signal, tilia } from "tilia";

const [title, setTitle] = signal("A");

const todo = tilia({
  title: lift(title),
  setTitle,
});

todo.setTitle("B");
todo.title;
```

```rescript
open Tilia

let (title, setTitle) = signal("A")

let todo = tilia({
  title: title->lift,
  setTitle,
})

todo.setTitle("B")
ignore(todo.title)
```
