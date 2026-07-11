---
title: What keeps it honest
slug: what-keeps-it-honest
sort: 9
refs: [computed, make]
---

A library that promises "the running program stays true to the declaration" owes you an account of the failure modes: what happens when a computation is declared in the wrong place, when a callback throws, when observers come and go by the thousands. tilia's answers are specific, and they are the reason the rest of this guide could be so confident.

### The glue zone

`computed`, `source` and `store` return *definitions*, not values. A definition only comes to life when it is inserted into a tilia object. Between creation and insertion lies what the docs call the **glue zone** — and a definition that never gets inserted is an **orphan computation**, a ghost that is neither a value nor attached to anything. Before v4, touching one produced obscure errors far from the mistake.

Since v4, every definition is wrapped in a **safety proxy**. Inside a reactive context — a `tilia` or `carve` object — it unwraps transparently. Outside, it throws a descriptive error the moment it is used:

```typescript
// ❌ Bad: the definition lingers in a variable
const dueSoon = computed(() => card.dueDate <= clock.today);
const count = dueSoon ? 1 : 0;
// 💥 Error: orphan computation detected

// ✅ Good: defined directly in the object
const card2 = tilia({
  ...fields,
  dueSoon: computed(() => card2.dueDate <= clock.today),
});
```

```rescript
// ❌ Bad: the definition lingers in a variable
let dueSoon = computed(() => card.dueDate <= clock.today)
let count = dueSoon ? 1 : 0
// 💥 Error: orphan computation detected

// ✅ Good: defined directly in the object
let card2 = tilia({
  ...fields,
  dueSoon: computed(() => card2.dueDate <= clock.today),
})
```

The golden rule: **never** assign the result of a `computed`, `source` or `store` to an intermediate variable — **always** define them directly inside a `tilia` or `carve` object. The safety proxy exists so that breaking the rule fails loudly, at the line that broke it.

### When a callback throws

An exception inside a `computed` or `observe` callback could poison the whole reactive graph. Instead, tilia does four things, in order: the exception is **caught** immediately; the error is **logged** to `console.error` with a stack trace cleaned of library internals, so the top frame is *your* code; the faulty observer is **cleared**, so it cannot block the system; and the error is **re-thrown** at the end of the next flush, so it still reaches your application's error handling.

One broken observer, one loud report, everyone else keeps working. The reactive system degrades one callback at a time, never as a whole — an application with a bug stays an application.

::: pro
Handle expected failures inside the computed itself — catch and return an error value, or fall back to a default — and let the clearing behavior be what it is meant to be: a safety net for the unexpected.
:::

### Growth and cleanup

Two garbage collectors share the work. JavaScript's native GC handles the big one: a tilia object no longer referenced anywhere is released, dependencies and all, with nothing to call on your side. tilia's own GC handles the small one: each observed property keeps a list of watchers, and when watchers are cleared — a React component unmounting, an observer being replaced — the emptied lists linger. After a threshold of cleared watchers (50 by default, configurable), tilia sweeps them.

The default suits most applications; an app with heavy mount/unmount churn can raise the threshold to sweep less often, a very stable one can lower it. The knob lives on `make`, which also answers a question this guide has quietly skirted:

```typescript
import { make } from "tilia";

const ctx = make(100); // a separate context: its own forest, its own observers
const card = ctx.tilia({ front: "gato" });
```

```rescript
open Tilia

let ctx = make(~gc=100) // a separate context: its own forest, its own observers
let card = ctx.tilia({front: "gato"})
```

Everything you have used so far — `tilia`, `observe`, `computed`, all of it — belongs to a default context created for you. `make` builds another, with the full API and complete isolation: objects from different contexts do not share tracking, even when they touch the same underlying data. One context is right for almost every application; the escape hatch exists for libraries and unusual hosts.

That is the whole safety story: mistakes fail fast and near their cause, crashes stay local, and memory is tended without ceremony. One chapter remains — a step back, to see what was actually built.
