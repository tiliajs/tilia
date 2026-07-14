---
name: Loadable
slug: loadable-type
kind: type
module: core
since: "0.1"
sort: 210
summary: A value as seen by the read path — five honest states.
signature:
  ts: |-
    type Loadable<T> =
      | "loading"
      | { state: "loaded", data: T, fresh: boolean }
      | "notFound"
      | "notLocal"
      | { state: "failed", message: string }
  res: |-
    @tag("state")
    type loadable<'a> =
      | @as("loading") Loading
      | @as("loaded") Loaded({data: 'a, fresh: bool})
      | @as("notFound") NotFound
      | @as("notLocal") NotLocal
      | @as("failed") Failed({message: string})
tags: []
---

`Loadable` is what [one](api.html#one) and [array](api.html#array) answer.

- `Loading` — no source has answered yet. A progress state: show a spinner.
- `Loaded` — data, with a `fresh` flag (see below).
- `NotFound` — the fetch completed empty. Only `one` answers it; `array` answers an empty `Loaded`.
- `NotLocal` — the offline dead end: nothing cached locally and the remote unreachable. Unlike `Loading` it is an answer, not progress — show "not available offline", not a spinner.
- `Failed` — the fetch error, carried to the place where the value is read. There is no global error slot to join against.

`fresh` says whether the data is known-fresh from the remote (`true`) or served from cache (`false`). It describes trust, not where the rows physically live.

- On [tick](api.html#tick), a non-live remote result with no delivery within `expiry.refresh` flips to `fresh: false`; the next remote delivery flips it back.
- While online, the flip waits one extra refresh-check period (`expiry.refresh / 8`) so an in-flight refresh can land without a flip/flop. Offline, it flips right at the limit.

More edge cases:

- `NotLocal` only appears while offline. Online, an empty local answer keeps the query `Loading` until the remote responds.
- A `Failed` non-live query is not stuck: it re-enters the refresh loop and is retried once per refresh window.

See guide chapter [Reads answer twice](docs.html#reads-answer-twice).

```typescript
import type { Loadable } from "@tilia/query";

function label(result: Loadable<Card[]>): string {
  if (result === "loading") return "…";
  if (result === "notFound") return "not found";
  if (result === "notLocal") return "not available offline";
  if (result.state === "failed") return result.message;
  return result.fresh ? "fresh" : "cached";
}
```

```rescript
let label = (result: TiliaQuery.loadable<array<card>>) =>
  switch result {
  | Loading => "…"
  | NotFound => "not found"
  | NotLocal => "not available offline"
  | Failed({message}) => message
  | Loaded({fresh: true}) => "fresh"
  | Loaded({fresh: false}) => "cached"
  }
```
