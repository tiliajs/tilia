---
name: readonly
slug: readonly
kind: function
module: core
since: "2.0"
sort: 120
summary: Wrap data in a non-writable holder to avoid nested tracking.
tags: []
signature.ts: "function readonly<T>(data: T): Readonly<T>"
signature.res: "let readonly: 'a => readonly<'a>"
label: readonly(data)
---

`readonly` returns an object with a non-writable `data` property. The wrapped value is returned as-is and is not proxied for nested tracking.

Use this to insert large immutable data blocks into a reactive tree while preventing accidental replacement of the wrapped `data` field.

See [tilia](api.html#tilia) and guide chapter [A small vocabulary](guide.html#a-small-vocabulary).

```typescript
import { readonly, tilia } from "tilia";

const app = tilia({ schema: readonly({ version: 1 }) });
app.schema.data.version;
```

```rescript
open Tilia

let app = tilia({schema: readonly({version: 1})})
ignore(app.schema.data.version)
```
