// Everything both halves speak: the read model, the channel vocabulary, and
// the schema itself. Neither half owns these words, so neither half defines
// them — a store and an engine that disagreed on `key` or `claim` would keep
// two truths about one query.

// === Read model

type claim =
  | @as("partial") Partial
  | @as("local") Local
  | @as("fresh") Fresh

@tag("reason")
type reason =
  | @as("failed") Failed({message: string})
  | @as("offline") Offline
  | @as("noMatch") NoMatch({claim: claim})

@tag("state")
type loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({claim: claim, data: 'a})
  | @as("noData") NoData({reason: reason})

module Channel = {
  /**
   * Read channel handed to `remote.fetch`.
   *
   * `fresh` publishes a complete result set, replacing the previous one.
   * `live` does the same and declares that the adaptor keeps the result
   * fresh, so periodic refresh is skipped. Both claim `Fresh`: `live` adds
   * maintenance, not strength.
   *
   * `fail` publishes a failed result without closing the fetch, allowing a
   * live source to recover. `end` closes the fetch and returns a live query
   * to periodic refresh.
   *
   * `finally` registers the fetch's teardown (e.g. unsubscribe a socket).
   * The last registered teardown runs once when the fetch closes. Callbacks
   * on a closed fetch are ignored.
   */
  type read<'a> = {
    fresh: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }

  /**
   * Local fetch channel, handed to `local.fetch`.
   *
   * `local` publishes a complete result set: everything the query matches,
   * as far as storage knows. `partial` publishes rows it holds without
   * claiming they are all of them — `partial([])` is how a store says it
   * holds nothing.
   */
  type local<'a> = {
    partial: array<'a> => unit,
    local: array<'a> => unit,
  }

  /**
   * Everything a store may answer one find with: the two weaker claims local
   * storage can make, the two a synchronized source can, and the lifecycle
   * of the source behind them. `read` is this minus `partial` and `local` —
   * a remote is never entitled to either.
   *
   * The engine asks once per find and does not know how many tiers answered
   * it. Only `tick` lowers a claim, so a weaker answer arriving after a
   * stronger one is ignored rather than shown.
   */
  type find<'a> = {
    partial: array<'a> => unit,
    local: array<'a> => unit,
    fresh: array<'a> => unit,
    live: array<'a> => unit,
    fail: string => unit,
    end: unit => unit,
    finally: (unit => unit) => unit,
  }

  /**
   * Write channel, handed to `remote.push` together with a batch of ops.
   *
   * `set`, `removed`, `conflict` and `reject` answer one operation. `retry`
   * and `fail` apply to every operation in the push that has not been
   * answered. Answering is not settling: `conflict` leaves its operation
   * pending.
   *
   * Confirm each upsert with its authoritative value through `set`, and each
   * remove by id through `removed`.
   *
   * `conflict` hands back the server's row for one operation and keeps it
   * pending, so the local change rebases onto it through `merge` and the
   * heartbeat pushes it again. A rejecting `merge` reverts instead and
   * records the conflict.
   *
   * `reject` refuses one operation: it reverts that write and records it.
   * Order does not imply dependency, so reverting unrelated writes would
   * record rejections that are false.
   *
   * `retry` keeps unanswered ops pending, for a failure that says nothing
   * about the writes themselves. `fail` rejects every operation in the
   * current push that has not yet received an outcome; earlier outcomes
   * remain unchanged, so a server that acknowledged an operation and then
   * rolled it back has to say so through `receive`.
   *
   * `set(value)` and `conflict(value)` find their operation by `id(value)`:
   * a server that assigns its own id leaves that operation pending forever.
   */
  type write<'a> = {
    set: 'a => unit,
    removed: string => unit,
    conflict: 'a => unit,
    reject: (string, string) => unit,
    retry: unit => unit,
    fail: string => unit,
  }
}

// Like `Tilia.res`, these bindings keep the compiled output free of
// `@rescript/runtime` imports. The bet: a value or a query is never `null`
// or `undefined`, so a `nullable` read from a dict or an array slot means
// absent, never stored.

module Dict = {
  let make: unit => dict<'a> = %raw(`() => ({})`)
  @get_index external get: (dict<'a>, string) => nullable<'a> = ""
  @set_index external set: (dict<'a>, string, 'a) => unit = ""
  @val external keys: dict<'a> => array<string> = "Object.keys"
  @val external values: dict<'a> => array<'a> = "Object.values"
  @val external entries: dict<'a> => array<(string, 'a)> = "Object.entries"
  external remove: (dict<'a>, string) => bool = "Reflect.deleteProperty"
  let delete = (d, k) => d->remove(k)->ignore
  let forEach = (d, fn) => d->values->Array.forEach(fn)
  let forEachWithKey = (d, fn) => d->entries->Array.forEach(((k, v)) => fn(v, k))
}

module Arr = {
  @get_index external at: (array<'a>, int) => nullable<'a> = ""
  @send external reduce: (array<'a>, ('b, 'a) => 'b, 'b) => 'b = "reduce"
}

// === Schema

/**
 * What both halves must agree on, resolved once from `config` and passed to
 * each of them. Neither half defaults anything itself: a store and an engine
 * that disagreed on `key` or `id` would keep two truths about one row.
 */
type schema<'query, 'a> = {
  id: 'a => string,
  matches: ('query, 'a) => bool,
  key: 'query => string,
  sort: 'query => array<'a> => array<'a>,
  now: unit => float,
}

/** `Partial < Local < Fresh`: a weaker answer cannot replace a stronger one. */
let rank = claim =>
  switch claim {
  | Partial => 0
  | Local => 1
  | Fresh => 2
  }

/**
 * An empty `Partial` is not a result: it says the store holds nothing, which
 * is not the same as the answer being empty. A remote answer may still be
 * coming, unless there is no network to bring it.
 */
let project = (online, result) =>
  switch result {
  | Loaded({claim: Partial, data}) if data->Array.length === 0 =>
    online ? Loading : NoData({reason: Offline})
  | result => result
  }

let sortedStringify: 'a => string = %raw(`
function sortedStringify(value) {
  return JSON.stringify(value, function(_key, value) {
    if (value && typeof value === "object" && !Array.isArray(value)) {
      const sorted = {};
      for (const key of Object.keys(value).sort()) {
        sorted[key] = value[key];
      }
      return sorted;
    }
    return value;
  });
}`)
