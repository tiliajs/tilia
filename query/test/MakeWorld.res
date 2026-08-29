// Test world for tilia/query: a simulated remote (Supabase-like) and local
// store (Dexie-like), plus the adaptors that expose them as a
// `TiliaQuery.remote` / `TiliaQuery.local`. Doubles as the reference
// example for writing real adaptors: `PapabaseAdaptor` and `DexmeAdaptor`
// are exactly the code an app would write against the real services.
//
// Simulation model:
// - Dexme answers with plain promises: local storage is fast, so results
//   land "immediately" (on the microtask drain between two test steps).
// - Papabase sits behind `Network`: requests reach the server instantly,
//   responses only travel back when the `time passes` step flushes the
//   network. This keeps a remote fetch observably in flight across steps
//   (`Then I should see loading`) and enforces the ordering the engine
//   assumes: local answers before remote.
// - Functions prefixed with `_` (like `_select`) are test-only inspection
//   helpers; a real remote or local store has no equivalent and no adaptor
//   uses them.

// ================ Helpers

/**
 * The simulated network. Responses are held in a queue and delivered, in
 * order, only when `flush` runs — however often the pending promises are
 * awaited in between. The `time passes` step owns the flush.
 */
module Network = {
  type t = {
    respond: (unit => unit) => unit,
    flush: unit => unit,
  }

  let make = (): t => {
    let queue: array<unit => unit> = []
    {
      respond: f => queue->Array.push(f),
      flush: () => {
        queue->Array.forEach(f => f())
        queue->Array.splice(~start=0, ~remove=queue->Array.length, ~insert=[])
      },
    }
  }
}

// ================ Domain

// The domain: language training cards, queried by deck. Table cells arrive
// as strings from vitest-bdd's `toRecords`, so `seen` stays a string end to
// end. `version` is owned by the remote (Papabase); values written by the
// app never carry one.
type card = {
  id: string,
  mutable deck: string,
  mutable english: string,
  mutable translation: string,
  mutable seen: string,
  version?: float,
}

type query = {
  deck: string,
  seen: option<string>,
}

let id = card => card.id
let clone = card => {...card, id: card.id}
let matches = (query: query, card: card) =>
  card.deck === query.deck && query.seen->Option.mapOr(true, seen => card.seen === seen)

// Simulate the api of a remote like Supabase, with version based rejection
// (incoming version must be 0 or match the actual version of the record;
// the version auto-increments on write).
module Papabase = {
  type t = {
    select: (card => bool) => promise<result<array<card>, string>>,
    upsert: card => promise<result<card, string>>,
    remove: string => promise<result<unit, string>>,
    /** Test-only: synchronous look inside the server's table. */
    _select: (card => bool) => array<card>,
    /** Test-only: write a row with its version, bypassing the version check. */
    _put: card => unit,
    /** Test-only: while set, `select` answers this error. */
    _failing: option<string> => unit,
    /** Test-only: the queue controlled replies share with the real ones. */
    _network: Network.t,
  }

  // The server processes a request the moment it is made; only the response
  // travels slowly, delivered by the next network flush.
  let make = (network: Network.t): t => {
    let data: dict<card> = Dict.make()
    let respond = value => Promise.make((resolve, _) => network.respond(() => resolve(value)))
    let upsert = card => {
      let actual = data->Dict.get(card.id)->Option.flatMap(c => c.version)->Option.getOr(0.0)
      let incoming = card.version->Option.getOr(0.0)
      if incoming !== 0.0 && incoming !== actual {
        respond(Error(`version conflict on "${card.id}"`))
      } else {
        let stored = {...card, version: actual +. 1.0}
        data->Dict.set(card.id, stored)
        respond(Ok(stored))
      }
    }
    let _put = card => data->Dict.set(card.id, card)
    let remove = id => {
      data->Dict.delete(id)
      respond(Ok())
    }
    let failing = ref(None)
    let _select = filter => data->Dict.valuesToArray->Array.filter(filter)->Array.map(clone)
    let select = filter =>
      switch failing.contents {
      | Some(message) => respond(Error(message))
      | None => respond(Ok(_select(filter)))
      }
    {
      select,
      upsert,
      remove,
      _select,
      _put,
      _failing: message => failing := message,
      _network: network,
    }
  }
}

// Simulate the api of a local storage like Dexie: promise-based, id-keyed
// tables. `cards` holds the values, `kv` the engine bookkeeping.
module Dexme = {
  type table<'a> = {
    get: string => promise<option<'a>>,
    put: 'a => promise<unit>,
    delete: string => promise<unit>,
    filter: ('a => bool) => promise<array<'a>>,
    /** Test-only: synchronous look inside the table. */
    _select: ('a => bool) => array<'a>,
  }

  type kvEntry = {key: string, value: string}

  type t = {
    cards: table<card>,
    kv: table<kvEntry>,
    /**
     * Test control. While set, a read answers `channel.partial`: the rows are
     * there but storage will not claim they are the whole answer. A store
     * without a query index can say no more than that.
     */
    mutable partial: bool,
  }

  let makeTable = (getKey: 'a => string): table<'a> => {
    let data: dict<'a> = Dict.make()
    let get = async key => data->Dict.get(key)
    let put = async row => data->Dict.set(getKey(row), row)
    let delete = async key => data->Dict.delete(key)
    let _select = f => data->Dict.valuesToArray->Array.filter(f)
    let filter = async f => _select(f)
    {
      get,
      put,
      delete,
      filter,
      _select,
    }
  }

  let make = (): t => {
    cards: makeTable(card => card.id),
    kv: makeTable(entry => entry.key),
    partial: false,
  }
}

// ================ Adaptors — the reference code for a real app

// Wire a Supabase-like api as a tilia/query remote. The online signal is
// owned by the app (or the test): the adaptor only hands it over. Fetches
// are one-shot promises — no `channel.live`, nothing to register with
// `channel.finally` — so the engine refreshes periodically.
module PapabaseAdaptor = {
  let make = (papabase: Papabase.t, online_: Tilia.signal<bool>): TiliaQuery.remote<
    query,
    card,
  > => {
    online: online_,
    fetch: (query, channel) => {
      papabase.select(card => matches(query, card))
      ->Promise.thenResolve(result =>
        switch result {
        | Ok(cards) => channel.fresh(cards)
        | Error(error) => channel.fail(error)
        }
      )
      ->ignore
    },
    push: (ops, channel) => {
      ops->Array.forEach(op =>
        switch op {
        | TiliaQuery.Upsert({value}) =>
          papabase.upsert(value)
          ->Promise.thenResolve(result =>
            switch result {
            | Ok(data) => channel.set(data)
            | Error(error) => channel.fail(error)
            }
          )
          ->ignore
        | TiliaQuery.Remove({id}) =>
          papabase.remove(id)
          ->Promise.thenResolve(result =>
            switch result {
            | Ok() => channel.removed(id)
            | Error(error) => channel.fail(error)
            }
          )
          ->ignore
        }
      )
    },
  }
}

// Wire a Dexie-like api as a tilia/query local. Bookkeeping entries land in
// the kv table under a "tag/key" composite key.
module DexmeAdaptor = {
  let kvKey = (~tag, ~key) => `${tag}/${key}`

  let make = (dexme: Dexme.t): TiliaQuery.local<query, card> => {
    fetch: (query, channel) => {
      dexme.cards.filter(card => matches(query, card))
      ->Promise.thenResolve(result =>
        if dexme.partial || result->Array.length === 0 {
          // Nothing held is never a complete answer: it is the store saying
          // it holds nothing, which the engine reads as loading or offline.
          channel.partial(result)
        } else {
          channel.local(result)
        }
      )
      ->ignore
    },
    push: ops =>
      ops->Array.forEach(op =>
        switch op {
        | TiliaQuery.Upsert({value}) => dexme.cards.put(value)->ignore
        | TiliaQuery.Remove({id}) => dexme.cards.delete(id)->ignore
        }
      ),
    set: (~tag, ~key, value) =>
      switch value {
      | Some(value) => dexme.kv.put({key: kvKey(~tag, ~key), value})->ignore
      | None => dexme.kv.delete(kvKey(~tag, ~key))->ignore
      },
    get: (~tag, ~key=?, ~set) =>
      switch key {
      | Some(key) =>
        dexme.kv.get(kvKey(~tag, ~key))
        ->Promise.thenResolve(result => set(result->Option.mapOr([], e => [e.value])))
        ->ignore
      | None =>
        dexme.kv.filter(e => e.key->String.startsWith(`${tag}/`))
        ->Promise.thenResolve(result => set(result->Array.map(e => e.value)))
        ->ignore
      },
    // With real Dexie this is `table.toCollection().primaryKeys()`.
    ids: (~set) =>
      dexme.cards.filter(_ => true)
      ->Promise.thenResolve(cards => set(cards->Array.map(card => card.id)))
      ->ignore,
  }
}

/**
 * Per-operation server outcomes, so a scenario can say what happens to one
 * write without saying it about the whole push. Controlled replies go through
 * the network like the real ones, so they land in queue order — a `fail` after
 * an accepted write really does arrive after it.
 */
module Rules = {
  type t = {
    rejects: dict<string>,
    conflicts: dict<card>,
    mutable transientFrom: option<string>,
    mutable failAfter: option<(string, string)>,
  }

  let make = (): t => {
    rejects: Dict.make(),
    conflicts: Dict.make(),
    transientFrom: None,
    failAfter: None,
  }

  let opId = (op: TiliaQuery.op<card>) =>
    switch op {
    | TiliaQuery.Upsert({value}) => value.id
    | TiliaQuery.Remove({id}) => id
    }

  let wrap = (
    rules: t,
    network: Network.t,
    remote: TiliaQuery.remote<query, card>,
  ): TiliaQuery.remote<query, card> => {
    let later = f =>
      Promise.make((resolve, _) => network.respond(() => resolve()))
      ->Promise.thenResolve(f)
      ->ignore
    {
      ...remote,
      push: (ops, channel) => {
        // Once the push has ended, the remaining ops are not sent at all:
        // `retry` or `fail` speaks for them.
        let ended = ref(false)
        ops->Array.forEach(op => {
          if !ended.contents {
            let oid = opId(op)
            switch rules.transientFrom {
            | Some(from) if from === oid =>
              ended := true
              later(() => channel.retry())
            | _ =>
              switch rules.rejects->Dict.get(oid) {
              | Some(message) => later(() => channel.reject(oid, message))
              | None =>
                switch rules.conflicts->Dict.get(oid) {
                | Some(row) =>
                  // One-shot: the write was out of date, and now it is not.
                  // A standing conflict would spin the outbox forever.
                  rules.conflicts->Dict.delete(oid)
                  later(() => channel.conflict(row))
                | None => remote.push([op], channel)
                }
              }
            }
            switch rules.failAfter {
            | Some((after, message)) if after === oid =>
              ended := true
              later(() => channel.fail(message))
            | _ => ()
            }
          }
        })
      },
    }
  }
}

// ================ Live test controls

/**
 * Test-only instrumentation wrapped around the remote adaptor. It counts
 * fetches, keeps channel handles so scenarios can play a subscription
 * source (deliver, end) and attempt late replies, and counts `finally`
 * teardowns. While `enabled`, a fetch answers through `channel.live` — the
 * scenario then owns freshness, like a real subscription adaptor would.
 */
module Live = {
  type t = {
    network: Network.t,
    mutable enabled: bool,
    /** When set, a fetch's source is already dead: it ends synchronously,
     before registering its teardown. */
    mutable endsInFetch: bool,
    /** Channel of the latest fetch — kept after it ends or is evicted. */
    mutable channel: option<TiliaQuery.Channel.read<card>>,
    /** Channel of the fetch the latest one replaced. */
    mutable superseded: option<TiliaQuery.Channel.read<card>>,
    /** How many times a registered `finally` teardown ran. */
    mutable cleanups: int,
    /** How many times the engine called `remote.fetch`. */
    mutable fetches: int,
  }

  let make = (network: Network.t): t => {
    network,
    enabled: false,
    endsInFetch: false,
    channel: None,
    superseded: None,
    cleanups: 0,
    fetches: 0,
  }

  let wrap = (
    live: t,
    papabase: Papabase.t,
    remote: TiliaQuery.remote<query, card>,
  ): TiliaQuery.remote<query, card> => {
    ...remote,
    fetch: (query, channel) => {
      live.fetches = live.fetches + 1
      live.superseded = live.channel
      live.channel = Some(channel)
      if live.endsInFetch {
        // The source is already dead: it ends before registering its
        // teardown — the engine runs the late registration immediately.
        channel.end()
        channel.finally(() => live.cleanups = live.cleanups + 1)
      } else if live.enabled {
        channel.finally(() => live.cleanups = live.cleanups + 1)
        // The initial result travels back like any response; later
        // deliveries are driven by the scenario through `live.channel`.
        live.network.respond(() => channel.live(papabase._select(card => matches(query, card))))
      } else {
        remote.fetch(query, channel)
      }
    },
  }
}

module Merge = {
  type call = {
    change: TiliaQuery.change<card>,
    remote: card,
  }

  type t = {
    mutable accepted: bool,
    calls: array<call>,
  }

  let make = (): t => {
    accepted: true,
    calls: [],
  }

  let run = (merge: t, ~change, ~remote) => {
    let local = switch change {
    | TiliaQuery.Clean({value: card})
    | TiliaQuery.Created({edited: card})
    | TiliaQuery.Updated({edited: card})
    | TiliaQuery.Removed({base: card}) => card
    }
    let snapshot = switch change {
    | TiliaQuery.Clean({value}) => TiliaQuery.Clean({value: clone(value)})
    | TiliaQuery.Created({edited}) => TiliaQuery.Created({edited: clone(edited)})
    | TiliaQuery.Updated({base, edited}) =>
      TiliaQuery.Updated({base: clone(base), edited: clone(edited)})
    | TiliaQuery.Removed({base}) => TiliaQuery.Removed({base: clone(base)})
    }
    merge.calls->Array.push({change: snapshot, remote: clone(remote)})->ignore
    if merge.accepted {
      local.deck = remote.deck
      local.english = remote.english
      local.translation = remote.translation
      switch change {
      | TiliaQuery.Clean(_) => local.seen = remote.seen
      | TiliaQuery.Created(_)
      | TiliaQuery.Updated(_)
      | TiliaQuery.Removed(_) => ()
      }
    }
    merge.accepted
  }
}

let sortBySeen = (a: card, b: card) =>
  if a.seen < b.seen {
    -1.0
  } else if a.seen > b.seen {
    1.0
  } else if a.english < b.english {
    -1.0
  } else if a.english > b.english {
    1.0
  } else {
    0.0
  }

/**
 * Wraps a remote so a scenario can make writes fail transiently. While
 * `unavailable`, `push` answers `channel.retry()`: the batch stays pending and
 * the engine owns when to try again. `attempts` counts the calls, so a
 * scenario can assert that a retry actually happened rather than inferring it
 * from the outcome.
 */
module Push = {
  type t = {
    mutable unavailable: bool,
    mutable attempts: int,
  }

  let make = (): t => {unavailable: false, attempts: 0}

  let wrap = (push: t, remote: TiliaQuery.remote<query, card>): TiliaQuery.remote<query, card> => {
    ...remote,
    push: (ops, channel) => {
      push.attempts = push.attempts + 1
      if push.unavailable {
        channel.retry()
      } else {
        remote.push(ops, channel)
      }
    },
  }
}

// Convention: signals end with an underscore (now_, online_).
// The engine's default expiry applies (refresh 30s, memory 5min, local
// 30 days): scenarios advance the clock with real durations.
let make = (
  ~dexme: option<Dexme.t>=?,
  ~live: option<Live.t>=?,
  ~push: option<Push.t>=?,
  ~rules: option<Rules.t>=?,
  ~merge: Merge.t=Merge.make(),
  ~onError: option<(~query: query, ~message: string) => unit>=?,
  papabase: Papabase.t,
  now: unit => float,
  online_: Tilia.signal<bool>,
): TiliaQuery.t<query, card> => {
  let remote = PapabaseAdaptor.make(papabase, online_)
  let remote = switch live {
  | Some(live) => Live.wrap(live, papabase, remote)
  | None => remote
  }
  let remote = switch rules {
  | Some(rules) => Rules.wrap(rules, papabase._network, remote)
  | None => remote
  }
  let remote = switch push {
  | Some(push) => Push.wrap(push, remote)
  | None => remote
  }
  let sort = _query => array => array->Array.toSorted(sortBySeen)
  let mergeValues = (~change, ~remote) => Merge.run(merge, ~change, ~remote)
  switch dexme {
  | Some(dexme) =>
    let local = DexmeAdaptor.make(dexme)
    TiliaQuery.make({id, matches, sort, merge: mergeValues, remote, local, now, ?onError})
  | None => TiliaQuery.make({id, matches, sort, merge: mergeValues, remote, now, ?onError})
  }
}
