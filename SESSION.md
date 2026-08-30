# Session — splitting `@tilia/query`

**Where things stand: 60/60 green, phases 0 through 4c done, 5a done on
paper. 4d is what is left of phase 4.**
Committed through 4a's first half, on `main`, at Anna's word — the ledger
below is what each commit did.

The decisions are in `TILIA-QUERY-SPLIT.md`, which was the whole spec phase 3
was built from.
The ledger is `query/test/TiliaQuery.feature`; the complete scenario batch is
in `TILIA-QUERY-SCENARIOS.md`, one per decided rule, each tagged with the
phase that makes it pass.

The 41 scenarios that shipped are the regression baseline for a refactor this
size. Together with the new scenarios, they must stay green at the end of
every step.

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
- Four files since 3d, and the dependency order is a line:
  `TiliaQuerySchema.res` (what both halves speak) → `TiliaQueryEngine.res`
  (A, plus `binding` and `source`) → `TiliaQueryStore.res` (B+C) →
  `TiliaQuery.res` (the assembly, and every public type re-exported). If a
  change needs the engine to know a store word, or the store to reach a row
  except through the binding, it is in the wrong file.

## The harness, as it now stands

Test controls added during phase 2, all driven from steps:

- `Dexme.partial` — local storage answers `channel.partial` instead of
  `channel.local`: it holds rows but will not claim they are the whole answer.
- `Rules` — per-operation server outcomes: `rejects` (id → message, standing),
  `conflicts` (id → row, **one-shot**, because a standing conflict would spin
  the outbox), `transientFrom`, `failAfter`. Controlled replies go out through
  `network.respond` wrapped in a promise, so they land in queue order behind
  the real ones — that is what makes `fail after "cat.es"` arrive *after*
  cat.es was accepted. `reversed` (2d) holds the controlled replies of a push
  and answers them backwards, so a scenario can ask for a rejection to arrive
  before the one that caused it.
- `Papabase._put` — write a row with its version, bypassing the version check,
  so a scenario can put the server ahead of the client.
- `numericVersion` in the steps — table cells are strings and `version` is a
  number on the server; anything crossing that line needs converting.
- `onError` recorder — failures the read site was never told about.
- `PapabaseStore` (4a) — the same simulated server described by outcomes
  instead of channels, and `makeOutcomes` to build the app on it. It is the
  reference for what an application writes against `Store.make`: three
  functions and a translation table.
- `DexmeKv` (4b) — the Dexie-like table wired as a `Kv`, one entry per row
  keyed `tag/key`. `DexmeIndex` (4c) is the same table read as an index, for
  the `lookup` scenario: same author, which is the point.
- `SyncStore` (3d) — a store whose replay is synchronous: it puts its rows
  into the engine inside its own constructor and answers finds by reading
  them back through `binding.item`. `makeSync` assembles it into a
  `TiliaQuery.t` whose write side is stubbed, so every read step works
  against it unchanged.
- `I retry the rejection for {string}` keeps the record it was handed, so
  `the retried rejection should still show english {string}` can ask what the
  application is still holding after the row moved on. The only harness work
  the 2d proof gaps needed: the other two scenarios are written entirely from
  controls that were already there.

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
      a store that replays synchronously in its own constructor. It waits for
      3d, where `binding` and `connect` exist.
- [x] **2 · Behaviour, on the monolith.** Each step green at its end. New
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
        now tracks which operations were *answered*, while `settled` closes
        the whole push after `retry` or `fail`; `fail` iterates in outbox order
        instead of backwards. `set` no longer calls `reconcile`: confirming is
        confirming, and rebasing is what `conflict` is for — which is the bug
        fixed. Harness gained `Rules` (per-operation server outcomes, replying
        through the network queue so a `fail` after an accepted write really
        lands after it).
  - [x] 2d rejection recovery — `retry`/`discard`, snapshots, outbox order.
        **53/53.** All three questions resolved into one place: `addRejection`
        took `~seq` and became the single boundary where a live change turns
        into a historical record. It copies the whole rejection through the
        store's JSON contract (`snapshot`, beside the other codecs) and
        inserts it in operation order rather than reply-arrival order, so a
        cascade still reads cause-first when the replies come back backwards.
        `dismiss` split into `retry` and `discard`, both acting only on the
        exact record they are handed; `upsert` and `remove` now clear the
        rejection an id had — that last one was new behaviour, not preserved
        behaviour, whatever the settlement said. Harness gained
        `Rules.reversed` (controlled replies held and answered backwards) and
        the steps for retry, discard, `the remote stops rejecting` and `the
        remote replies out of order`. Rules 10, 11, 13 and 14 each
        mutation-checked; decisions along the way under **Opus autonomous
        decisions**.
- [x] **Before 3a · Close the 2d proof gaps. 56/56.** Three scenarios, one
      per gap, each mutation-checked and each failing only its own:
  - *a reply arriving after a transient is ignored* — `retry` closes the
      push. The existing controls already state it: `the remote rejects
      "cat.es"` + `the remote is transient from "dog.es"` + `the remote
      replies out of order` puts the terminal `retry()` ahead of a
      per-operation `reject`. Without `settled := true`, that late reject
      answers a write the next push now owns — 1 pending, 1 rejected instead
      of 2 pending, 0 rejected.
  - *a rejection from an inbound remove keeps its place in the order* — both
      `receiveRemoved` sites at once. Three writes queued offline, the
      second (`Created`) and third (`Updated`) taken out by the
      subscription, then the first refused by the remote: the list still
      reads in outbox order. `~seq=0.0` at either site reorders it.
  - *a retried rejection is not the row it puts back in play* — retry is
      handed the record, retries it offline, and a delivery then merges into
      the row now in play. Without `upsert(snapshot(edited))` the record the
      app still holds reads `CAT`. The copy is proven; it stays.
  - The `.resi` now states the JSON round trip on `make`, beside the
      plain-object rule, and says it holds with or without a `local`
      adaptor. `rejection` and `retry` name the copy that rests on it.
- [x] **3 · The split, behaviour-neutral. 57/57.** No shipped scenario
      changed, and none needed editing. The one addition is rule 17's, at 3d,
      which states what the new construction allows.
  - [x] 3a `Schema.t` resolved once, threaded through. `{id, matches, key,
        sort, now}`, resolved from `config` in one place and read by both
        halves from then on. Neither half defaults anything itself.
  - [x] 3b store-side touches of engine rows routed through
        `item`/`changed`/`removed`/`place` — still one file. `join` split in
        two: the engine walks its entries and `idsByKey`, the store walks its
        registry, both with `matches` from the schema. `place` keeps a row
        whether or not a query lists it (an optimistic write stands on its
        own); `changed` is remote truth and keeps one only while some query
        matches. The store's `listed` walk folded into its half of the join.
  - [x] 3c engine's find path routed through `{online, find, forget}` — still
        one file. One find, both tiers: the engine no longer knows there are
        two, so it asks on every refresh and the store answers from local
        storage first. `loaded` lost `reconcile`, `applyPending`, the local
        push and `recordSeen` — the store does all four before it hands the
        values over. `held` (find → forget) replaces the store's two reads of
        `entries`. The online watch and `tick` each split in half.
  - [x] 3d files split: `TiliaQuerySchema.res`, `TiliaQueryEngine.res`,
        `TiliaQueryStore.res`, `TiliaQuery.res` as the assembly.
        `source.forget` on eviction only. Rule 17 landed with a `SyncStore`
        double in the harness: it places its rows into the engine inside its
        own constructor and answers finds by reading them back through
        `binding.item`, so a binding that arrived afterwards would leave it
        with nothing to place and nothing to find. Mutation-checked — drop
        the constructor `place` and only that scenario fails.
- [ ] **4 · The new surface.**
  - [x] 4a **the seam is public, and both constructors are written. 60/60.**
        `make` takes `store:` and returns `(t, 'store)`; `t` is
        `{one, array, tick, dispose, _canopy}` and everything a store offers
        comes back beside it — `Store.t` for the one shipped here, `unit` for
        one that offers nothing. `Store.custom({remote, local?, merge?,
        expiry?})` is that store, described by its channels. `expiry` split
        in two with nothing left over: `{refresh, memory}` on the query,
        `{local}` on the store. The suite moved to the new surface unchanged
        — the same 57 scenarios, the write steps now going through the store
        handle.
        `Store.make({find, upsert, remove, ...})` landed after 4b, as 5a
        settled it: `answer` is `{fresh, fail}`, the outcomes are
        `Outcome.t`/`Removal.t` in the channel's own words, and the batch is
        issued one operation at a time so it can stop at the first
        `Transient` with nothing further sent. `Store.online()` is one signal
        per process. Scenario: *an outcome store issues one write at a time*
        — three writes take three round trips, where a channel store settles
        them in one. Mutation-checked by issuing the batch at once.
  - [x] 4b **`Kv.t`, memory keyspace as default, `persist`. 59/59.** The
        local adaptor is gone: rows, query records and the outbox are all
        entries under a tag in one string keyspace, `{get, keys, set}`. `get`
        takes `~keys` so a record's ids are one read; `keys` is the sweep,
        and with IndexedDB it is `primaryKeys()`. `persist` absent means an
        in-memory keyspace — the same code path, so every `switch local` in
        the store went with it. Rule 16.
  - [x] 4c **registry lookup, scan fallback, `lookup?`. 59/59.** A query with
        a record is answered from the ids it recorded, and claims `local`; a
        query without one is scanned through `matches` and claims `partial`,
        because a scan cannot know about rows it has never seen. `lookup` is
        the way out for a keyspace with an index — it may certify, and only
        then claim `local`. Rules 12 and 15, both mutation-checked, and rule
        16 with them. The shipped *a partial result is shown* became rule
        12's scenario: `Dexme.partial` was a stand-in for exactly this, and
        the store can now produce `Partial` itself.
  - [ ] 4d `@tilia/query/indexeddb` subpath: `exports`, esbuild, clean-package
- [ ] **5 · Proof and product.**
  - [x] 5a `claims-app-ts` adaptor on paper, before `Store.config` is
        locked. Written up in `TILIA-QUERY-SPLIT.md` under **`Store.make`,
        and what `claims-app-ts` says about it**: the config, the two outcome
        types in the channel's own words, one-at-a-time issue so the batch
        can stop at the first `Transient`, and the app's ~90-line `push`
        reduced to a translation table. It does not absorb the live half —
        that stays on `Store.custom` by decision — and `claims-app-ts`
        happens to have both because `live` is a test flag.
  - [ ] 5b guide and API reference
  - [ ] 5c `claims-app-ts` migrated, after the refactor ships

### Opus Autonomous Decisions

Taken while landing phase 3 alone. Each is cheap to undo.

**The registry mirror is a cache of the keyspace, not a snapshot of it.** A
find that has no record in memory reads the one the keyspace may hold before
falling back to a scan. Loading them all at boot was the first try and it is
wrong: a record written after boot — by an earlier session in the tests, by
another window in life — would never be seen, and a store holding the whole
answer would keep calling it partial.

**Opening a deck now ends when storage has answered.** The local tier reads
its keyspace twice (the record, then the rows it lists), which outruns the
harness's assumption that one microtask is enough. The step drains instead,
which is what its own comment always claimed — and no real keyspace answers
inside a microtask anyway.

**The row layout is documented, not hidden.** `Store.rowTag`, one entry per
row keyed by id, holding the value as JSON. `lookup` is written by whoever
writes the keyspace, because only they can index what they store; hiding the
layout would leave `lookup` unimplementable by the one person who needs it.

**`source` carries `tick` and `dispose`.** The settlement lists the seam as
`{online, find, forget}` and says to dispose the engine first and the store
second — but with `'store` opaque, nothing above the seam can call the
store's half, and leaving it to the application means two calls in an order
it has to get right. Both cross where `find` does, and the engine keeps the
order: its own half first, then the store's. The application still calls one
`tick` and one `dispose`.

**A fourth file, `TiliaQuerySchema.res`.** The plan named three. The read
model, the channel vocabulary and the schema belong to neither half, and the
low-level `Dict`/`Arr` bindings belong to neither either; leaving them in the
engine would have made the store depend on the engine for the word `claim`.
The name is the design's own (`Schema.t` is resolved once by `Query.make`).
Dependencies are a line: Schema → Engine → Store → Query.

**The public types are re-exported with their equalities, and the three new
modules are public.** A `.resi` that declares `type loadable<'a> = ...` afresh
makes it nominally distinct from the half that defines it, so nothing built
from `TiliaQueryEngine.t` can be handed to a step expecting `TiliaQuery.t` —
which is exactly what rule 17's harness does. Each public type now reads
`= TiliaQuerySchema.claim = | ...`, and `Channel` is a module alias, so its
documentation moved into `TiliaQuerySchema.res` where it is now defined.
There is no ReScript consumer of this package outside it, so widening
`public` costs nothing today; 4a makes `Store` and `Query` public vocabulary
anyway.

**The registry is dated by the find, not by the heartbeat.** `tick` used to
re-date an observed query's record from inside the engine's loop
(`TiliaQuery.res:1042`); after the split the engine cannot reach the
registry. So `find` dates the record it is asked for, and `store.tick`
re-dates every *held* record once per refresh window — which also covers a
live query, found once, whose record would otherwise age out while it is on
screen. Two bounded differences, neither with a scenario: a query in memory
but no longer observed now keeps its record current for up to the memory
window (5 minutes) longer than the canopy-gated version did, and both are
measured against a 30-day expiry.

**`recordSeen` obeys the same no-weakening rule as the result.** The store
answers finds from local storage on every refresh now, so a local answer
lands after a fresh one and would re-record the ids storage still holds —
including a row the remote had dropped. *A card deleted on the remote is
swept from local at the next purge* caught it. The store tracks the strongest
claim recorded per held query and refuses a weaker one, cleared by `forget`:
the same lattice, the same words, one dict.

**The `weaker` guard moved from `loaded` into the find's callbacks.** It used
to run inside `loaded`, after the callback had already stamped `entry.state`.
With local answers arriving on refreshes that would demote the state of an
entry whose result was refused, so the check now gates both together.

**The engine still stamps `fetchedAt` only when online.** It no longer knows
whether the store asked a remote at all, but it does know whether one could
have been reached, and that is what the refresh slot is for. Keeping the
condition kept every refresh-timing scenario unchanged.

**Rule 17's double answers finds through `binding.item`.** Placing rows in the
constructor and answering from a private array would have exercised the
binding without depending on it. Answering out of the engine is also the
shape the design has in mind for a store that materializes its own rows —
one live object per id, handed across — so the double is a small `@lapa/db`,
not a contrivance.

### Earlier autonomous decisions

Taken while landing 2d alone. Each is cheap to undo.

**The seq lives in a private dict keyed by id, not on the rejection.** The
settlement asked for it as private metadata on the record, but `rejection<'a>`
is a public variant in the `.resi`: a hidden payload field means a wrapper type
or an external. `addRejection` already keys by id and there is at most one
rejection per id, so a `dict<float>` beside `status` is exact and the public
type is untouched. `retry`, `discard` and a write on the id all delete from it.

**A replacement keeps the place — and the seq — its id already holds.** So
array order and seq order stay the same statement. With rule 11 clearing on
write, a second rejection for an id nothing has written to since is nearly
unreachable anyway, and keeping the first position is what the code did before.

**The copy is not ordered against `revert` and `place`.** The settlement asked
for `addRejection` to run before `base` is restored or remote truth installed.
Taking the copy inside `addRejection` makes that moot — neither `place` nor
`revert` mutates the objects it moves — so the call sites stayed where they
were. One less rule to hold.

**`retry`'s second copy is kept, and now proven.** It protects a real
boundary — a rejection already handed to the application must not become the
live row when retried — and *a retried rejection is not the row it puts back
in play* fails without it. The retry has to stay unconfirmed for the alias to
be visible: once the server answers, `place` installs its own row and the
window closes. So the scenario retries offline and lets a delivery merge into
the pending edit.

**Rule 14's scenario stands as the batch wrote it; my review of it was
wrong.** I had claimed it could not fail without the copy, on the reading that
a delivered change replaces the row in `itemById`. It does not: `itemById` is
a tilia dict, so `receiveChanged` updates the observed row *in place* and
`base` reads `4` without the copy. Verified by mutation. The extra step I had
added to force the failure (`the app edits {string} seen to {string}`) was
redundant and is gone with its scenario line.

**The four new scenarios state the standing rule before the write.** The batch
has `I upsert` and then `the remote rejects "cat.es"`, but the push leaves the
moment the write is queued, so the rule was never in force and nothing was
refused. Reordered — the same behaviour, declared in time.

**The shipped `... and can be dismissed` scenario is now `... and can be
discarded`**, with its step swapped. `dismiss` left the api, so one shipped
scenario had to move; nothing else about it changed.

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

**`settled` closes a push after `retry` or `fail`.** After `fail`, every
unanswered operation has left the outbox and `waiting` rejects a late reply
on its own. After `retry`, however, unanswered operations remain in the
outbox; without `settled`, a late per-operation callback can still answer
them. *A reply arriving after a transient is ignored* holds that half — the
`fail` half is still a cheap guard against a channel that answers twice, and
still has no scenario.

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
replay, `purgeLocal`, `retry`, `discard`, local expiry.

**Straddlers — the actual work of phase 3.** All seven landed; kept as the
record of the analysis, and of where each one ended up.

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
  This is where the no-weakening decision above applies.
- `tick` (`:1029`) does A's refresh, demote and evict, and B's purge and
  push. Splits into `engine.tick()` then `store.tick()`, in that order, which
  is the order the current code already runs them in.
- The online watch (`:926`) refetches (A) and pushes (B). Each half watches
  `online` for its own reason.

## Standing

- **`vitest-bdd` has no tag support.** The string `tag` appears nowhere in the
  package, so a phase cannot land its scenarios as skipped: each one trickles
  in with the code that makes it pass, which is how 2d went.
- **`receiveRemoved`'s seq is covered.** *A rejection from an inbound remove
  keeps its place in the order* orders both of its rejection sites against a
  remote refusal; `~seq=0.0` at either one reorders the list.
- **`claims-app-ts`'s suite has been red since 2a**: 21 failed, 5 passed,
  identical before and after the split (checked against `c6d6a7b` in a
  worktree). Its adaptor still speaks the pre-phase-2 channel — `channel.set`
  for a local answer (`adapters.ts:149`, now `partial`/`local`) and for a
  remote one (`:86`, now `fresh`) — so nothing it does reaches the engine.
  Expected: 5c migrates it. Recorded because a red suite that was always red
  says nothing, and the next person to run it should not have to find that
  out. `tests/app1` is also red, on a missing steps file, unrelated.
- **`claims-app-ts` loses an edit on every conflict.**
  `claims-app-ts/src/app/adapters.ts:109` maps the server's `conflict`
  outcome onto `channel.set`, which was right while `set` still called
  `reconcile`. Since 2c that confirms the op away and places remote truth:
  no merge, no rejection, the local edit is gone. One line —
  `channel.conflict(outcome.claim)` — and the app's own three-way merge is
  reached again. Belongs to 5c, but it is data loss against the shipped app,
  not a migration chore.
- **The api reference and guide still say `dismiss`.** Five pages plus guide
  07; carried in `query/TODO.md`, for the doc rewrite once 4a has settled the
  surface. Not done here: 2d is behaviour, and the `.resi` is rewritten again
  at 4a.
- `one` now has its first scenario and step under rule 4, covering `NoMatch`
  and claim ageing for a complete empty query. Fuller coverage is deferred:
  selecting a row from a narrowed query and `one` over an empty `Partial` are
  pre-existing gaps. `one(query)` selects the first result of a query — it is
  not a lookup by id (`TiliaQuery.res:347`), which the first draft of the batch
  got wrong.
- The overlay item in `TODO.md` was stale and is closed: rejections are status
  records, not optimistic overlays — `applyPending` folds the outbox alone, a
  rejected op has already reverted, and overlaying one would show refused work
  again. The ordering that did matter was `status.rejected` itself, which rule
  13 now fixes. The restart-with-rejection scenario the `.resi` promises stays
  deferred as a pre-existing gap.
- `TODO.md` also wants the query-language constraint stated in the `.resi`:
  queries are pure predicates over one row, no limits, no pagination, no
  aggregates. It belongs to 4a, when the `.resi` is rewritten anyway.
- **`query/src/croquis/TiliaQuerySplit.res` does not exist** — only
  `.gitkeep` was ever committed. `TILIA-QUERY-SPLIT.md` was the whole spec for
  phase 3, and it was enough. The line about it at the top of this file is
  wrong.
- **`src/index.d.ts` is hand-written and stale since 2a.** `esbuild.js`
  copies it to `dist/index.d.ts`; nothing generates it. It still describes
  `notFound`, `notLocal`, `fresh: boolean` and `dismiss`, and now also
  predates `store:` and the tuple return. It is the contract `claims-app-ts`
  compiles against, so it is part of 5c, not of the doc rewrite — and worth
  doing once, after 4d, rather than at every step.
