---
name: make
slug: make
kind: function
module: core
since: "1.0"
sort: 10
summary: Create an isolated Tilia context with its own reactive world.
signature:
  ts: "function make(gc?: number): Tilia"
  res: "let make: (~gc: int=?, unit) => tilia"
tags: []
---

`make` creates a context object containing the Tilia API (`tilia`, `carve`, `observe`, `watch`, `batch`, `signal`, `derived`, `source`, `store`, `_observe`).

Each context is isolated: observers and proxies from one context do not share tracking with another context. Use this for uncorrelated reactive worlds.

`gc` sets the cleared-watcher garbage-collection threshold. Default is `50`. See [tilia](api.html#tilia), [Tilia](api.html#tilia-type), and guide chapter [What keeps it honest](docs.html#what-keeps-it-honest).

```typescript
import { make } from "tilia";

const a = make();
const b = make();
const left = a.tilia({ count: 0 });
const right = b.tilia({ count: 0 });
left.count = 1;
right.count = 2;
```

```rescript
open Tilia

let a = make()
let b = make()
let left = a.tilia({count: 0})
let right = b.tilia({count: 0})
left.count = 1
right.count = 2
```
