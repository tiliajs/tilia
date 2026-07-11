---
name: Changing
slug: changing-type
kind: type
module: core
since: "5.2"
sort: 270
summary: Change-tracker handle exposing capture and mute operations.
signature:
  ts: "interface Changing<T> { changes: () => Changes<T>; mute: (fn: () => void) => void }"
  res: "type changing<'a> = {changes: unit => changes<'a>, mute: (unit => unit) => unit}"
tags: [deprecated]
---

`Changing<T>`/`changing<'a>` is deprecated, along with [changing](api.html#changing). Prefer explicit mutate actions in carved features and `tilia/query` for data flow.

`Changing<T>`/`changing<'a>` is the return type of [changing](api.html#changing).

`changes` is used as a capture function for [watch](api.html#watch). `mute` temporarily disables outbound tracking for this tracker while keeping normal reactive updates.

```typescript
import { changing, tilia } from "tilia";
import type { Changing } from "tilia";

const rows = tilia<Record<string, { qty: number }>>({});
const tracker: Changing<{ qty: number }> = changing(() => rows);
void tracker.mute;
```

```rescript
open Tilia

type row = {qty: int}

let rows: dict<row> = tilia(Dict.make())
let tracker: changing<row> = changing(() => rows)
ignore(tracker.mute)
```
