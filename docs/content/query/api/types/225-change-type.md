---
name: Change
slug: change-type
kind: type
module: core
since: "0.1"
sort: 225
summary: Describe local context when a remote value arrives.
tags: []
signature.ts: |-
  type Change<T> =
    | { change: "clean", value: T }
    | { change: "created", edited: T }
    | { change: "updated", base: T, edited: T }
    | { change: "removed", base: T }
signature.res: |-
  @tag("change")
  type change<'a> =
    | @as("clean") Clean({value: 'a})
    | @as("created") Created({edited: 'a})
    | @as("updated") Updated({base: 'a, edited: 'a})
    | @as("removed") Removed({base: 'a})
label: Change
---

`Change` is passed to the shipped store's `merge` callback with an incoming remote value:

- `clean` carries the current value when no write is pending.
- `created` carries the latest local create.
- `updated` carries the original `base` and latest `edited` value.
- `removed` carries the value removed locally.

The callback runs inside `Tilia.batch`. Mutate the local object in place and return `true` to merge. Return `false` to keep remote truth and record the corresponding conflict.

```typescript
// Field-level merge. Alice changed `back`; Nora, elsewhere, `seen`. Keep both:
// a field Alice left alone takes the remote's value, and her write goes again.
const merge = (change: Change<Card>, remote: Card) => {
  switch (change.change) {
    case "clean":
      Object.assign(change.value, remote);
      return true;
    case "updated": {
      const { base, edited } = change;
      if (edited.seen === base.seen) edited.seen = remote.seen;
      if (edited.back === base.back) edited.back = remote.back;
      return true;
    }
    default:
      return false; // a create or a remove against a row the server holds: record the conflict
  }
};
```

```rescript
// Field-level merge. Alice changed `back`; Nora, elsewhere, `seen`. Keep both:
// a field Alice left alone takes the remote's value, and her write goes again.
let merge = (~change, ~remote) =>
  switch change {
  | Clean({value}) =>
    value.back = remote.back
    value.seen = remote.seen
    true
  | Updated({base, edited}) =>
    if edited.seen === base.seen {
      edited.seen = remote.seen
    }
    if edited.back === base.back {
      edited.back = remote.back
    }
    true
  | Created(_) | Removed(_) => false // a create or a remove against a row the server holds: record the conflict
  }
```
