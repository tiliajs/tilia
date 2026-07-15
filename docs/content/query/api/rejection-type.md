---
name: Rejection
slug: rejection-type
kind: type
module: core
since: "0.1"
sort: 230
summary: An op the remote definitively refused.
signature:
  ts: |-
    type Rejection<T> = {
      id: string,
      op: Op<T>,
      message: string
    }
  res: |-
    type rejection<'a> = {
      id: string,
      op: op<'a>,
      message: string,
    }
tags: []
---

`Rejection` is an op the remote definitively refused — the result of a [WriteChannel](api.html#write-channel-type)`.fail`. Rejections live in [status](api.html#status)`.rejected`.

- `id` is the op's value id — the key [retry](api.html#retry) and [discard](api.html#discard) match on. At most one rejection per id: a newer rejection replaces the older.
- `op` is the refused operation, `message` the remote's reason.

Edge cases:

- A rejected op keeps overlaying remote deliveries like a pending one — the refused edit stays visible until `retry` re-queues it or `discard` reverts it.
- The op's persisted outbox entry is kept. After a restart it reloads as pending, the re-push fails again, and the rejection resurfaces on its own.

See guide chapter [When the server disagrees](guide.html#when-the-server-disagrees).

```typescript
import type { Rejection } from "@tilia/query";

const describe = (r: Rejection<Card>) =>
  `${r.id}: ${r.message}`;
```

```rescript
let describe = (r: TiliaQuery.rejection<card>) =>
  `${r.id}: ${r.message}`
```
