---
name: TiliaReact
slug: tilia-react-type
kind: type
module: react
since: "2.0"
sort: 300
summary: Context-bound React integration surface for Tilia.
signature:
  ts: |-
    type TiliaReact {
      useTilia: () => void;
      useComputed: <T>(fn: () => T) => T;
      leaf: <T, U>(fn: (p: T) => U) => (p: T) => U
    }
  res: |-
    type tilia_react = {
      useTilia: unit => unit,
      useComputed: 'a. (unit => 'a) => 'a,
      leaf: 'a 'b. ('a => 'b) => 'a => 'b
    }
tags: []
---

`TiliaReact`/`tilia_react` is the React API object shape returned by [react make](api.html#react-make).

It groups `useTilia`, `useComputed`, and `leaf` for one core context.

See [leaf](api.html#leaf), [useTilia](api.html#use-tilia), and [useComputed](api.html#use-computed).

```typescript
import { make as makeCore } from "tilia";
import { make as makeReact } from "@tilia/react";
import type { TiliaReact } from "@tilia/react";

const reactApi: TiliaReact = makeReact(makeCore());
void reactApi.leaf;
```

```rescript
open TiliaReact

let reactApi: tilia_react = make(Tilia.make())
ignore(reactApi.leaf)
```
