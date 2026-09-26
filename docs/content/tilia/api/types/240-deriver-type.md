---
name: Deriver
slug: deriver-type
kind: type
module: core
since: "2.0"
sort: 240
summary: Helper object passed to carve for self-based derivation.
tags: []
signature.ts: "type Deriver<U> = { derived: <T>(fn: (p: U) => T) => T }"
signature.res: "type deriver<'p> = {derived: 'a. ('p => 'a) => 'a}"
label: Deriver
---

The `Deriver<U>`/`deriver<'p>` type is the helper parameter received by [carve](api.html#carve).

Its `derived` method binds the carved object as input for self-based derivations.

```typescript
import { carve, lift } from "tilia";
import type { Deriver } from "tilia";

// The factory `carve` calls, written as a named function so the deck can be
// built from several places — the app, a test, a fixture — with the same
// derivations. `derived` hands `queue` and `review` the object under
// construction, which is how they read sibling fields.
const build = (repo: Repo, today: Signal<string>) => ({ derived }: Deriver<Deck>): Deck => ({
  repo,
  today: lift(today),
  cards: repo.load(),
  queue: derived(queue),
  review: derived(review),
});

const deck = carve(build(repo, today));
```

```rescript
open Tilia

// The factory `carve` calls, written as a named function so the deck can be
// built from several places — the app, a test, a fixture — with the same
// derivations. `derived` hands `queue` and `review` the object under
// construction, which is how they read sibling fields.
let build = (repo, today: signal<string>) => ({derived}: deriver<deck>): deck => {
  repo,
  today: lift(today),
  cards: repo.load(),
  queue: derived(queue),
  review: derived(review),
}

let deck = carve(build(repo, today))
```
