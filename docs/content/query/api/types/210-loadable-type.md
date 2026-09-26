---
name: Loadable
slug: loadable-type
kind: type
module: core
since: "0.1"
sort: 210
summary: Represent waiting, available data, or an explained absence.
tags: []
signature.ts: |-
  type Loadable<T> =
    | "loading"
    | { state: "loaded", claim: Claim, data: T }
    | { state: "noData", reason: Reason }
signature.res: |-
  @tag("state")
  type loadable<'a> =
    | @as("loading") Loading
    | @as("loaded") Loaded({claim: claim, data: 'a})
    | @as("noData") NoData({reason: reason})
label: Loadable
---

`Loadable` is returned by [one](api.html#one) and [array](api.html#array):

- `"loading"` / `Loading` means no usable answer is available yet.
- `loaded` / `Loaded` carries data and its [Claim](api.html#claim-type).
- `noData` / `NoData` carries a [Reason](api.html#reason-type).

An empty `partial` answer is not data. It stays loading while a remote answer is possible and becomes offline `NoData` otherwise. A complete empty `array` answer is loaded; only `one` projects it to `NoMatch`.

```typescript
// One renderer for every read. `claim` is a field, so the loaded branch
// renders first and only the view asks how strong the answer is.
const render = <T>(value: Loadable<T>, view: (data: T, claim: Claim) => Node) => {
  if (value === "loading") return spinner();
  if (value.state === "loaded") return view(value.data, value.claim);
  return empty(value.reason);
};
```

```rescript
// One renderer for every read. `claim` is a field, so the loaded branch
// renders first and only the view asks how strong the answer is.
let render = (value, view) =>
  switch value {
  | Loading => spinner()
  | Loaded({data, claim}) => view(data, claim)
  | NoData({reason}) => empty(reason)
  }
```
