---
name: Readonly
slug: readonly-type
kind: type
module: core
since: "2.0"
sort: 220
summary: Wrapper type exposing immutable data through a data field.
signature:
  ts: "type Readonly<T> = { readonly data: T }"
  res: "type readonly<'a> = {data: 'a}"
tags: []
---

`Readonly<T>`/`readonly<'a>` is the wrapper produced by [readonly](api.html#readonly).

It exposes `data` and prevents replacing the `data` property itself.

The wrapped value is not proxied for nested tracking.

```typescript
import type { Readonly } from "tilia";

const ro: Readonly<{ version: number }> = { data: { version: 1 } };
void ro.data.version;
```

```rescript
open Tilia

type schema = {version: int}

let ro: readonly<schema> = {data: {version: 1}}
ignore(ro.data.version)
```
