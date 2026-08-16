---
name: make
slug: react-make
kind: function
module: react
since: "1.0"
sort: 40
summary: Create a React API bound to a specific Tilia context.
tags: []
signature.ts: "function make(tilia: Tilia): TiliaReact"
signature.res: "let make: tilia => tilia_react"
label: make(tilia)
---

`make` from `@tilia/react` builds a React integration object (`useTilia`, `useComputed`, `leaf`) from a provided core [Tilia](../api.html#tilia-type) context.

Use it with core [make](../api.html#make) when an application needs isolated reactive worlds that do not affect one another.

The package-level exports provide the default-context version; this function provides the context-bound version.

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
