---
title: A small vocabulary
slug: a-small-vocabulary
sort: 8
refs: [signal, derived, lift, readonly]
---

Alice wants a streak — days in a row with every due card reviewed. It is one number, and it raises a question Claudine asks before writing anything: *who may change it?* Anyone should read it; only the review logic should bump it. The question is about ownership, and tilia answers it the way this guide answers everything — with a word.

Four small words round out tilia's vocabulary: `signal`, standalone `derived`, `lift`, and `readonly`. Three are one-liners over what you already know. They earn their place not by adding power but by **naming intentions** — and knowing they are thin keeps the mental model lean: there is still only one mechanism underneath.

### signal, lift: reading is public, writing is owned

You have already seen [`signal`](api.html#signal) and [`lift`](api.html#lift) work together to carry today's date into the deck. A signal is a mutable record with one `value` field, returned together with a setter; `lift` inserts its current value into another object as a computed. The steps owned `setToday`, while the deck received a public `today` that it could only read. Alice's streak uses the same split:

```typescript
import { signal, lift, tilia } from "tilia";

const [streak, setStreak] = signal(0);
// setStreak stays inside the review logic

const stats = tilia({
  streak: lift(streak), // ✅ readable by anyone, writable by no one else
});
```

```rescript
open Tilia

let (streak, setStreak) = signal(0)
// setStreak stays inside the review logic

let stats = tilia({
  streak: streak->lift, // ✅ readable by anyone, writable by no one else
})
```

The domain exposes `stats.streak` in domain language; neither the signal nor its setter leaves the module. A whole class of "who owns this value" bugs cannot be written — the ownership is not a convention in a comment, it is the shape of the code.

::: story
Seven days in a row. The number on Alice's screen and the number the session logic increments are the same value — there is no copy to drift.
:::

Standalone [`derived`](api.html#derived) rounds out the pair: it creates a signal from other reactive values — a value that follows, living on its own before it has a home in a larger object.

### readonly: opting out

Tracking costs a little, and immutable data does not need it. [`readonly`](api.html#readonly) wraps a value so tilia leaves it alone — reads return the original data untouched, writes throw. The deck catalogue Alice browses — hundreds of decks, updated never — rides along inside the reactive app without paying for reactivity it will not use:

```typescript
import { readonly } from "tilia";

const app = tilia({
  catalogue: readonly(allDecks), // large, static: not tracked
});
```

```rescript
open Tilia

let app = tilia({
  catalogue: readonly(allDecks), // large, static: not tracked
})
```

That is the whole vocabulary — small enough that this guide has now shown every word of it. What remains is subtler than any single function: *when*, exactly, do reactions run? The answer involves midnight again, and this time for real.
