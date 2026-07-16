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
    /** Test-only: while set, `select` answers this error. */
    _failing: option<string> => unit,
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
      _failing: message => failing := message,
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
        | Ok(cards) => channel.set(cards)
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
      ->Promise.thenResolve(result => {
        if result->Array.length > 0 {
          channel.set(result)
        } else {
          channel.unknown()
        }
      })
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
    | TiliaQuery.Clean(card)
    | TiliaQuery.Created(card)
    | TiliaQuery.Updated(_, card)
    | TiliaQuery.Removed(card) => card
    }
    let snapshot = switch change {
    | TiliaQuery.Clean(card) => TiliaQuery.Clean(clone(card))
    | TiliaQuery.Created(edited) => TiliaQuery.Created(clone(edited))
    | TiliaQuery.Updated(base, edited) => TiliaQuery.Updated(clone(base), clone(edited))
    | TiliaQuery.Removed(base) => TiliaQuery.Removed(clone(base))
    }
    merge.calls->Array.push({change: snapshot, remote: clone(remote)})->ignore
    if merge.accepted {
      local.deck = remote.deck
      local.english = remote.english
      local.translation = remote.translation
      switch change {
      | TiliaQuery.Clean(_) => local.seen = remote.seen
      | TiliaQuery.Created(_)
      | TiliaQuery.Updated(_, _)
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

// Convention: signals end with an underscore (now_, online_).
// The engine's default expiry applies (refresh 30s, memory 5min, local
// 30 days): scenarios advance the clock with real durations.
let make = (
  ~dexme: option<Dexme.t>=?,
  ~live: option<Live.t>=?,
  ~merge: Merge.t=Merge.make(),
  papabase: Papabase.t,
  now: unit => float,
  online_: Tilia.signal<bool>,
): TiliaQuery.t<query, card> => {
  let remote = PapabaseAdaptor.make(papabase, online_)
  let remote = switch live {
  | Some(live) => Live.wrap(live, papabase, remote)
  | None => remote
  }
  let sort = _query => array => array->Array.toSorted(sortBySeen)
  let mergeValues = (~change, ~remote) => Merge.run(merge, ~change, ~remote)
  switch dexme {
  | Some(dexme) =>
    let local = DexmeAdaptor.make(dexme)
    TiliaQuery.make({id, matches, sort, merge: mergeValues, remote, local, now})
  | None => TiliaQuery.make({id, matches, sort, merge: mergeValues, remote, now})
  }
}
