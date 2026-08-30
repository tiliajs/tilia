// The assembly. `Query` resolves the schema and the expiry once, builds the
// engine around the store this package ships, and presents the two halves as
// one object. Everything public is defined by one half or the other and
// re-exported here, so a consumer sees a single module and the halves cannot
// drift apart.

// === PUBLIC TYPES (from .resi file)

type claim = TiliaQuerySchema.claim =
  | @as("partial") Partial
  | @as("local") Local
  | @as("fresh") Fresh

@tag("reason")
type reason = TiliaQuerySchema.reason =
  | @as("failed") Failed({message: string})
  | @as("offline") Offline
  | @as("noMatch") NoMatch({claim: claim})

@tag("state")
type loadable<'a> = TiliaQuerySchema.loadable<'a> =
  | @as("loading") Loading
  | @as("loaded") Loaded({claim: claim, data: 'a})
  | @as("noData") NoData({reason: reason})

@tag("op")
type op<'a> = TiliaQueryStore.op<'a> =
  | @as("upsert") Upsert({value: 'a})
  | @as("remove") Remove({id: string})

@tag("rejection")
type rejection<'a> = TiliaQueryStore.rejection<'a> =
  | @as("createConflict") CreateConflict({edited: 'a})
  | @as("createFailed") CreateFailed({edited: 'a, message: string})
  | @as("updateConflict") UpdateConflict({base: 'a, edited: 'a})
  | @as("updateFailed") UpdateFailed({base: 'a, edited: 'a, message: string})
  | @as("removeConflict") RemoveConflict({base: 'a})
  | @as("removeFailed") RemoveFailed({base: 'a, message: string})

@tag("change")
type change<'a> = TiliaQueryStore.change<'a> =
  | @as("clean") Clean({value: 'a})
  | @as("created") Created({edited: 'a})
  | @as("updated") Updated({base: 'a, edited: 'a})
  | @as("removed") Removed({base: 'a})
module Channel = TiliaQuerySchema.Channel

type expiry = TiliaQueryEngine.expiry = {
  refresh: float,
  memory: float,
}

type schema<'query, 'a> = TiliaQuerySchema.schema<'query, 'a> = {
  id: 'a => string,
  matches: ('query, 'a) => bool,
  key: 'query => string,
  sort: 'query => array<'a> => array<'a>,
  now: unit => float,
}

type binding<'a> = TiliaQueryEngine.binding<'a> = {
  item: string => option<'a>,
  changed: array<'a> => unit,
  removed: array<string> => unit,
  place: 'a => unit,
}

type source<'query, 'a> = TiliaQueryEngine.source<'query, 'a> = {
  online: Tilia.signal<bool>,
  find: ('query, Channel.find<'a>) => unit,
  forget: 'query => unit,
  tick: unit => unit,
  dispose: unit => unit,
}

/**
 * A store, as `Query.make` takes it: not a built store but a factory, given
 * the schema the engine resolved and a binding that already works. The two
 * halves cannot disagree about `id` or `key`, because neither of them
 * decides it.
 */
type store<'query, 'a, 'store> = (schema<'query, 'a>, binding<'a>) => (source<'query, 'a>, 'store)

type status<'a> = TiliaQueryStore.status<'a> = {
  pending: int,
  rejected: array<rejection<'a>>,
}

type remote<'query, 'a> = TiliaQueryStore.remote<'query, 'a> = {
  online: Tilia.signal<bool>,
  fetch: ('query, Channel.read<'a>) => unit,
  push: (array<op<'a>>, Channel.write<'a>) => unit,
}

type config<'query, 'a, 'store> = {
  id: 'a => string,
  matches: ('query, 'a) => bool,
  store: store<'query, 'a, 'store>,
  expiry?: expiry,
  now?: unit => float,
  key?: 'query => string,
  sort?: 'query => array<'a> => array<'a>,
  onError?: (~query: 'query, ~message: string) => unit,
}

type receive<'a> = TiliaQueryStore.receive<'a> = {
  changed: array<'a> => unit,
  removed: array<string> => unit,
}

type canopy = TiliaQueryEngine.canopy = {
  live: array<string>,
  idle: array<string>,
}

type t<'query, 'a> = TiliaQueryEngine.t<'query, 'a> = {
  one: 'query => loadable<'a>,
  array: 'query => loadable<array<'a>>,
  tick: unit => unit,
  dispose: unit => unit,
  _canopy: unit => canopy,
}

/**
 * The store this package ships: a write-through cache with an outbox. It is
 * one value the `store` field can take, not a second entry point.
 */
module Store = {
  type expiry = TiliaQueryStore.expiry = {local: float}

  type t<'a> = TiliaQueryStore.t<'a> = {
    upsert: 'a => unit,
    remove: string => unit,
    receive: receive<'a>,
    status: status<'a>,
    retry: rejection<'a> => unit,
    discard: rejection<'a> => unit,
  }

  module Kv = TiliaQueryStore.Kv

  let memory = TiliaQueryStore.Kv.make

  let rowTag = TiliaQueryStore.rowTag

  type channels<'query, 'a> = {
    remote: remote<'query, 'a>,
    persist?: Kv.t,
    lookup?: ('query, Channel.local<'a>) => unit,
    merge?: (~change: change<'a>, ~remote: 'a) => bool,
    expiry?: expiry,
  }

  let _expiry: expiry = {
    // 30 days
    local: 2_592_000_000.0,
  }

  /**
   * A store described by its channels: an adaptor that answers a find when
   * it can, pushes a batch when asked, and may push facts in at any time.
   */
  module Outcome = TiliaQueryStore.Outcome
  module Removal = TiliaQueryStore.Removal

  type answer<'a> = TiliaQueryStore.answer<'a> = {
    fresh: array<'a> => unit,
    fail: string => unit,
  }

  type config<'query, 'a> = {
    find: ('query, answer<'a>) => unit,
    upsert: ('a, Outcome.t<'a> => unit) => unit,
    remove: (string, Removal.t => unit) => unit,
    online?: Tilia.signal<bool>,
    persist?: Kv.t,
    lookup?: ('query, Channel.local<'a>) => unit,
    merge?: (~change: change<'a>, ~remote: 'a) => bool,
    expiry?: expiry,
  }

  let online = TiliaQueryStore.online

  let custom = ({remote, ?persist, ?lookup, ?merge, ?expiry}: channels<'query, 'a>) =>
    (schema, binding) =>
      TiliaQueryStore.connect(
        {
          schema,
          expiry: switch expiry {
          | Some(expiry) => expiry
          | None => _expiry
          },
          remote,
          persist: switch persist {
          | Some(persist) => persist
          | None => Kv.make()
          },
          ?lookup,
          ?merge,
        },
        binding,
      )

  /**
   * A store described by what its backend does when asked: find these rows,
   * write this one, remove that one. The batching, the ordering and the
   * protocol are ours; what is left is a translation table.
   */
  let make = (
    {find, upsert, remove, ?online, ?persist, ?lookup, ?merge, ?expiry}: config<'query, 'a>,
  ) => {
    let signal = switch online {
    | Some(online) => online
    | None => TiliaQueryStore.online()
    }
    (schema: schema<'query, 'a>, binding) =>
      custom({
        remote: TiliaQueryStore.asRemote(~id=schema.id, ~online=signal, ~find, ~upsert, ~remove),
        ?persist,
        ?lookup,
        ?merge,
        ?expiry,
      })(schema, binding)
  }
}

// === make (factory)

let sortedStringify = TiliaQuerySchema.sortedStringify

let _expiry: expiry = {
  // 30 seconds
  refresh: 30_000.0,
  // 5 minutes
  memory: 300_000.0,
}

let _now = () => Date.now()
let _no_sort = _query => array => array

let make = (
  {id, matches, store, ?expiry, ?now, ?key, ?sort, ?onError}: config<'query, 'a, 'store>,
) => {
  let expiry = switch expiry {
  | Some(expiry) => expiry
  | None => _expiry
  }
  let now = switch now {
  | Some(now) => now
  | None => _now
  }
  let key = switch key {
  | Some(key) => key
  | None => sortedStringify
  }
  let sort = switch sort {
  | Some(sort) => sort
  | None => _no_sort
  }
  // Resolved once, here, and read by both halves from now on. `store` is a
  // factory, not a built store, so the two cannot disagree about it.
  let schema: schema<'query, 'a> = {id, matches, key, sort, now}
  let onError = (~query, ~message) =>
    switch onError {
    | Some(onError) => onError(~query, ~message)
    | None => ()
    }

  TiliaQueryEngine.make({
    schema,
    expiry,
    onError,
    connect: binding => store(schema, binding),
  })
}
