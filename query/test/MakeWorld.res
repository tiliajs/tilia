// Test world for tilia/query: a simulated remote (Supabase-like) and local
// store (Dexie-like), plus the adaptors that expose them as a
// `TiliaQuery.remote` / `TiliaQuery.local`. Doubles as the reference
// example for writing real adaptors.

// ================ Helpers

module Stack = {
  type t = {
    push: (unit => unit) => unit,
    flush: unit => unit,
  }

  let make = (): t => {
    let pending: array<unit => unit> = []
    {
      push: f => pending->Array.push(f),
      flush: () => {
        pending->Array.forEach(f => f())
        pending->Array.splice(~start=0, ~remove=pending->Array.length, ~insert=[])
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

// Simulate the api of a remote like Supabase
// with version based rejection (incoming version must === 0 or actual version
// of record, auto-increments version on write).
module Papabase = {
  type t = {
    select: (card => bool) => promise<array<card>>,
    upsert: card => promise<result<card, string>>,
    remove: string => promise<result<unit, string>>,
    // For testing
    _select: (card => bool) => array<card>,
  }

  let make = (stack: Stack.t): t => {
    let do = stack.push
    let data: dict<card> = Dict.make()
    let upsert = card => {
      let actual = data->Dict.get(card.id)->Option.flatMap(c => c.version)->Option.getOr(0.0)
      let incoming = card.version->Option.getOr(0.0)
      if incoming !== 0.0 && incoming !== actual {
        Promise.make((resolve, _) => do(() => resolve(Error(`version conflict on "${card.id}"`))))
      } else {
        let stored = {...card, version: actual +. 1.0}
        data->Dict.set(card.id, stored)
        Promise.make((resolve, _) => do(() => resolve(Ok(stored))))
      }
    }
    let remove = id => {
      data->Dict.delete(id)
      Promise.make((resolve, _) => do(() => resolve(Ok())))
    }
    let _select = filter => data->Dict.valuesToArray->Array.filter(filter)
    let select = filter => {
      let result = _select(filter)
      Promise.make((resolve, _) => do(() => resolve(result)))
    }
    {
      select,
      upsert,
      remove,
      _select,
    }
  }
}
// Simulate the api of a local storage like Dexie: id-keyed tables with
// inbound keys. `cards` holds the values, `kv` the engine bookkeeping.
module Dexme = {
  type table<'a> = {
    get: string => promise<option<'a>>,
    put: 'a => promise<unit>,
    delete: string => promise<unit>,
    filter: ('a => bool) => promise<array<'a>>,
    // For testing
    _select: ('a => bool) => array<'a>,
  }

  type kvEntry = {key: string, value: string}

  type t = {
    cards: table<card>,
    kv: table<kvEntry>,
  }

  let makeTable = (stack: Stack.t, getKey: 'a => string): table<'a> => {
    let data: dict<'a> = Dict.make()
    let do = stack.push
    let get = key => {
      let result = data->Dict.get(key)
      Promise.make((resolve, _) => do(() => resolve(result)))
    }
    let put = row => {
      data->Dict.set(getKey(row), row)
      Promise.make((resolve, _) => do(resolve))
    }
    let delete = key => {
      data->Dict.delete(key)
      Promise.make((resolve, _) => do(resolve))
    }
    let _select = f => data->Dict.valuesToArray->Array.filter(f)
    let filter = f => {
      let result = _select(f)
      Promise.make((resolve, _) => do(() => resolve(result)))
    }
    {
      get,
      put,
      delete,
      filter,
      _select,
    }
  }

  let make = (stack: Stack.t): t => {
    cards: makeTable(stack, card => card.id),
    kv: makeTable(stack, entry => entry.key),
  }
}

// Wire a Supabase-like api as a tilia/query remote. The online signal is
// owned by the app (or the test): the adaptor only hands it over.
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
