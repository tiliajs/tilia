---
name: make
slug: react-make
kind: function
module: react
since: "1.0"
sort: 170
summary: Create a React API bound to a specific Tilia context.
signature:
  ts: "function make(tilia: Tilia): TiliaReact"
  res: "let make: tilia => tilia_react"
tags: []
---

`@tilia/react` `make` builds a React integration object (`useTilia`, `useComputed`, `leaf`) from a provided core [Tilia](api.html#tilia-type) context.

Use this with core [make](api.html#make) when an application needs isolated, uncorrelated reactive worlds.

The package-level exports are the default-context version; this function is the context-bound version.

```typescript
import { make as makeCore } from "tilia";
import { make as makeReact } from "@tilia/react";

const ctx = makeCore();
const reactApi = makeReact(ctx);
void reactApi.useTilia;
```

```rescript
let ctx = Tilia.make()
let reactApi = TiliaReact.make(ctx)
ignore(reactApi.useTilia)
```
