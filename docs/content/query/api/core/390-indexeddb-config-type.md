---
name: IndexedDB Config
slug: indexeddb-config-type
kind: type
module: core
since: "0.1"
sort: 390
summary: Configure the TypeScript/JavaScript IndexedDB keyspace.
tags: []
signature.ts: |-
  type Config = {
    name: string,
    store?: string,
    version?: number,
    onError?: (error: Error) => void
  }
signature.res: |-
  type TiliaQueryIndexedDb.config = {
    name: string,
    store?: string,
    version?: float,
    onError?: JsError.t => unit,
  }
label: IndexedDB config
---

TypeScript exports `Config` from `@tilia/query/indexeddb`; ReScript exposes the same contract as `TiliaQueryIndexedDb.config`.

- `name` is the required database name.
- `store` is the object-store name. Default: `"entries"`.
- `version` is the database version. Default: `1`.
- `onError` receives database-open and transaction-abort errors. Failed reads still answer with no values and failed writes are dropped because [Kv](api.html#kv-type) persistence is command-only.

```typescript
import type { Config } from "@tilia/query/indexeddb";

const config: Config = { name: "cards", onError: console.error };
```

```rescript
let config: TiliaQueryIndexedDb.config = {
  name: "cards",
  onError: _error => (),
}
```
