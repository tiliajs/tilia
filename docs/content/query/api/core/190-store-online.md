---
name: Store.online
slug: store-online
kind: function
module: core
since: "0.1"
sort: 190
summary: Return the shared browser connectivity signal.
tags: []
signature.ts: "Store.online(): Signal<boolean>"
signature.res: "Store.online: unit => Tilia.signal<bool>"
label: Store.online()
---

`Store.online` returns the process-wide connectivity signal used by [Store.make](api.html#store-make) when `online` is omitted. In environments with `addEventListener`, it follows browser online/offline events. Where connectivity cannot be observed, it is `true` so writes are not permanently blocked.

```typescript
const online = Store.online();
```

```rescript
let online = Store.online()
```
