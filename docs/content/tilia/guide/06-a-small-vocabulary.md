---
title: A small vocabulary
slug: a-small-vocabulary
sort: 6
refs: [signal, derived, lift, readonly]
---

Four more words complete tilia's vocabulary: `signal`, `derived` (standalone), `lift`, and `readonly`. Three of them are syntactic sugar — each is a one-liner over what you already know. They earn their place not by adding power but by naming intentions, and knowing they are thin keeps the mental model honest: there is still only one mechanism underneath.

### signal: one value, one setter

A signal is a single changing value of any type — a tilia object with just a `value` field, plus a setter:

```typescript
const signal = (v) => {
  const s = tilia({ value: v });
  return [s, (v) => { s.value = v }];
};
```

```rescript
let signal = v => {
  let s = tilia({value: v})
  (s, v => s.value = v)
}
```

That is the entire implementation. Use it when a value has no natural home in a larger object yet — or when you want to keep the *writing* of a value private.

### derived and lift

Standalone `derived` creates a signal from other reactive values — `signal(computed(fn))`, nothing more. And `lift` inserts a signal's current value into a tilia object as a computed — `computed(() => s.value)`.

Together with `signal`, they make a tidy privacy pattern. Alice's streak should be visible everywhere but bumped only by review logic:

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

::: story
Seven days in a row. The number on Alice's screen and the number her session logic increments are the same value — there is no copy to drift.
:::

What this spares is a whole class of "who owns this value" bugs: the domain object exposes `stats.streak` in domain language, while the setter never leaves the module that has the right to use it.

### readonly: opting out of tracking

Tracking costs a little, and immutable data does not need it. `readonly` wraps a value so tilia leaves it alone — reads return the original data untouched, and writes throw:

```typescript
import { readonly } from "tilia";

const app = tilia({
  catalogue: readonly(allDecks), // large, static: not tracked
});

const decks = app.catalogue.data; // the original object, no proxy

// 🚨 'set' on proxy: trap returned falsish for property 'data'
app.catalogue.data = otherDecks;
```

```rescript
open Tilia

let app = tilia({
  catalogue: readonly(allDecks), // large, static: not tracked
})

let decks = app.catalogue.data // the original object, no proxy

// 🚨 'set' on proxy: trap returned falsish for property 'data'
app.catalogue.data = otherDecks
```

The deck catalogue Alice browses — hundreds of decks, updated never — rides along inside the reactive app without paying for reactivity it will not use.

That is the whole vocabulary. What remains is subtler than any single function: *when*, exactly, do reactions run? The next chapter is about time.
