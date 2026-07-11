---
name: Tilia
slug: tilia-type
kind: type
module: core
since: "2.0"
sort: 250
summary: Context object type containing one complete Tilia API surface.
signature:
  ts: |-
    type Tilia = {
      tilia: <T>(branch: T) => T,
      carve: <T>(fn: (deriver: Deriver<T>) => T) => T,
      observe: (fn: () => void) => void,
      watch: <T>(fn: () => T, effect: (v: T) => void) => void,
      batch: (fn: () => void) => void,
      signal: <T>(value: T) => [Signal<T>, Setter<T>],
      derived: <T>(fn: () => T) => Signal<T>,
      source: <T>(
        initialValue: T,
        fn: (previous: T, set: Setter<T>) => unknown
      ) => T,
      store: <T>(fn: (set: Setter<T>) => T) => T,
      changing: <T>(
        accessor: () => Record<string, T>,
        guard?: () => boolean
      ) => Changing<T>,
      _observe: (callback: () => void) => Observer
    }
  res: |-
    type tilia = {
      tilia: 'a. 'a => 'a,
      carve: 'a. (deriver<'a> => 'a) => 'a,
      observe: (unit => unit) => unit,
      watch: 'a. (unit => 'a, 'a => unit) => unit,
      batch: (unit => unit) => unit,
      signal: 'a. 'a => (signal<'a>, setter<'a>),
      derived: 'a. (unit => 'a) => signal<'a>,
      source: 'a 'ignored. ('a, ('a, 'a => unit) => 'ignored) => 'a,
      store: 'a. (('a => unit) => 'a) => 'a,
      _observe: (unit => unit) => observer,
    }
tags: []
---

`Tilia`/`tilia` is the context object returned by [make](api.html#make).

It packages a full API set bound to one reactive root context. Proxies and observers from different contexts are isolated.

In TypeScript, this surface includes `changing`; that API is deprecated in favor of explicit mutate actions and `tilia/query`.

Use this type when passing a context explicitly (for example into [react make](api.html#react-make)).

```typescript
import { make } from "tilia";
import type { Tilia } from "tilia";

const ctx: Tilia = make();
void ctx.observe;
```

```rescript
open Tilia

let ctx: tilia = make()
ignore(ctx.observe)
```
