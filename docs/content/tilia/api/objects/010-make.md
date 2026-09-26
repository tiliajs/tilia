---
name: make
slug: make
kind: function
module: core
since: "1.0"
sort: 10
summary: Create an isolated Tilia context with its own reactive world.
tags: []
signature.ts: "function make(gc?: number): Tilia"
signature.res: "let make: (~gc: int=?, unit) => tilia"
label: make(gc?)
---

`make` creates a context object containing the Tilia API (`tilia`, `carve`, `observe`, `watch`, `batch`, `signal`, `derived`, `source`, `store`, `_observe`).

Each context is isolated: observers and proxies from one context do not share tracking with another context. Use this to create independent reactive worlds.

`gc` sets the garbage-collection threshold for cleared watchers. The default is `50`. See [tilia](api.html#tilia), [Tilia](api.html#tilia-type), and the guide chapter [Mistakes stay small](guide.html#mistakes-stay-small).

```typescript
import { make } from "tilia";

// One context is right for almost every application, and the top-level
// functions use it. A library that must not share tracking with its host —
// a plugin rendered inside someone else's tilia app — builds its own.
const plugin = make();
const { tilia, observe } = plugin;

const state = tilia({ visible: false });
observe(() => {
  panel.hidden = !state.visible;
});

// The other reason to call it: the garbage-collection threshold. A host that
// mounts and unmounts thousands of observers a minute may sweep less often.
const app = make(500);
```

```rescript
open Tilia

// One context is right for almost every application, and the top-level
// functions use it. A library that must not share tracking with its host —
// a plugin rendered inside someone else's tilia app — builds its own.
let plugin = make()

let state = plugin.tilia({visible: false})
plugin.observe(() => panel.hidden = !state.visible)->ignore

// The other reason to call it: the garbage-collection threshold. A host that
// mounts and unmounts thousands of observers a minute may sweep less often.
let app = make(~gc=500)
```
