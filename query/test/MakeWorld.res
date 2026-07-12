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
  deck: string,
  english: string,
  translation: string,
  seen: string,
  version?: float,
}

type query = {deck: string}

let id = card => card.id
let matches = (query: query, card: card) => card.deck === query.deck
let sort = (a: card, b: card) => a.id < b.id ? -1.0 : a.id > b.id ? 1.0 : 0.0

// Simulate the api of a remote like Supabase, with version based rejection
// (incoming version must be 0 or match the actual version of the record;
// the version auto-increments on write).
module Papabase = {
  type t = {
    select: (card => bool) => promise<array<card>>,
    upsert: card => promise<result<card, string>>,
    remove: string => promise<result<unit, string>>,
    /** Test-only: synchronous look inside the server's table. */
    _select: (card => bool) => array<card>,
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
    let _select = filter => data->Dict.valuesToArray->Array.filter(filter)
    let select = filter => respond(_select(filter))
    {
      select,
      upsert,
      remove,
      _select,
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
// are one-shot promises — no `channel.live`, nothing to cancel, so `fetch`
// returns `None` and the engine refreshes periodically.
module PapabaseAdaptor = {
  let make = (papabase: Papabase.t, online_: Tilia.signal<bool>): TiliaQuery.remote<
    card,
    query,
  > => {
    online: online_,
    fetch: (query, channel) => {
      papabase.select(card => matches(query, card))->Promise.thenResolve(channel.set)->ignore
      None
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

  let make = (dexme: Dexme.t): TiliaQuery.local<card, query> => {
    fetch: (query, channel) => {
      dexme.cards.filter(card => matches(query, card))
      ->Promise.thenResolve(result => channel.set(result))
      ->ignore
      None
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
  }
}

let sortByEnglish = (a: card, b: card) =>
  a.english < b.english ? -1.0 : a.english > b.english ? 1.0 : 0.0

// Convention: signals end with an underscore (now_, online_).
// Test expiry defaults are tiny integers so scenarios drive time with
// single-digit `now_` moves: refresh 2, memory 4, local 8.
let make = (
  ~dexme: option<Dexme.t>=?,
  ~expiry: TiliaQuery.expiry={refresh: 2.0, memory: 4.0, local: 8.0},
  papabase: Papabase.t,
  now_: Tilia.signal<float>,
  online_: Tilia.signal<bool>,
): TiliaQuery.t<card, query> => {
  let remote = PapabaseAdaptor.make(papabase, online_)
  let now = () => now_.value
  let sort = array => array->Array.toSorted(sortByEnglish)
  switch dexme {
  | Some(dexme) =>
    let local = DexmeAdaptor.make(dexme)
    TiliaQuery.make(~id, ~matches, ~sort, ~remote, ~local, ~expiry, ~now)
  | None => TiliaQuery.make(~id, ~matches, ~sort, ~remote, ~expiry, ~now)
  }
}
