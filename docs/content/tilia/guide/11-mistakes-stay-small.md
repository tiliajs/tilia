---
title: Mistakes stay small
slug: mistakes-stay-small
sort: 11
refs: [computed, make]
---

Trust needs a floor. Adèle signs Claudine's diffs; Alice signs the scenarios; the suite guards the behavior. But somebody — human or AI — will eventually get it wrong anyway, and what happens *then* decides whether collaboration stays convivial or turns cautious. tilia's answers are specific.

::: story
Sunday's nightly import delivers a card with no interval — a malformed row from the shared deck. Somewhere inside, a computed throws. On Alice's phone: the queue still turns, the streak still counts. One card is quietly absent, and one line of red has appeared in the log, pointing at the exact function that choked.
:::

### When a callback throws

An exception inside a `computed` or `observe` callback could poison the whole reactive graph. Instead, tilia does four things, in order: the exception is **caught** immediately; the error is **logged** with a stack trace cleaned of library internals, so the top frame is *your* code; the faulty observer is **cleared**, so it cannot block the system; and the error is **re-thrown** at the end of the next flush, so it still reaches the application's error handling.

One broken observer, one loud report, everyone else keeps working. The reactive system degrades one callback at a time, never as a whole — an application with a bug stays an application.

### A bug is a missing scenario

Monday morning, Adèle does what `CONTRIBUTING.md` says. She does not start with the fix; she starts with the drawing:

```gherkin
Scenario: an imported card without an interval
  Given an imported card "sol" with no interval
  Then "sol" waits 1 day
```

Red. Then Claudine makes it green — a malformed import now defaults gently instead of throwing — and the suite is one scenario richer. The bug cannot come back without a red line saying so, and the decision ("waits 1 day") is recorded where all decisions live: in Alice's words, in the ledger, checked forever.

::: pro
Handle *expected* failures inside the computed itself — catch and return a fallback. Let the clearing behavior be what it is meant to be: a safety net for the unexpected.
:::

### Failing near the cause

The other half of the floor you have already met: in [chapter 4](#values-that-follow), Claudine stranded a `computed` in a variable and the mistake failed loudly *at that line* — not three files away as a wrong value. Every definition (`computed`, `source`, `store`) is wrapped in a safety proxy: inside a `tilia` or `carve` object it unwraps transparently; anywhere else, it throws a descriptive error the moment it is used. Mistakes surface where they are made, which is exactly where a new collaborator — permanently new, in Claudine's case — needs them to surface.

### Growth and cleanup

Long-lived apps accumulate and shed observers by the thousand — components mounting and unmounting, sessions starting and ending. Two garbage collectors share the work: JavaScript's own GC releases any tilia object no longer referenced, dependencies and all; tilia's internal GC sweeps the bookkeeping left by cleared observers after a threshold (50 by default). The knob lives on [`make`](api.html#make), which also builds fully isolated reactive contexts — a niche need for libraries and unusual hosts; one context is right for almost every application.

That is the whole safety story, and it is short on purpose: mistakes fail fast and near their cause, crashes stay local, memory is tended without ceremony — and every lesson learned becomes a scenario, so it is only ever learned once. One chapter remains: a step back, to see what was actually built.
