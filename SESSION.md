# Session — splitting `@tilia/query`

**Where things stand: 49/49 green, phases 0 through 2c done, 2d next.**
Nothing is committed — Anna owns the history.

The decisions are in `TILIA-QUERY-SPLIT.md` and the shape they imply is
`query/src/croquis/TiliaQuerySplit.res` (a sketch that compiles, not code).
The ledger is `query/test/TiliaQuery.feature`; the scenarios still waiting to
land are in `TILIA-QUERY-SCENARIOS.md`, one per decided rule, each tagged with
the phase that makes it pass.

The 41 scenarios that shipped are the only safety net for a refactor this
size, so no step leaves the suite red past its own end.

## How to work here

    cd query
    npx rescript                 # build (ReScript 12, in-source .mjs)
    npx rescript format <files>  # before finishing a step
    pnpm test                    # vitest-bdd over test/*.feature

- **Never commit.** Anna does that.
- **Behaviour before structure.** Phase 2 changes what the code does, in the
  single file it already lives in; phase 3 moves it. Mixing the two means a
  red test cannot tell you which one broke it.
- **Mutation-check every rule you add.** Break the line that implements it,
  confirm the scenario you just wrote fails, put it back. Twice so far this
  caught a rule that was passing on another rule's strength, and once it
  showed a guard was redundant rather than untested.
- **New scenarios go beside the ones they relate to**, not appended: the
  feature file reads top to bottom as one story.
- Steps live in `test/TiliaQuerySteps.res`, the world in `test/MakeWorld.res`.
  `vitest-bdd` binds `X.feature` to `XSteps.res`.

## The harness, as it now stands

Test controls added during phase 2, all driven from steps:

- `Dexme.partial` — local storage answers `channel.partial` instead of
  `channel.local`: it holds rows but will not claim they are the whole answer.
- `Rules` — per-operation server outcomes: `rejects` (id → message, standing),
  `conflicts` (id → row, **one-shot**, because a standing conflict would spin
  the outbox), `transientFrom`, `failAfter`. Controlled replies go out through
  `network.respond` wrapped in a promise, so they land in queue order behind
  the real ones — that is what makes `fail after "cat.es"` arrive *after*
  cat.es was accepted.
- `Papabase._put` — write a row with its version, bypassing the version check,
  so a scenario can put the server ahead of the client.
- `numericVersion` in the steps — table cells are strings and `version` is a
  number on the server; anything crossing that line needs converting.
- `onError` recorder — failures the read site was never told about.

## Plan

- [x] **0 · Map.** Classify every touch of `itemById`, `idsByKey`, `entries`,
      `registry` and `outbox` as A or B+C. Notes below.
- [x] **1 · Scenarios as one batch.** `TILIA-QUERY-SCENARIOS.md`: three
      existing scenarios rewritten, sixteen added — one per decided rule — and
      a rename sweep over all 41. Cut from 34 after review: the batch had one
      scenario per conceivable case instead of one per rule. All of it lands
      in `TiliaQuery.feature` on the existing harness — Gherkin is the
      translation layer, so a rule is stated as behaviour and the
      implementation stays out of it. Five gaps are deferred as pre-existing.
      One scenario needs the harness strengthened before it can fail at all:
      a store that replays synchronously in its own constructor.
- [ ] **2 · Behaviour, on the monolith.** Each step green at its end. New
      scenarios go beside the ones they relate to, not appended: the file
      reads top to bottom as one story.
  - [x] 2a `claim` + `NoData`; `one`/`array` projection; empty-`Partial`;
        entry gains a `Partial` state; the no-weakening rule. **45/45.**
        Landed: the §0 rename sweep and rules 1–4. `Channel.read.set` became
        `fresh` and `Channel.local` went from `{set, unknown}` to `{partial,
        local}`, so `unknown()` is now `partial([])` and the empty-partial
        rule lives in `project`, read by both `one` and `array`. Checked by
        mutation: breaking `project` fails four scenarios, two of them
        pre-existing.
  - [x] 2b failure rule — keep `Loaded`, route the rest to `onError`.
        **45/45.** The two shipped scenarios inverted as predicted, and
        nothing else moved. `tick`'s refresh gate had to change with it: it
        keyed on the result being `Failed`, which the new rule stops
        producing when there is data to keep, so it now asks whether the
        entry is stale — anything but live, and anything but a first find
        still open. Both halves mutation-checked.
  - [x] 2c per-op `conflict` + `reject`, and the `set`-with-`merge` bug.
        **49/49.** `Channel.write` gained `conflict` and `reject`; the push
        now tracks which operations were *answered* rather than one `settled`
        flag, and `fail` iterates in outbox order instead of backwards. `set`
        no longer calls `reconcile`: confirming is confirming, and rebasing is
        what `conflict` is for — which is the bug fixed. Harness gained
        `Rules` (per-operation server outcomes, replying through the network
        queue so a `fail` after an accepted write really lands after it).
  - [ ] 2d rejection recovery — `retry`/`discard`, snapshots, outbox order.
        Four scenarios in `TILIA-QUERY-SCENARIOS.md` (rules 10, 11, 13, 14)
        and four new steps: `I retry the rejection for`, `I discard the
        rejection for`, `the remote stops rejecting` (delete from
        `Rules.rejects`), `the remote replies out of order` (a `reversed` flag
        on `Rules`). Three things to decide or find out:
        1. **How to snapshot.** `Updated({base, edited})` holds the *live*
           objects: `base` is what `place` puts back, so a later remote change
           mutates the rejection under the app. Clone at refusal, in `revert`
           and in the `conflict` reject branch. The store's own contract
           already requires values to survive a JSON round trip, so
           `JSON.parse(JSON.stringify(v))` is the cheap answer; there is no
           dependency to add.
        2. **`dismiss` becomes `retry` + `discard`** on `t` and in the
           `.resi`. `retry` re-enqueues the snapshot as a new optimistic
           write — the local value is back at `base`, so the change context
           recomputes with no special path. `discard` just drops the record.
        3. **`addRejection` (`:467`) appends or replaces in place.** Ordering
           has to come from the operation's seq, not from reply arrival.
           `TODO.md` carries a second half of this: `applyPending` overlays
           rejections in dict order.
  - [ ] 2e harness: a store that replays synchronously during construction
- [ ] **3 · The split, behaviour-neutral.** No scenario changes here; if one
      needs editing, behaviour moved by accident.
  - [ ] 3a `Schema.t` resolved once, threaded through
  - [ ] 3b store-side touches of engine state routed through
        `item`/`changed`/`removed`/`place` — still one file
  - [ ] 3c engine's find path routed through `{online, find, forget}` — still
        one file
  - [ ] 3d files split: `TiliaQueryEngine.res`, `TiliaQueryStore.res`,
        `TiliaQuery.res` as the assembly; `source.forget` on eviction only
- [ ] **4 · The new surface.**
  - [ ] 4a `connect: binding => (source, 'store)`; `Store.make`/`Store.custom`;
        `Query.make` with `store:`
  - [ ] 4b `Kv.t`, memory keyspace as default, `persist`
  - [ ] 4c registry lookup, scan fallback, `lookup?` — `Partial` first becomes
        reachable from the shipped store here
  - [ ] 4d `@tilia/query/indexeddb` subpath: `exports`, esbuild, clean-package
- [ ] **5 · Proof and product.**
  - [ ] 5a `claims-app-ts` adaptor on paper, before `Store.config` is locked
  - [ ] 5b guide and API reference
  - [ ] 5c `claims-app-ts` migrated, after the refactor ships

## Decided in review

**An answer may not weaken a claim while a find is open.** `Partial` cannot
replace `Local` or `Fresh`, and `Local` cannot replace `Fresh`. Only `tick`
lowers a claim, as data ages.

Why it is needed: today A asks local storage only while the entry is
`Pristine` (`TiliaQuery.res:252`) — "local only materializes a query, a
refresh would discard its answer". After the split A calls `source.find` for
refreshes too, and the store does not know entry state, so it answers from
local storage again and a `Fresh` result would flicker to `Local`. The rule
falls out of the lattice, costs nothing, and no store author can get it wrong.
The alternative — passing the current claim into `find` — was rejected: it
adds a parameter and every store has to honour it. Scenario: *a refresh does
not weaken a result while it is in flight*.

**`settled` is redundant, not untested.** Flipping it off breaks no
scenario, because after `fail` every unanswered operation has already left the
outbox and `waiting` rejects a late reply on its own. Left in as a cheap guard
against a channel that answers twice; not worth a scenario.

**`tick` now refreshes anything not fresh.** 2b replaced the old gate
(`LoadedRemote`, or a `Failed` result) with `stale`: false while live, false
while a first find is still open, true otherwise. A `LoadedPartial` or
`LoadedLocal` entry is now refreshed on the heartbeat, which the old gate did
only by way of the `Failed` result the new failure rule no longer produces.

**Two shipped scenarios change meaning.** Under "a failure replaces the result
only when there is no data to show", *a failed fetch replaces a local result
and retries* (`:508`) and *a live source failure recovers on the next
delivery* (`:612`) both assert the opposite: they expect the data to be
replaced by the failure. Rewritten in the batch, not deleted — the retry half
of each still holds.

**`dispose` writes nothing, on either side.** Dating the registry on the way
out was a rule and has been dropped: `tick` re-dates an observed record at
most one refresh window apart (`TiliaQuery.res:1042`), so a clean shutdown is
at worst 30 seconds stale against a 30-day expiry, and an early purge heals on
the next find. It was carrying a flush guarantee, an ordering rule, a harness
demand and a completion-aware `dispose` — all for 0.001% of the window.
`Store.dispose()` also never closes `persist`: `Kv.t` has no lifecycle and one
keyspace can back several stores, so closing belongs to whoever created it.

## Notes from the map

**Clean, A.** `entryState`, `entry`, `entries`, `results`, `itemById`,
`idsByKey`, `observedKeys`, `getResult`, `makeGetEntry`, `makeOne`,
`makeArray`, the `build` computed, memory eviction, `_canopy`, `sort`, `key`.

**Clean, B+C.** `outboxOp` and its codec, `queryRecord` and its codec,
`registry`, `persistRecord`, `outbox`, `status`, rejections, `persistOp`,
`confirmed`, `pending`, `applyPending`, `conflict`, `failed`, `merged`,
`enqueue`, `upsert`, `remove`, `receiveChanged`, `receiveRemoved`, boot
replay, `purgeLocal`, `dismiss`, local expiry.

**Straddlers — the actual work of phase 3.**

- `loaded` (`:641`) reconciles, applies pending and pushes to local (B), then
  writes `itemById`, `recordSeen`, `idsByKey` and `results` (A). It splits
  cleanly because the store knows the values before it hands them over:
  `recordSeen` runs store-side, then `channel.fresh(values)`.
- `join` (`:514`) walks `entries` (A) and `registry` (B) in one loop. Each
  half keeps its own walk over its own dict, both using `matches` from the
  schema. That applies the documented linear-scan bet twice instead of once —
  the cost is real and is the price of the boundary.
- `forget` (`:550`) deletes from `itemById` and `idsByKey` (A), from the
  registry, and pushes a local remove (B). Becomes `binding.removed` plus the
  store's own work.
- `reconcile` (`:604`) is pure B but reads `itemById` at `:634`. Becomes
  `binding.item(rid)` — the one place the getter is load-bearing.
- `makeFetch` (`:227`) orchestrates local-then-remote. Both collapse into
  `source.find`, and A stops knowing there are two tiers. `unknown()` (`:245`)
  becomes the store answering `partial([])` and A's empty-`Partial` rule.
  This is where the open decision above bites.
- `tick` (`:1029`) does A's refresh, demote and evict, and B's purge and
  push. Splits into `engine.tick()` then `store.tick()`, in that order, which
  is the order the current code already runs them in.
- The online watch (`:926`) refetches (A) and pushes (B). Each half watches
  `online` for its own reason.

## Standing

- `one` is **untested**. No scenario and no step touches it, and `one` is
  exactly where `NoMatch` and the empty-`Partial` projection live. The batch
  gets its first, under rule 4. Fuller coverage is deferred: it is a
  pre-existing gap, not this refactor's. `one(query)` selects the first result
  of a query — it is not a lookup by id (`TiliaQuery.res:347`), which the
  first draft of the batch got wrong.
- `TODO.md` already carries two items that belong to 2d: rejections overlaying
  in dict order rather than by seq, and the restart-with-rejection scenario the
  `.resi` promises. The first is in scope; the second is deferred as a
  pre-existing gap.
- `TODO.md` also wants the query-language constraint stated in the `.resi`:
  queries are pure predicates over one row, no limits, no pagination, no
  aggregates. It belongs to 4a, when the `.resi` is rewritten anyway.
- How `dist/index.d.ts` is produced is unchecked. The read model and the
  constructors both change the TypeScript surface, and `claims-app-ts` is a TS
  consumer.
- Whether vitest-bdd honours scenario tags is unchecked. It decides whether a
  phase can land scenarios as skipped or has to trickle them in.
