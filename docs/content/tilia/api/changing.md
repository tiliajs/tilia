---
name: changing
slug: changing
kind: function
module: core
since: "5.2"
sort: 130
summary: Track key-level dict writes as drained upsert/remove batches.
signature:
  ts: "function changing<T>(accessor: () => Record<string, T>, guard?: () => boolean): Changing<T>"
  res: "let changing: (unit => dict<'a>, ~guard: unit => bool=?) => changing<'a>"
tags: [deprecated]
---

`changing` is deprecated. Prefer explicit mutate actions in carved features and `tilia/query` for data flow.

`changing` tracks key-level writes on a Tilia-proxied dictionary returned by `accessor`.

It returns `{ changes, mute }`. `changes` is a capture function for [watch](api.html#watch) that drains accumulated writes into `{ upsert, remove }` (`upsert` contains latest written objects, `remove` contains deleted keys). Last write wins per key. Each `changing()` call has an independent accumulator.

If `guard` is provided and returns `false`, changes accumulate silently. When `guard` becomes `true`, accumulated changes drain as one batch. `mute(fn)` performs writes without tracking them for this accumulator, while keeping normal reactivity.

Use this only for legacy connectors that still depend on direct repository writes.

```typescript
import { changing, tilia, watch } from "tilia";

const rows = tilia<Record<string, { qty: number }>>({});
const { changes, mute } = changing(() => rows);

watch(changes, ({ upsert, remove }) => {
  void upsert;
  void remove;
});

rows.a = { qty: 1 };
mute(() => {
  rows.b = { qty: 2 };
});
```

```rescript
open Tilia

type row = {qty: int}

let rows: dict<row> = tilia(Dict.make())
let {changes, mute} = changing(() => rows)

watch(changes, ({upsert, remove}) => {
  ignore(upsert)
  ignore(remove)
})

rows->Dict.set("a", {qty: 1})
mute(() => {
  rows->Dict.set("b", {qty: 2})
})
```
